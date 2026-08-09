import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../models/brand.dart';
import '../../models/lookup.dart';
import '../../services/brands_service.dart';
import '../../services/lookups_service.dart';
import '../../services/products_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/searchable_select.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? id;

  const ProductFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _minimumStockController = TextEditingController(text: '5');

  int? _brandId;
  int? _statusId;
  int? _currentStock;

  List<BrandModel> _brands = [];
  List<StatusModel> _statuses = [];

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;

  String? _brandError;
  String? _statusError;
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ref.read(brandsServiceProvider).all(),
        ref.read(lookupsServiceProvider).statuses('general'),
      ]);
      _brands = results[0] as List<BrandModel>;
      _statuses = results[1] as List<StatusModel>;

      if (widget.id != null) {
        final product = await ref.read(productsServiceProvider).get(widget.id!);
        _nameController.text = product.name;
        _barcodeController.text = product.barcode ?? '';
        _descriptionController.text = product.description ?? '';
        _purchasePriceController.text = product.purchasePrice.toStringAsFixed(2);
        _sellingPriceController.text = product.sellingPrice.toStringAsFixed(2);
        _minimumStockController.text = product.minimumStock.toString();
        _brandId = product.brand?.id;
        _statusId = product.status?.id;
        _currentStock = product.currentStock;
      } else if (_statuses.isNotEmpty) {
        final active = _statuses.firstWhere((s) => s.slug == 'active', orElse: () => _statuses.first);
        _statusId = active.id;
      }
    } catch (e) {
      final ex = ApiClient.toApiException(e);
      _loadError = ex.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<SelectOption<int>?> _createBrand(String query) async {
    try {
      StatusModel activeStatus;
      if (_statuses.isEmpty) {
        throw ApiException('No statuses available to create a brand with.');
      }
      activeStatus = _statuses.firstWhere((s) => s.slug == 'active', orElse: () => _statuses.first);
      final brand = await ref.read(brandsServiceProvider).create({
        'name': query,
        'status_id': activeStatus.id,
      });
      if (!mounted) return SelectOption(brand.id, brand.name);
      setState(() {
        _brands = [..._brands, brand];
        _brandId = brand.id;
        _brandError = null;
      });
      AppSnackbar.success(context, 'Brand "${brand.name}" created');
      return SelectOption(brand.id, brand.name);
    } catch (e) {
      final ex = ApiClient.toApiException(e);
      if (mounted) AppSnackbar.error(context, ex.message);
      return null;
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _brandError = _brandId == null ? 'Brand is required' : null;
      _statusError = _statusId == null ? 'Status is required' : null;
    });
    if (!formValid || _brandId == null || _statusId == null) return;

    setState(() {
      _submitting = true;
      _serverErrors = {};
    });

    final payload = <String, dynamic>{
      'brand_id': _brandId,
      'name': _nameController.text.trim(),
      'purchase_price': double.parse(_purchasePriceController.text.trim()),
      'selling_price': double.parse(_sellingPriceController.text.trim()),
      'minimum_stock': int.parse(_minimumStockController.text.trim()),
      'status_id': _statusId,
    };
    final barcode = _barcodeController.text.trim();
    payload['barcode'] = barcode.isEmpty ? null : barcode;
    final description = _descriptionController.text.trim();
    payload['description'] = description.isEmpty ? null : description;

    try {
      if (widget.id == null) {
        await ref.read(productsServiceProvider).create(payload);
      } else {
        await ref.read(productsServiceProvider).update(widget.id!, payload);
      }
      if (!mounted) return;
      AppSnackbar.success(context, widget.id == null ? 'Product created' : 'Product updated');
      context.pop();
    } catch (e) {
      final ex = ApiClient.toApiException(e);
      if (!mounted) return;
      setState(() {
        _serverErrors = ex.errors?.map((key, value) => MapEntry(key, value.isNotEmpty ? value.first : '')) ?? {};
        _brandError = ex.firstErrorFor('brand_id') ?? _brandError;
        _statusError = ex.firstErrorFor('status_id') ?? _statusError;
      });
      _formKey.currentState?.validate();
      AppSnackbar.error(context, ex.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Add Product' : 'Edit Product')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const AppLoading();
    if (_loadError != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load form',
        message: _loadError,
        clearLabel: 'Retry',
        onClear: _loadData,
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.id != null && _currentStock != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current stock: $_currentStock — managed via Stock In / Stock Out, not editable here.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SearchableSelect<int>(
            label: 'Brand',
            value: _brandId,
            placeholder: 'Select brand',
            options: _brands.map((b) => SelectOption(b.id, b.name)).toList(),
            allowCreate: true,
            onCreate: _createBrand,
            errorText: _brandError,
            onChanged: (value) => setState(() {
              _brandId = value;
              _brandError = null;
            }),
          ),
          const SizedBox(height: 16),
          SearchableSelect<int>(
            label: 'Status',
            value: _statusId,
            placeholder: 'Select status',
            options: _statuses.map((s) => SelectOption(s.id, s.name)).toList(),
            errorText: _statusError,
            onChanged: (value) => setState(() {
              _statusId = value;
              _statusError = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Product Name'),
            textInputAction: TextInputAction.next,
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Product name is required';
              return _serverErrors['name'];
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _barcodeController,
            decoration: const InputDecoration(labelText: 'Barcode (optional)'),
            textInputAction: TextInputAction.next,
            validator: (v) => _serverErrors['barcode'],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            validator: (v) => _serverErrors['description'],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Purchase Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return 'Required';
                    final parsed = double.tryParse(text);
                    if (parsed == null) return 'Invalid number';
                    if (parsed < 0) return 'Must be ≥ 0';
                    return _serverErrors['purchase_price'];
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sellingPriceController,
                  decoration: const InputDecoration(labelText: 'Selling Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return 'Required';
                    final parsed = double.tryParse(text);
                    if (parsed == null) return 'Invalid number';
                    if (parsed < 0) return 'Must be ≥ 0';
                    return _serverErrors['selling_price'];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _minimumStockController,
            decoration: const InputDecoration(labelText: 'Minimum Stock'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Required';
              final parsed = int.tryParse(text);
              if (parsed == null) return 'Enter a whole number';
              if (parsed < 0) return 'Must be ≥ 0';
              return _serverErrors['minimum_stock'];
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const ButtonSpinner()
                  : Text(widget.id == null ? 'Create Product' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
