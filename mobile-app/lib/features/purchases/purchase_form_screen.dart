import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/line_item.dart';
import '../../models/product.dart';
import '../../services/products_service.dart';
import '../../services/purchases_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/product_thumbnail.dart';
import '../../shared/widgets/remote_search_field.dart';
import '../../shared/widgets/section_card.dart';

/// Mutable in-memory draft for a line item being edited on the form. `LineItem`
/// itself is immutable, so each draft owns its own text controllers and is
/// converted back to a `LineItem` (via [toLineItem]) only at submit time.
class _LineItemDraft {
  final int? id;
  final int productId;
  final String? productName;
  final String? sku;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  _LineItemDraft({
    this.id,
    required this.productId,
    this.productName,
    this.sku,
    required int quantity,
    required double unitPrice,
  })  : quantityController = TextEditingController(text: quantity.toString()),
        unitPriceController = TextEditingController(text: unitPrice.toStringAsFixed(2));

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(unitPriceController.text.trim()) ?? 0;
  double get lineTotal => quantity * unitPrice;

  LineItem toLineItem() => LineItem(
        id: id,
        productId: productId,
        productName: productName,
        sku: sku,
        quantity: quantity,
        unitPrice: unitPrice,
      );

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final int? id;
  const PurchaseFormScreen({super.key, this.id});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();
  final _additionalCostController = TextEditingController();

  DateTime? _purchaseDate;
  DateTime? _warrantyEndDate;
  final List<_LineItemDraft> _items = [];

