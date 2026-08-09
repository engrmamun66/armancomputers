import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/permissions.dart';
import '../../models/brand.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../providers/auth_provider.dart';
import '../../services/brands_service.dart';
import '../../services/lookups_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/status_badge.dart';

/// Sentinel for the status filter's "All Statuses" option. Real status ids
/// are always positive, so 0 is safe. SearchableSelect can't use `null`
/// for this (it treats the sheet returning null as "dismissed, no
/// selection", so an option whose value is null could never be chosen).
const int _kAllStatuses = 0;

class BrandListScreen extends ConsumerStatefulWidget {
  const BrandListScreen({super.key});

  @override
  ConsumerState<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends ConsumerState<BrandListScreen> {
  List<BrandModel> _brands = [];
  PageMeta? _meta;
  List<StatusModel> _statuses = [];

  bool _loading = true;
  String? _error;

  String _search = '';
  int _statusId = _kAllStatuses;
  int _page = 1;

  bool get _hasFilters => _search.trim().isNotEmpty || _statusId != _kAllStatuses;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadStatuses();
    await _loadBrands();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await ref.read(lookupsServiceProvider).statuses('general');
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (_) {
      // Non-fatal: the status filter/form just shows no options. The brand
      // list itself can still load and function without it.
    }
  }

  Future<void> _loadBrands() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final params = <String, dynamic>{'page': _page};
    if (_search.trim().isNotEmpty) params['search'] = _search.trim();
    if (_statusId != _kAllStatuses) params['status_id'] = _statusId;

    try {
      final res = await ref.read(brandsServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _brands = res.data;
        _meta = res.meta;
        _loading = false;
      });
    } catch (e) {
      final message = e is ApiException ? e.message : 'Failed to load brands.';
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = message;
      });
      AppSnackbar.error(context, message);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _search = value;
      _page = 1;
    });
    _loadBrands();
  }

  void _onStatusFilterChanged(int value) {
    setState(() {
      _statusId = value;
      _page = 1;
    });
    _loadBrands();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _statusId = _kAllStatuses;
      _page = 1;
    });
    _loadBrands();
  }

  void _onPageChange(int page) {
    setState(() => _page = page);
    _loadBrands();
  }

  Future<void> _openForm(BrandModel? brand) async {
    if (_statuses.isEmpty) {
      AppSnackbar.error(context, 'No statuses are configured yet. Please try again later.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _BrandFormSheet(brand: brand, statuses: _statuses),
    );
    if (saved == true && mounted) {
      AppSnackbar.success(context, brand == null ? 'Brand created successfully.' : 'Brand updated successfully.');
      if (brand == null) _page = 1;
      _loadBrands();
    }
  }

  Future<void> _deleteBrand(BrandModel brand) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this brand?',
      message: '"${brand.name}" will be permanently removed. This cannot be undone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(brandsServiceProvider).remove(brand.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'Brand deleted successfully.');
      if (_brands.length == 1 && _page > 1) _page -= 1;
      _loadBrands();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to delete brand.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).roleSlug;
    final canManage = can(role, 'brands.manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brands'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Add brand',
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(null),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildFilters(),
            ),
            Expanded(child: _buildBody(canManage)),
            if (_meta != null && !_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PaginationControls(meta: _meta!, onPageChange: _onPageChange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final statusOptions = <SelectOption<int>>[
      const SelectOption(_kAllStatuses, 'All Statuses'),
      ..._statuses.map((s) => SelectOption(s.id, s.name)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          initialValue: _search,
          hint: 'Search brand name…',
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 12),
        SearchableSelect<int>(
          label: 'Status',
          value: _statusId,
          options: statusOptions,
          placeholder: 'All Statuses',
          onChanged: _onStatusFilterChanged,
        ),
        if (_hasFilters)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Reset filters'),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(bool canManage) {
    if (_loading) return const AppLoading();

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: _error,
        clearLabel: 'Retry',
        onClear: _loadBrands,
      );
    }

    if (_brands.isEmpty) {
      return AppEmptyState(
        icon: Icons.sell_outlined,
        title: _hasFilters ? 'No brands match your filters' : 'No brands yet',
        message: _hasFilters ? 'Try adjusting your search or status filter.' : null,
        clearLabel: _hasFilters ? 'Reset filters' : null,
        onClear: _hasFilters ? _resetFilters : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBrands,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _brands.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return _BrandCard(
            brand: brand,
            canManage: canManage,
            onEdit: () => _openForm(brand),
            onDelete: () => _deleteBrand(brand),
          );
        },
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final BrandModel brand;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BrandCard({
    required this.brand,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final description = brand.description?.trim();
    final productsCount = brand.productsCount ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    brand.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: brand.status?.slug ?? ''),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (description == null || description.isEmpty) ? '—' : description,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: muted),
                const SizedBox(width: 4),
                Text(
                  '$productsCount ${productsCount == 1 ? 'product' : 'products'}',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const Spacer(),
                if (canManage) ...[
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandFormSheet extends ConsumerStatefulWidget {
  final BrandModel? brand;
  final List<StatusModel> statuses;

  const _BrandFormSheet({required this.brand, required this.statuses});

  @override
  ConsumerState<_BrandFormSheet> createState() => _BrandFormSheetState();
}

class _BrandFormSheetState extends ConsumerState<_BrandFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  int? _statusId;
  bool _submitting = false;
  String? _nameError;
  String? _statusError;

  bool get _isEdit => widget.brand != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.brand?.name ?? '');
    _descriptionController = TextEditingController(text: widget.brand?.description ?? '');
    _statusId = widget.brand?.status?.id ?? (widget.statuses.isNotEmpty ? widget.statuses.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _statusError = null;
    });
    final formOk = _formKey.currentState!.validate();
    final statusOk = _statusId != null;
    if (!statusOk) setState(() => _statusError = 'Status is required.');
    if (!formOk || !statusOk) return;

    setState(() => _submitting = true);
    final description = _descriptionController.text.trim();
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': description.isEmpty ? null : description,
      'status_id': _statusId,
    };

    try {
      if (_isEdit) {
        await ref.read(brandsServiceProvider).update(widget.brand!.id, payload);
      } else {
        await ref.read(brandsServiceProvider).create(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _nameError = e.firstErrorFor('name');
        _statusError = e.firstErrorFor('status_id');
      });
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusOptions = widget.statuses.map((s) => SelectOption(s.id, s.name)).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Brand' : 'Add Brand',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SearchableSelect<int>(
                label: 'Status',
                value: _statusId,
                options: statusOptions,
                placeholder: 'Select a status',
                errorText: _statusError,
                onChanged: (value) => setState(() {
                  _statusId = value;
                  _statusError = null;
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _submitting ? const ButtonSpinner() : Text(_isEdit ? 'Save changes' : 'Create brand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
