import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/line_item.dart';
import '../../models/sale.dart';
import '../../providers/auth_provider.dart';
import '../../services/sales_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const SaleDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  SaleModel? _sale;
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sale = await ref.read(salesServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load sale.';
        _loading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    final result = await context.push('/sales/${widget.id}/edit');
    if (result == true) _fetch();
  }

  Future<void> _handleDelete() async {
    final sale = _sale;
    if (sale == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Sale',
      message: '${sale.referenceNo} will be cancelled, its stock returned, and its invoice voided. This cannot be undone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(salesServiceProvider).remove(widget.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'Sale deleted successfully.');
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
      setState(() => _deleting = false);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Failed to delete sale.');
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canManage = can(auth.roleSlug, 'sales.manage');
    final sale = _sale;

    return Scaffold(
      appBar: AppBar(
        title: Text(sale?.referenceNo ?? 'Sale'),
        actions: [
          if (canManage && sale != null) ...[
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: _handleEdit),
            IconButton(
              icon: _deleting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _deleting ? null : _handleDelete,
            ),
          ],
        ],
      ),
      body: _buildBody(context, sale),
    );
  }

  Widget _buildBody(BuildContext context, SaleModel? sale) {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load sale',
        message: _error,
        clearLabel: 'Retry',
        onClear: _fetch,
      );
    }
    if (sale == null) {
      return const AppEmptyState(title: 'Sale not found');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, sale),
          const SizedBox(height: 16),
          _buildCustomerCard(context, sale),
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(title: 'Notes', child: Text(sale.notes!)),
          ],
          const SizedBox(height: 16),
          _buildItemsCard(context, sale),
          const SizedBox(height: 16),
          _buildTotalsCard(context, sale),
          if (sale.invoiceId != null) ...[
            const SizedBox(height: 16),
            _buildInvoiceLink(context, sale),
          ],
          const SizedBox(height: 16),
          _buildMetaFooter(context, sale),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  sale.referenceNo,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatCurrency(sale.grandTotal),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(formatDate(sale.saleDate), style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          if (sale.warrantyEndDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Warranty: ${formatWarranty(sale.saleDate, sale.warrantyEndDate) ?? '—'} (until ${formatDate(sale.warrantyEndDate)})',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sale.status != null) StatusBadge(status: sale.status!.slug),
              if (sale.paymentStatus != null) StatusBadge(status: sale.paymentStatus!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    final c = sale.customer;
    return SectionCard(
      title: 'Customer',
      child: c == null
          ? Text('Walk-in customer', style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (c.phone != null && c.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(c.phone!),
                    ],
                  ),
                ],
                if (c.address != null && c.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c.address!)),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildItemsCard(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Items (${sale.itemsCount ?? sale.items.length})',
      child: sale.items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No line items.', style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : Column(
              children: [
                for (int i = 0; i < sale.items.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _buildItemRow(context, sale.items[i]),
                ],
              ],
            ),
    );
  }

  Widget _buildItemRow(BuildContext context, LineItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.productName ?? 'Product #${item.productId}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Qty ${item.quantity} × ${formatCurrency(item.unitPrice)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            Text(formatCurrency(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalsCard(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Payment Summary',
      child: Column(
        children: [
          _row(context, 'Subtotal', formatCurrency(sale.subtotal)),
          _row(context, 'Discount', '- ${formatCurrency(sale.discount)}'),
          _row(context, 'Additional Cost', '+ ${formatCurrency(sale.additionalCost)}'),
          const Divider(height: 20),
          _row(context, 'Grand Total', formatCurrency(sale.grandTotal), bold: true),
          const SizedBox(height: 8),
          _row(context, 'Paid', formatCurrency(sale.paidAmount)),
          _row(
            context,
            'Due',
            formatCurrency(sale.dueAmount),
            bold: true,
            color: sale.dueAmount > 0 ? AppColors.danger(context) : AppColors.success(context),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment Method: ${_labelForPaymentMethod(sale.paymentMethod)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  String _labelForPaymentMethod(String value) {
    final match = kPaymentMethods.where((m) => m['value'] == value);
    return match.isEmpty ? value : match.first['label']!;
  }

  Widget _buildInvoiceLink(BuildContext context, SaleModel sale) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
        title: const Text('View Invoice'),
        subtitle: const Text('Open the linked invoice for this sale'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/invoices/${sale.invoiceId}'),
      ),
    );
  }

  Widget _buildMetaFooter(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    if (sale.createdBy == null && sale.createdAt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sale.createdBy != null)
            Text('Created by ${sale.createdBy}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (sale.createdAt != null)
            Text('Created ${formatDate(sale.createdAt)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