  bool _loading = false;
  bool _submitting = false;
  String? _fetchError;
  int? _savingPriceForProductId;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _purchaseDate = DateTime.now();
    if (_isEdit) {
      _loading = true;
      _fetchExisting();
    }
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _additionalCostController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchExisting() async {
    setState(() {
      _loading = true;
      _fetchError = null;
    });
    try {
      final purchase = await ref.read(purchasesServiceProvider).get(widget.id!);
      if (!mounted) return;
      _supplierNameController.text = purchase.supplierName ?? '';
      _supplierPhoneController.text = purchase.supplierPhone ?? '';
      _notesController.text = purchase.notes ?? '';
      _discountController.text = purchase.discount == 0 ? '' : purchase.discount.toStringAsFixed(2);
      _additionalCostController.text = purchase.additionalCost == 0 ? '' : purchase.additionalCost.toStringAsFixed(2);
      _purchaseDate = DateTime.tryParse(purchase.purchaseDate) ?? DateTime.now();
      _warrantyEndDate = purchase.warrantyEndDate != null ? DateTime.tryParse(purchase.warrantyEndDate!) : null;
      for (final item in _items) {
        item.dispose();
      }
      _items
        ..clear()
        ..addAll(purchase.items.map((li) => _LineItemDraft(
              id: li.id,
              productId: li.productId,
              productName: li.productName,
              sku: li.sku,
              quantity: li.quantity,
              unitPrice: li.unitPrice,
            )));
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Failed to load purchase record.';
        _loading = false;
      });
    }
  }

  void _addProduct(ProductModel product) {
    setState(() {
      _items.add(_LineItemDraft(
        productId: product.id,
        productName: product.name,
        quantity: 1,
        unitPrice: product.purchasePrice,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      final draft = _items.removeAt(index);
      draft.dispose();
    });
  }

  Future<void> _savePurchasePrice(_LineItemDraft draft) async {
    if (draft.unitPrice < 0) {
      AppSnackbar.error(context, 'Enter a valid price before saving.');
      return;
    }
    setState(() => _savingPriceForProductId = draft.productId);
    try {
      await ref.read(productsServiceProvider).update(draft.productId, {'purchase_price': draft.unitPrice});
      if (mounted) AppSnackbar.success(context, "Updated ${draft.productName ?? 'product'}'s purchase price.");
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to update purchase price.');
    } finally {
      if (mounted) setState(() => _savingPriceForProductId = null);
    }
  }

  double get _subtotal => _items.fold(0.0, (sum, d) => sum + d.lineTotal);
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _additionalCost => double.tryParse(_additionalCostController.text.trim()) ?? 0;
  double get _grandTotal => _subtotal - _discount + _additionalCost;

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  String? _validate() {
    if (_purchaseDate == null) return 'Purchase date is required.';
    if (_items.isEmpty) return 'Add at least one product.';
    for (final item in _items) {
      if (item.quantity < 1) return 'Quantity must be at least 1 for ${item.productName ?? 'a product'}.';
      if (item.unitPrice < 0) return 'Unit price cannot be negative for ${item.productName ?? 'a product'}.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }

    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'supplier_name': _emptyToNull(_supplierNameController.text),
      'supplier_phone': _emptyToNull(_supplierPhoneController.text),
      'purchase_date': apiDate(_purchaseDate!),
      'warranty_end_date': _warrantyEndDate != null ? apiDate(_warrantyEndDate!) : null,
      'notes': _emptyToNull(_notesController.text),
      'discount': _discount,
      'additional_cost': _additionalCost,
      'items': _items.map((d) => d.toLineItem().toJson()).toList(),
    };

    try {
      if (_isEdit) {
        await ref.read(purchasesServiceProvider).update(widget.id!, payload);
      } else {
        await ref.read(purchasesServiceProvider).create(payload);
      }
      if (!mounted) return;
      AppSnackbar.success(context, _isEdit ? 'Purchase updated successfully.' : 'Purchase recorded successfully.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Purchase' : 'Add Purchase')),
      body: _loading
          ? const AppLoading()
          : _fetchError != null
              ? _buildError(context)
              : _buildForm(context),
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
            Text(_fetchError ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _fetchExisting, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Purchase Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _supplierNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Supplier Name', hintText: 'Optional'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _supplierPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Supplier Phone', hintText: 'Optional'),
                  ),
                  const SizedBox(height: 14),
                  AppDateField(
                    label: 'Purchase Date',
                    required: true,
                    value: _purchaseDate,
                    onChanged: (d) => setState(() => _purchaseDate = d),
                  ),
                  const SizedBox(height: 14),
                  AppDateField(
                    label: 'Warranty End Date (optional)',
                    value: _warrantyEndDate,
                    onChanged: (d) => setState(() => _warrantyEndDate = d),
                    onClear: () => setState(() => _warrantyEndDate = null),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Products',
              trailing: Text(
                '${_items.length} item(s)',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RemoteSearchField<ProductModel>(
                    hint: 'Search product by name or barcode…',
                    search: (q) => ref.read(productsServiceProvider).search(q),
                    itemBuilder: _buildProductResult,
                    onSelected: _addProduct,
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No products added yet. Search above to add the first line item.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...List.generate(
                      _items.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildLineItemRow(context, index),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Totals',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _totalsRow(context, 'Subtotal', formatCurrency(_subtotal)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: const InputDecoration(labelText: 'Discount', hintText: '0.00'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _additionalCostController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: const InputDecoration(labelText: 'Additional Cost', hintText: '0.00'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  _totalsRow(context, 'Grand Total', formatCurrency(_grandTotal), emphasize: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting ? const ButtonSpinner() : Text(_isEdit ? 'Update Purchase' : 'Save Purchase'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProductResult(BuildContext context, ProductModel product) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductThumbnail(url: product.imageUrl, size: 36, radius: 6),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  if (product.brand != null) Text(product.brand!.name, style: TextStyle(fontSize: 12, color: muted)),
                  Text('Stock: ${product.currentStock}', style: TextStyle(fontSize: 12, color: muted)),
                  Text('Purchase: ${formatCurrency(product.purchasePrice)}', style: TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemRow(BuildContext context, int index) {
    final draft = _items[index];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.productName ?? 'Product #${draft.productId}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.unitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: const InputDecoration(labelText: 'Unit Price', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: _savingPriceForProductId == draft.productId
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                tooltip: "Save as this product's purchase price",
                onPressed: _savingPriceForProductId == draft.productId ? null : () => _savePurchasePrice(draft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line Total: ${formatCurrency(draft.lineTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
