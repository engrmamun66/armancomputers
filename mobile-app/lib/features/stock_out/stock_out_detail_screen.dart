import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/line_item.dart';
import '../../models/stock_out.dart';
import '../../providers/auth_provider.dart';
import '../../services/stock_outs_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// All roles (including staff) can create a Stock Out, but only admin/manager
/// may edit or delete an existing one — staff is explicitly excluded even
/// though `can('staff', 'stock-out.manage')` is true, per the app's business
/// rule that staff can record sales but not alter/void them afterwards.
class StockOutDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const StockOutDetailScreen({super.key, required this.id});

  @override
  ConsumerState<StockOutDetailScreen> createState() => _StockOutDetailScreenState();
}

class _StockOutDetailScreenState extends ConsumerState<StockOutDetailScreen> {
  StockOutModel? _stockOut;
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
      final so = await ref.read(stockOutsServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _stockOut = so;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load stock out.';
        _loading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    final result = await context.push('/stock-out/${widget.id}/edit');
    if (result == true) _fetch();
  }

  Future<void> _handleDelete() async {
    final so = _stockOut;
    if (so == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Stock Out',
      message: '${so.referenceNo} will be cancelled, its stock returned, and its invoice voided. This cannot be undone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(stockOutsServiceProvider).remove(widget.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'Stock out deleted successfully.');
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
      setState(() => _deleting = false);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Failed to delete stock out.');
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    // Staff CAN create (see StockOutListScreen's always-visible "+"), but
    // must NOT see edit/delete here even though stock-out.manage is granted
    // to their role — hence the explicit role != 'staff' exclusion.
    final canManage = can(auth.roleSlug, 'stock-out.manage') && auth.roleSlug != 'staff';
    final so = _stockOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(so?.referenceNo ?? 'Stock Out'),
        actions: [
          if (canManage && so != null) ...[
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
      body: _buildBody(context, so),
    );
  }

  Widget _buildBody(BuildContext context, StockOutModel? so) {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load stock out',
        message: _error,
        clearLabel: 'Retry',
        onClear: _fetch,
      );
    }
    if (so == null) {
      return const AppEmptyState(title: 'Stock out not found');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, so),
          const SizedBox(height: 16),
          _buildCustomerCard(context, so),
          if (so.notes != null && so.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(title: 'Notes', child: Text(so.notes!)),
          ],
          const SizedBox(height: 16),
          _buildItemsCard(context, so),
          const SizedBox(height: 16),
          _buildTotalsCard(context, so),
          if (so.invoiceId != null) ...[
            const SizedBox(height: 16),
            _buildInvoiceLink(context, so),
          ],
          const SizedBox(height: 16),
          _buildMetaFooter(context, so),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, StockOutModel so) {
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
                  so.referenceNo,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatCurrency(so.grandTotal),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(formatDate(so.saleDate), style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (so.status != null) StatusBadge(status: so.status!.slug),
              if (so.paymentStatus != null) StatusBadge(status: so.paymentStatus!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, StockOutModel so) {
    final scheme = Theme.of(context).colorScheme;
    final c = so.customer;
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

  Widget _buildItemsCard(BuildContext context, StockOutModel so) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Items (${so.itemsCount ?? so.items.length})',
      child: so.items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No line items.', style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : Column(
              children: [
                for (int i = 0; i < so.items.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _buildItemRow(context, so.items[i]),
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
        if (item.sku != null && item.sku!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('SKU: ${item.sku}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
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

  Widget _buildTotalsCard(BuildContext context, StockOutModel so) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Payment Summary',
      child: Column(
        children: [
          _row(context, 'Subtotal', formatCurrency(so.subtotal)),
          _row(context, 'Discount', '- ${formatCurrency(so.discount)}'),
          _row(context, 'Additional Cost', '+ ${formatCurrency(so.additionalCost)}'),
          const Divider(height: 20),
          _row(context, 'Grand Total', formatCurrency(so.grandTotal), bold: true),
          const SizedBox(height: 8),
          _row(context, 'Paid', formatCurrency(so.paidAmount)),
          _row(
            context,
            'Due',
            formatCurrency(so.dueAmount),
            bold: true,
            color: so.dueAmount > 0 ? AppColors.danger(context) : AppColors.success(context),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment Method: ${_labelForPaymentMethod(so.paymentMethod)}',
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

  Widget _buildInvoiceLink(BuildContext context, StockOutModel so) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
        title: const Text('View Invoice'),
        subtitle: const Text('Open the linked invoice for this sale'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/invoices/${so.invoiceId}'),
      ),
    );
  }

  Widget _buildMetaFooter(BuildContext context, StockOutModel so) {
    final scheme = Theme.of(context).colorScheme;
    if (so.createdBy == null && so.createdAt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (so.createdBy != null)
            Text('Created by ${so.createdBy}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (so.createdAt != null)
            Text('Created ${formatDate(so.createdAt)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
