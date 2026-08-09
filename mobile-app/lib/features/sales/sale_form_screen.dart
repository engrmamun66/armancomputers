import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/line_item.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/customers_service.dart';
import '../../services/lookups_service.dart';
import '../../services/products_service.dart';
import '../../services/sales_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/remote_search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/section_card.dart';

/// Mutable in-memory cart row while the form is being edited. `currentStock`
/// is the stock level captured at the moment the product was picked (for the
/// client-side, non-blocking "insufficient stock" hint). For line items
/// seeded from an existing Sale (edit mode) it is left null — we don't
/// know the "available for this row" figure without extra round-trips, and
/// the backend's row-locked check is authoritative regardless.
class _CartItem {
  final int productId;
  final String productName;
  final String? sku;
  final int? currentStock;
  int quantity;
  double unitPrice;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _CartItem({
    required this.productId,
    required this.productName,
    this.sku,
    required this.currentStock,
    required this.quantity,
    required this.unitPrice,
  })  : qtyController = TextEditingController(text: quantity.toString()),
        priceController = TextEditingController(text: unitPrice.toStringAsFixed(2));

  double get lineTotal => quantity * unitPrice;

  LineItem toLineItem() => LineItem(productId: productId, quantity: quantity, unitPrice: unitPrice);

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}

class SaleFormScreen extends ConsumerStatefulWidget {
  final int? id;
  const SaleFormScreen({super.key, this.id});

  @override
  ConsumerState<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends ConsumerState<SaleFormScreen> {
  bool _loading = false;
  String? _loadError;
  bool _submitting = false;
  bool _showValidation = false;

  CustomerRef? _customer;
  DateTime? _saleDate;
  DateTime? _warrantyEndDate;
  late final TextEditingController _notesController;
  late final TextEditingController _discountController;
  late final TextEditingController _additionalCostController;
  late final TextEditingController _paidAmountController;

  double _discount = 0;
  double _additionalCost = 0;
  double _paidAmount = 0;
  String _paymentMethod = 'cash';
  final List<_CartItem> _items = [];

  int? _activeGeneralStatusId;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _saleDate = DateTime.now();
    _notesController = TextEditingController();
    _discountController = TextEditingController(text: '0.00');
    _additionalCostController = TextEditingController(text: '0.00');
    _paidAmountController = TextEditingController(text: '0.00');
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _additionalCostController.dispose();
    _paidAmountController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final sale = await ref.read(salesServiceProvider).get(widget.id!);
      if (!mounted) return;
      setState(() {
        _customer = sale.customer;
        _saleDate = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
        _warrantyEndDate = sale.warrantyEndDate != null ? DateTime.tryParse(sale.warrantyEndDate!) : null;
        _notesController.text = sale.notes ?? '';
        _discount = sale.discount;
        _discountController.text = sale.discount.toStringAsFixed(2);
        _additionalCost = sale.additionalCost;
        _additionalCostController.text = sale.additionalCost.toStringAsFixed(2);
        _paymentMethod = sale.paymentMethod;
        _paidAmount = sale.paidAmount;
        _paidAmountController.text = sale.paidAmount.toStringAsFixed(2);
        _items.addAll(sale.items.map((li) => _CartItem(
              productId: li.productId,
              productName: li.productName ?? 'Product #${li.productId}',
              sku: li.sku,
              currentStock: null,
              quantity: li.quantity,
              unitPrice: li.unitPrice,
            )));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : 'Failed to load sale.';
        _loading = false;
      });
    }
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  double get _grandTotal {
    final total = _subtotal - _discount + _additionalCost;
    return total < 0 ? 0 : total;
  }

  double get _dueAmount {
    final due = _grandTotal - _paidAmount;
    return due < 0 ? 0 : due;
  }

