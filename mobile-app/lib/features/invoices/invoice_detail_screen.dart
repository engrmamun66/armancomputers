import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/company.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../models/line_item.dart';
import '../../services/invoices_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// View-only invoice document. Invoices are auto-created 1:1 from Stock Out
/// records for every authenticated role, so there is deliberately no edit or
/// delete affordance anywhere on this screen.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const InvoiceDetailScreen({super.key, required this.id});

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _loading = true;
  String? _error;
  InvoiceModel? _invoice;

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
      final invoice = await ref.read(invoicesServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.toApiException(e).message;
        _loading = false;
      });
    }
  }

  void _copyDetails() {
    final invoice = _invoice;
    if (invoice == null) return;
    final buffer = StringBuffer()
      ..writeln(Company.name)
      ..writeln('Invoice #${invoice.invoiceNumber}')
      ..writeln('Date: ${formatDate(invoice.invoiceDate)}')
      ..writeln('Customer: ${invoice.customer?.name ?? 'Walk-in customer'}')
      ..writeln('Subtotal: ${formatCurrency(invoice.subtotal)}')
      ..writeln('Discount: ${formatCurrency(invoice.discount)}')
      ..writeln('Additional Cost: ${formatCurrency(invoice.additionalCost)}')
      ..writeln('Grand Total: ${formatCurrency(invoice.grandTotal)}')
      ..writeln('Paid: ${formatCurrency(invoice.paidAmount)}')
      ..writeln('Due: ${formatCurrency(invoice.dueAmount)}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppSnackbar.success(context, 'Invoice details copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(invoice != null ? 'Invoice #${invoice.invoiceNumber}' : 'Invoice'),
        actions: [
          if (invoice != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy details',
              onPressed: _copyDetails,
            ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? _buildError(context)
              : _buildContent(context, invoice!),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InvoiceModel invoice) {
    final hasBadges = invoice.status != null || invoice.paymentStatus != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, invoice),
            if (hasBadges) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (invoice.status != null) StatusBadge(status: invoice.status!.slug),
                  if (invoice.paymentStatus != null) StatusBadge(status: invoice.paymentStatus!),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildBillTo(context, invoice),
            const SizedBox(height: 16),
            _buildItems(context, invoice),
            const SizedBox(height: 16),
            _buildTotals(context, invoice),
            const SizedBox(height: 16),
            _buildFooterMeta(context, invoice),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InvoiceModel invoice) {
    final scheme = Theme.of(context).colorScheme;

    final companyBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Company.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(Company.address, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 2),
        Text(Company.phone, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 2),
        Text(Company.email, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ],
    );

    Widget invoiceBlock(CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'INVOICE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text('#${invoice.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(formatDate(invoice.invoiceDate), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        );

    return SectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 420) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: companyBlock),
                const SizedBox(width: 16),
                invoiceBlock(CrossAxisAlignment.end),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              companyBlock,
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              invoiceBlock(CrossAxisAlignment.start),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBillTo(BuildContext context, InvoiceModel invoice) {
    final scheme = Theme.of(context).colorScheme;
    final customer = invoice.customer;
    return SectionCard(
      title: 'Bill To',
      child: customer == null
          ? Text('Walk-in customer (no customer on file).', style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _iconLine(context, Icons.call_outlined, customer.phone!),
                ],
                if (customer.email != null && customer.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _iconLine(context, Icons.email_outlined, customer.email!),
                ],
                if (customer.address != null && customer.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _iconLine(context, Icons.location_on_outlined, customer.address!),
                ],
              ],
            ),
    );
  }

  Widget _iconLine(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
      ],
    );
  }

  Widget _buildItems(BuildContext context, InvoiceModel invoice) {
    final scheme = Theme.of(context).colorScheme;
    final items = invoice.items;
    return SectionCard(
      title: 'Items (${items.length})',
      child: items.isEmpty
          ? Text('No line items recorded.', style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ItemRow(item: items[i], startDate: invoice.invoiceDate),
                  if (i != items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _buildTotals(BuildContext context, InvoiceModel invoice) {
    return SectionCard(
      title: 'Summary',
      child: Column(
        children: [
          _totalRow(context, 'Subtotal', formatCurrency(invoice.subtotal)),
          if (invoice.discount > 0) _totalRow(context, 'Discount', '– ${formatCurrency(invoice.discount)}'),
          if (invoice.additionalCost > 0) _totalRow(context, 'Additional Cost', formatCurrency(invoice.additionalCost)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
          _totalRow(context, 'Grand Total', formatCurrency(invoice.grandTotal), bold: true, fontSize: 17),
          const SizedBox(height: 10),
          _totalRow(context, 'Paid Amount', formatCurrency(invoice.paidAmount), valueColor: AppColors.success(context)),
          _totalRow(
            context,
            'Due Amount',
            formatCurrency(invoice.dueAmount),
            bold: invoice.dueAmount > 0,
            valueColor: invoice.dueAmount > 0 ? AppColors.danger(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value, {bool bold = false, Color? valueColor, double? fontSize}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: fontSize ?? 14, fontWeight: bold ? FontWeight.w600 : null),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterMeta(BuildContext context, InvoiceModel invoice) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <String>[];
    if (invoice.createdBy != null && invoice.createdBy!.isNotEmpty) {
      final when = invoice.createdAt != null ? ' on ${formatDateTime(invoice.createdAt)}' : '';
      lines.add('Created by ${invoice.createdBy}$when');
    } else if (invoice.createdAt != null) {
      lines.add('Created on ${formatDateTime(invoice.createdAt)}');
    }
    if (invoice.saleId != null) {
      lines.add('Generated from Sale #${invoice.saleId}');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final line in lines)
            Text(line, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final LineItem item;
  final String startDate;
  const _ItemRow({required this.item, required this.startDate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (item.productName != null && item.productName!.isNotEmpty) ? item.productName! : 'Product #${item.productId}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            Text(formatCurrency(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
        if (item.warrantyEndDate != null) ...[
          const SizedBox(height: 4),
          Text('Warranty: ${formatWarranty(startDate, item.warrantyEndDate) ?? '—'}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}
