import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../services/customers_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';
import 'customer_form_sheet.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int id;

  const CustomerDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  CustomerModel? _customer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customer = await ref.read(customersServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() => _customer = customer);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load customer.');
      AppSnackbar.error(context, 'Failed to load customer.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    final customer = _customer;
    if (customer == null) return;
    await showCustomerFormSheet(
      context,
      customer: customer,
      onSaved: (updated) => setState(() => _customer = updated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).roleSlug;
    final canManage = can(role, 'customers.manage');

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'Customer'),
        actions: [
          if (canManage && _customer != null)
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit customer', onPressed: _openEdit),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _customer == null) return const AppLoading();

    if (_error != null && _customer == null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load customer',
        message: _error,
        clearLabel: 'Retry',
        onClear: _load,
      );
    }

    final customer = _customer;
    if (customer == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final due = customer.totalDue ?? 0;
    final hasPhone = customer.phone != null && customer.phone!.isNotEmpty;
    final hasEmail = customer.email != null && customer.email!.isNotEmpty;
    final hasAddress = customer.address != null && customer.address!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 2)),
          SectionCard(
            title: 'Contact Info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhone) _DetailRow(icon: Icons.call_outlined, label: 'Phone', value: customer.phone!),
                if (hasEmail) _DetailRow(icon: Icons.email_outlined, label: 'Email', value: customer.email!),
                if (hasAddress) _DetailRow(icon: Icons.location_on_outlined, label: 'Address', value: customer.address!),
                if (!hasPhone && !hasEmail && !hasAddress)
                  Text('No contact information on file.', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Purchase Summary',
            trailing: StatusBadge(status: customer.status?.slug ?? customer.status?.name ?? ''),
            child: Column(
              children: [
                _StatRow(label: 'Total Purchases', value: '${customer.totalPurchases ?? 0}'),
                const Divider(height: 24),
                _StatRow(label: 'Total Paid', value: formatCurrency(customer.totalPaid)),
                const Divider(height: 24),
                _StatRow(
                  label: 'Total Due',
                  value: formatCurrency(due),
                  valueColor: due > 0 ? AppColors.danger(context) : null,
                ),
                const Divider(height: 24),
                _StatRow(label: 'Customer Since', value: formatDate(customer.createdAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    );
  }
}