  void _addProduct(ProductModel product) {
    setState(() {
      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex != -1) {
        final item = _items[existingIndex];
        item.quantity += 1;
        item.qtyController.text = item.quantity.toString();
      } else {
        _items.add(_CartItem(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          currentStock: product.currentStock,
          quantity: 1,
          unitPrice: product.sellingPrice,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<int> _resolveActiveGeneralStatusId() async {
    if (_activeGeneralStatusId != null) return _activeGeneralStatusId!;
    final statuses = await ref.read(lookupsServiceProvider).statuses('general');
    final active = statuses.where((s) => s.slug == 'active');
    final id = active.isNotEmpty ? active.first.id : statuses.first.id;
    _activeGeneralStatusId = id;
    return id;
  }

  Future<void> _openAddCustomerSheet() async {
    final controller = TextEditingController();
    bool creating = false;
    String? error;
    final created = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add New Customer', style: Theme.of(sheetCtx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Customer Name', errorText: error),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isEmpty) {
                            setSheetState(() => error = 'Name is required');
                            return;
                          }
                          setSheetState(() {
                            creating = true;
                            error = null;
                          });
                          try {
                            final statusId = await _resolveActiveGeneralStatusId();
                            final customer =
                                await ref.read(customersServiceProvider).create({'name': name, 'status_id': statusId});
                            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(customer);
                          } catch (e) {
                            setSheetState(() {
                              creating = false;
                              error = e is ApiException ? e.message : 'Could not create customer.';
                            });
                          }
                        },
                  child: creating ? const ButtonSpinner(color: Colors.white) : const Text('Add Customer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _customer = CustomerRef(
          id: created.id,
          name: created.name,
          phone: created.phone,
          email: created.email,
          address: created.address,
        );
      });
    }
  }

  bool _validate() {
    setState(() => _showValidation = true);
    return _customer != null && _saleDate != null && _items.isNotEmpty && _paymentMethod.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) {
      AppSnackbar.error(context, 'Please fix the highlighted fields before submitting.');
      return;
    }
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'customer_id': _customer!.id,
      'sale_date': apiDate(_saleDate!),
      'warranty_end_date': _warrantyEndDate != null ? apiDate(_warrantyEndDate!) : null,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'discount': _discount,
      'additional_cost': _additionalCost,
      'paid_amount': _paidAmount,
      'payment_method': _paymentMethod,
      'items': _items.map((i) => i.toLineItem().toJson()).toList(),
    };
    try {
      if (_isEdit) {
        await ref.read(salesServiceProvider).update(widget.id!, payload);
      } else {
        await ref.read(salesServiceProvider).create(payload);
      }
      if (!mounted) return;
      AppSnackbar.success(context, _isEdit ? 'Sale updated successfully.' : 'Sale recorded successfully.');
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Expected outcome — e.g. a concurrency-safe insufficient-stock
      // rejection from the backend. Surface the server's message as-is.
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Sale' : 'Add Sale')),
      body: _loading
          ? const AppLoading()
          : _loadError != null
              ? AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load sale',
                  message: _loadError,
                  clearLabel: 'Retry',
                  onClear: _loadExisting,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildCustomerSection(context),
                    const SizedBox(height: 16),
                    _buildSaleInfoSection(context),
                    const SizedBox(height: 16),
                    _buildProductsSection(context),
                    const SizedBox(height: 16),
                    _buildPaymentSection(context),
                  ],
                ),
      bottomNavigationBar: (_loading || _loadError != null)
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? ButtonSpinner(color: Theme.of(context).colorScheme.onPrimary)
                      : Text(_isEdit ? 'Save Changes' : 'Create Sale'),
                ),
              ),
            ),
    );
  }

  Widget _buildCustomerSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_customer != null) {
      final c = _customer!;
      return SectionCard(
        title: 'Customer',
        child: Row(
          children: [
            CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (c.phone != null && c.phone!.isNotEmpty)
                    Text(c.phone!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            TextButton(onPressed: () => setState(() => _customer = null), child: const Text('Change')),
          ],
        ),
      );
    }
    return SectionCard(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteSearchField<CustomerRef>(
            hint: 'Search customer by name or phone',
            search: (q) => ref.read(customersServiceProvider).search(q),
            itemBuilder: (ctx, c) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (c.phone != null && c.phone!.isNotEmpty)
                        Text(c.phone!, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            onSelected: (c) => setState(() => _customer = c),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openAddCustomerSheet,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add new customer'),
            ),
          ),
          if (_showValidation && _customer == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Customer is required', style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildSaleInfoSection(BuildContext context) {
    return SectionCard(
      title: 'Sale Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDateField(
            label: 'Sale Date',
            value: _saleDate,
            onChanged: (d) => setState(() => _saleDate = d),
            errorText: _showValidation && _saleDate == null ? 'Sale date is required' : null,
          ),
          const SizedBox(height: 12),
          AppDateField(
            label: 'Warranty End Date (optional)',
            value: _warrantyEndDate,
            onChanged: (d) => setState(() => _warrantyEndDate = d),
            onClear: () => setState(() => _warrantyEndDate = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Products',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RemoteSearchField<ProductModel>(
            hint: 'Search product by name or SKU',
            search: (q) => ref.read(productsServiceProvider).search(q),
            itemBuilder: (ctx, p) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('SKU: ${p.sku}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCurrency(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Stock: ${p.currentStock}',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.currentStock > 0 ? AppColors.success(ctx) : AppColors.danger(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onSelected: _addProduct,
          ),
          if (_showValidation && _items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Add at least one product', style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No products added yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            )
          else
            for (int i = 0; i < _items.length; i++) _buildItemRow(context, _items[i], i),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, _CartItem item, int index) {
    final scheme = Theme.of(context).colorScheme;
    final overStock = item.currentStock != null && item.quantity > item.currentStock!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (item.sku != null && item.sku!.isNotEmpty)
                      Text('SKU: ${item.sku}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                tooltip: 'Remove',
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  onChanged: (v) {
                    final q = int.tryParse(v);
                    if (q != null && q > 0) setState(() => item.quantity = q);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: item.priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit Price', isDense: true, prefixText: '৳'),
                  onChanged: (v) {
                    final p = double.tryParse(v);
                    if (p != null && p >= 0) setState(() => item.unitPrice = p);
                  },
                ),
              ),
            ],
          ),
          if (overStock) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Only ${item.currentStock} in stock — the server will reject this if unavailable.',
                    style: TextStyle(fontSize: 12, color: AppColors.warning(context)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Line Total: ${formatCurrency(item.lineTotal)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    return SectionCard(
      title: 'Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryRow(context, 'Subtotal', formatCurrency(_subtotal)),
          const SizedBox(height: 10),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Discount', prefixText: '৳'),
            onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _additionalCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Additional Cost', prefixText: '৳'),
            onChanged: (v) => setState(() => _additionalCost = double.tryParse(v) ?? 0),
          ),
          const Divider(height: 24),
          _summaryRow(context, 'Grand Total', formatCurrency(_grandTotal), bold: true),
          const SizedBox(height: 14),
          SearchableSelect<String>(
            label: 'Payment Method',
            value: _paymentMethod,
            options: kPaymentMethods.map((m) => SelectOption(m['value']!, m['label']!)).toList(),
            onChanged: (v) => setState(() => _paymentMethod = v),
            errorText: _showValidation && _paymentMethod.isEmpty ? 'Payment method is required' : null,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _paidAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Paid Amount', prefixText: '৳'),
            onChanged: (v) => setState(() => _paidAmount = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            context,
            'Due Amount',
            formatCurrency(_dueAmount),
            bold: true,
            color: _dueAmount > 0 ? AppColors.danger(context) : AppColors.success(context),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color, fontSize: bold ? 16 : 14),
        ),
      ],
    );
  }
}
