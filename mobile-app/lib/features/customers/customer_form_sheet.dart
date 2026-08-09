import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/customer.dart';
import '../../models/lookup.dart';
import '../../services/customers_service.dart';
import '../../services/lookups_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/searchable_select.dart';

/// Opens the create/edit bottom sheet used by both CustomerListScreen and
/// CustomerDetailScreen. Pass [customer] to pre-fill for editing, omit it to
/// create a new customer. [onSaved] fires with the saved CustomerModel right
/// after the sheet closes on a successful submit.
Future<void> showCustomerFormSheet(
  BuildContext context, {
  CustomerModel? customer,
  required ValueChanged<CustomerModel> onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => CustomerFormSheet(customer: customer, onSaved: onSaved),
  );
}

class CustomerFormSheet extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  final ValueChanged<CustomerModel> onSaved;

  const CustomerFormSheet({super.key, this.customer, required this.onSaved});

  @override
  ConsumerState<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  int? _statusId;

  bool _loadingStatuses = true;
  bool _submitting = false;
  String? _statusLoadError;
  List<StatusModel> _statuses = [];
  Map<String, String?> _fieldErrors = {};

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _statusId = widget.customer?.status?.id;
    _loadStatuses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loadingStatuses = true;
      _statusLoadError = null;
    });
    try {
      final statuses = await ref.read(lookupsServiceProvider).statuses('general');
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _statusId ??= statuses.isNotEmpty ? statuses.first.id : null;
      });
    } catch (_) {
      if (mounted) setState(() => _statusLoadError = 'Failed to load statuses.');
    } finally {
      if (mounted) setState(() => _loadingStatuses = false);
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final statusMissing = _statusId == null;
    if (statusMissing) {
      setState(() => _fieldErrors = {..._fieldErrors, 'status_id': 'Status is required'});
    }
    if (!formValid || statusMissing) return;

    setState(() {
      _submitting = true;
      _fieldErrors = {};
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'status_id': _statusId,
    };

    try {
      final service = ref.read(customersServiceProvider);
      final result = _isEdit
          ? await service.update(widget.customer!.id, payload)
          : await service.create(payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved(result);
      AppSnackbar.success(context, _isEdit ? 'Customer updated successfully.' : 'Customer created successfully.');
    } on ApiException catch (e) {
      final hasFieldErrors = e.errors != null && e.errors!.isNotEmpty;
      if (mounted) {
        setState(() {
          _fieldErrors = hasFieldErrors
              ? {
                  'name': e.firstErrorFor('name'),
                  'phone': e.firstErrorFor('phone'),
                  'email': e.firstErrorFor('email'),
                  'address': e.firstErrorFor('address'),
                  'status_id': e.firstErrorFor('status_id'),
                }
              : {};
        });
        if (!hasFieldErrors) AppSnackbar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _loadingStatuses
            ? const SizedBox(height: 180, child: AppLoading())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_isEdit ? 'Edit Customer' : 'Add Customer', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: 'Name', errorText: _fieldErrors['name']),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: 'Phone (optional)', errorText: _fieldErrors['phone']),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: 'Email (optional)', errorText: _fieldErrors['email']),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                        return ok ? null : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Address (optional)',
                        alignLabelWithHint: true,
                        errorText: _fieldErrors['address'],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_statusLoadError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_statusLoadError!, style: TextStyle(color: scheme.onErrorContainer)),
                            ),
                            TextButton(onPressed: _loadStatuses, child: const Text('Retry')),
                          ],
                        ),
                      )
                    else
                      SearchableSelect<int>(
                        label: 'Status',
                        value: _statusId,
                        options: _statuses.map((s) => SelectOption<int>(s.id, s.name)).toList(),
                        onChanged: (v) => setState(() {
                          _statusId = v;
                          _fieldErrors = {..._fieldErrors, 'status_id': null};
                        }),
                        placeholder: 'Select a status',
                        errorText: _fieldErrors['status_id'],
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _submitting ? const ButtonSpinner() : Text(_isEdit ? 'Save Changes' : 'Create Customer'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
