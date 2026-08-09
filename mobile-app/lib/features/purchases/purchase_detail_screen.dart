import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/line_item.dart';
import '../../models/purchase.dart';
import '../../services/purchases_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const PurchaseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  PurchaseModel? _purchase;

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
      final purchase = await ref.read(purchasesServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _purchase = purchase;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load purchase record.';
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final purchase = _purchase;
    if (purchase == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel Purchase',
      message: '${purchase.referenceNo} will be cancelled and its stock effect reversed. This cannot be undone.',
      confirmText: 'Cancel Purchase',
      danger: true,
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(purchasesServiceProvider).remove(purchase.id);
      if (!mounted) return;
      AppSnackbar.success(context, '${purchase.referenceNo} was cancelled.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    return Scaffold(
      appBar: AppBar(
        title: Text(purchase?.referenceNo ?? 'Purchase'),
        actions: purchase == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () => context.push('/purchases/${widget.id}/edit').then((_) => _load()),
                ),
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: 'Cancel',
                  onPressed: _deleting ? null : _delete,
                ),
              ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? _buildError(context)
              : purchase == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, purchase),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PurchaseModel purchase) {
    final scheme = Theme.of(context).colorScheme;
    final hasNotes = purchase.notes != null && purchase.notes!.trim().isNotEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Purchase Info',
              trailing: StatusBadge(status: purchase.status?.slug ?? 'unknown'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoRow(context, 'Reference No.', purchase.referenceNo, mono: true),
                  _infoRow(context, 'Purchase Date', formatDate(purchase.purchaseDate)),
                  _infoRow(
                    context,
                    'Warranty',
                    purchase.warrantyEndDate != null
                        ? '${formatWarranty(purchase.purchaseDate, purchase.warrantyEndDate) ?? '—'} (until ${formatDate(purchase.warrantyEndDate)})'
                        : '—',
                  ),
                  _infoRow(
                    context,
                    'Supplier',
                    (purchase.supplierName?.isNotEmpty ?? false) ? purchase.supplierName! : '—',
                  ),
                  _infoRow(
                    context,
                    'Supplier Phone',
                    (purchase.supplierPhone?.isNotEmpty ?? false) ? purchase.supplierPhone! : '—',
                  ),
                  _infoRow(
                    context,
                    'Created By',
                    (purchase.createdBy?.isNotEmpty ?? false) ? purchase.createdBy! : '—',
                  ),
                  if (purchase.createdAt != null) _infoRow(context, 'Recorded On', formatDateTime(purchase.createdAt)),
                ],
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 16),
              SectionCard(title: 'Notes', child: Text(purchase.notes!.trim())),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: 'Items (${purchase.items.length})',
              child: purchase.items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No line items recorded.', style: TextStyle(color: scheme.onSurfaceVariant)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: purchase.items
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildItemRow(context, item),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Summary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _totalsRow(context, 'Subtotal', formatCurrency(purchase.subtotal)),
                  const SizedBox(height: 8),
                  _totalsRow(context, 'Discount', '- ${formatCurrency(purchase.discount)}'),
                  const SizedBox(height: 8),
                  _totalsRow(context, 'Additional Cost', '+ ${formatCurrency(purchase.additionalCost)}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  _totalsRow(context, 'Grand Total', formatCurrency(purchase.grandTotal), emphasize: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {bool mono = false}) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontFamily: mono ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, LineItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.productName ?? 'Product #${item.productId}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (item.sku != null && item.sku!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('SKU: ${item.sku}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Qty: ${item.quantity}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              Text('Unit Price: ${formatCurrency(item.unitPrice)}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Line Total: ${formatCurrency(item.lineTotal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _totalsRow(BuildContext context, String label, String value, {bool emphasize = false}) {
    final base = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: emphasize ? base : base?.copyWith(color: muted)),
        Text(value, style: emphasize ? base?.copyWith(color: Theme.of(context).colorScheme.primary) : base),
      ],
    );
  }
}
