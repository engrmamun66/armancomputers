import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/line_item.dart';
import '../../models/stock_in.dart';
import '../../services/stock_ins_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

class StockInDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const StockInDetailScreen({super.key, required this.id});

  @override
  ConsumerState<StockInDetailScreen> createState() => _StockInDetailScreenState();
}

class _StockInDetailScreenState extends ConsumerState<StockInDetailScreen> {
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  StockInModel? _stockIn;

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
      final stockIn = await ref.read(stockInsServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _stockIn = stockIn;
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
        _error = 'Failed to load stock in record.';
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final stockIn = _stockIn;
    if (stockIn == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel Stock In',
      message: '${stockIn.referenceNo} will be cancelled and its stock effect reversed. This cannot be undone.',
      confirmText: 'Cancel Stock In',
      danger: true,
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(stockInsServiceProvider).remove(stockIn.id);
      if (!mounted) return;
      AppSnackbar.success(context, '${stockIn.referenceNo} was cancelled.');
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
    final stockIn = _stockIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(stockIn?.referenceNo ?? 'Stock In'),
        actions: stockIn == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () => context.push('/stock-in/${widget.id}/edit').then((_) => _load()),
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
              : stockIn == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, stockIn),
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

  Widget _buildBody(BuildContext context, StockInModel stockIn) {
    final scheme = Theme.of(context).colorScheme;
    final hasNotes = stockIn.notes != null && stockIn.notes!.trim().isNotEmpty;
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
              trailing: StatusBadge(status: stockIn.status?.slug ?? 'unknown'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoRow(context, 'Reference No.', stockIn.referenceNo, mono: true),
                  _infoRow(context, 'Purchase Date', formatDate(stockIn.purchaseDate)),
                  _infoRow(
                    context,
                    'Supplier',
                    (stockIn.supplierName?.isNotEmpty ?? false) ? stockIn.supplierName! : '—',
                  ),
                  _infoRow(
                    context,
                    'Supplier Phone',
                    (stockIn.supplierPhone?.isNotEmpty ?? false) ? stockIn.supplierPhone! : '—',
                  ),
                  _infoRow(
                    context,
                    'Created By',
                    (stockIn.createdBy?.isNotEmpty ?? false) ? stockIn.createdBy! : '—',
                  ),
                  if (stockIn.createdAt != null) _infoRow(context, 'Recorded On', formatDateTime(stockIn.createdAt)),
                ],
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 16),
              SectionCard(title: 'Notes', child: Text(stockIn.notes!.trim())),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: 'Items (${stockIn.items.length})',
              child: stockIn.items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No line items recorded.', style: TextStyle(color: scheme.onSurfaceVariant)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: stockIn.items
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
                  _totalsRow(context, 'Subtotal', formatCurrency(stockIn.subtotal)),
                  const SizedBox(height: 8),
                  _totalsRow(context, 'Discount', '- ${formatCurrency(stockIn.discount)}'),
                  const SizedBox(height: 8),
                  _totalsRow(context, 'Additional Cost', '+ ${formatCurrency(stockIn.additionalCost)}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  _totalsRow(context, 'Grand Total', formatCurrency(stockIn.grandTotal), emphasize: true),
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
