import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/brand.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/brands_service.dart';
import '../../services/lookups_service.dart';
import '../../services/products_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/status_badge.dart';

/// Sentinel values representing "no filter" for the int-keyed pickers below.
/// Real brand/status ids from the backend are positive auto-increment
/// primary keys, so 0 can never collide with a real record.
const int _kAllBrandsId = 0;
const int _kAllStatusId = 0;

const List<Map<String, String>> _kSortFields = [
  {'key': 'name', 'label': 'Name'},
  {'key': 'selling_price', 'label': 'Price'},
  {'key': 'current_stock', 'label': 'Stock'},
];

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _search = '';
  int _brandId = _kAllBrandsId;
  String _stockStatus = '';
  int _statusId = _kAllStatusId;
  String _sortBy = 'name';
  String _sortDir = 'asc';
  int _page = 1;

  List<BrandModel> _brands = [];
  List<StatusModel> _statuses = [];

  PaginatedResponse<ProductModel>? _response;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadProducts();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final results = await Future.wait([
        ref.read(brandsServiceProvider).all(),
        ref.read(lookupsServiceProvider).statuses('general'),
      ]);
      if (!mounted) return;
      setState(() {
        _brands = results[0] as List<BrandModel>;
        _statuses = results[1] as List<StatusModel>;
      });
    } catch (_) {
      // Filters are a nice-to-have; a failure here shouldn't block the list.
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'sort_by': _sortBy,
        'sort_dir': _sortDir,
        'page': _page,
      };
      if (_search.isNotEmpty) params['search'] = _search;
      if (_brandId != _kAllBrandsId) params['brand_id'] = _brandId;
      if (_stockStatus.isNotEmpty) params['stock_status'] = _stockStatus;
      if (_statusId != _kAllStatusId) params['status_id'] = _statusId;

      final res = await ref.read(productsServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _response = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final ex = ApiClient.toApiException(e);
      setState(() {
        _error = ex.message;
        _loading = false;
      });
      AppSnackbar.error(context, ex.message);
    }
  }

  bool get _hasFilters =>
      _search.isNotEmpty || _brandId != _kAllBrandsId || _stockStatus.isNotEmpty || _statusId != _kAllStatusId;

  void _resetFilters() {
    setState(() {
      _search = '';
      _brandId = _kAllBrandsId;
      _stockStatus = '';
      _statusId = _kAllStatusId;
      _page = 1;
    });
    _loadProducts();
  }

  void _onFilterChanged() {
    _page = 1;
    _loadProducts();
  }

  void _onSortSelected(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = key;
        _sortDir = 'asc';
      }
      _page = 1;
    });
    _loadProducts();
  }

  String _sortLabel(String key) => _kSortFields.firstWhere((f) => f['key'] == key)['label']!;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).roleSlug;
    final canManage = can(role, 'products.manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add product',
              onPressed: () => context.push('/products/create'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _page = 1;
          await Future.wait([_loadFilterOptions(), _loadProducts()]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            _buildBody(context),
            if (_response != null && !_loading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PaginationControls(
                    meta: _response!.meta,
                    onPageChange: (page) {
                      setState(() => _page = page);
                      _loadProducts();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            initialValue: _search,
            hint: 'Search by name or barcode',
            onChanged: (value) {
              _search = value;
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 170,
                child: SearchableSelect<int>(
                  label: 'Brand',
                  value: _brandId,
                  placeholder: 'All Brands',
                  options: [
                    const SelectOption<int>(_kAllBrandsId, 'All Brands'),
                    ..._brands.map((b) => SelectOption<int>(b.id, b.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _brandId = value);
                    _onFilterChanged();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: SearchableSelect<String>(
                  label: 'Stock Status',
                  value: _stockStatus,
                  placeholder: 'All Stock',
                  options: const [
                    SelectOption<String>('', 'All Stock'),
                    SelectOption<String>('in-stock', 'In Stock'),
                    SelectOption<String>('low-stock', 'Low Stock'),
                    SelectOption<String>('out-of-stock', 'Out of Stock'),
                  ],
                  onChanged: (value) {
                    setState(() => _stockStatus = value);
                    _onFilterChanged();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: SearchableSelect<int>(
                  label: 'Status',
                  value: _statusId,
                  placeholder: 'All Statuses',
                  options: [
                    const SelectOption<int>(_kAllStatusId, 'All Statuses'),
                    ..._statuses.map((s) => SelectOption<int>(s.id, s.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _statusId = value);
                    _onFilterChanged();
                  },
                ),
              ),
              SizedBox(width: 170, child: _buildSortControl(context)),
            ],
          ),
          if (_hasFilters)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Reset filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortControl(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sort By', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          tooltip: 'Sort by',
          onSelected: _onSortSelected,
          itemBuilder: (context) => _kSortFields.map((f) {
            final active = f['key'] == _sortBy;
            return PopupMenuItem<String>(
              value: f['key'],
              child: Row(
                children: [
                  Expanded(child: Text(f['label']!)),
                  if (active)
                    Icon(
                      _sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: scheme.primary,
                    ),
                ],
              ),
            );
          }).toList(),
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                Expanded(child: Text(_sortLabel(_sortBy), overflow: TextOverflow.ellipsis)),
                Icon(_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const SliverFillRemaining(child: AppLoading());
    }
    if (_error != null) {
      return SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load products',
          message: _error,
          clearLabel: 'Retry',
          onClear: _loadProducts,
        ),
      );
    }
    final products = _response?.data ?? const <ProductModel>[];
    if (products.isEmpty) {
      return SliverFillRemaining(
        child: AppEmptyState(
          title: _hasFilters ? 'No products match your filters' : 'No products yet',
          message: _hasFilters ? 'Try adjusting or clearing your filters.' : 'Products you add will show up here.',
          icon: Icons.inventory_2_outlined,
          clearLabel: _hasFilters ? 'Reset filters' : null,
          onClear: _hasFilters ? _resetFilters : null,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProductCard(product: products[index]),
          ),
          childCount: products.length,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  String get _stockState {
    if (product.stockState != null && product.stockState!.isNotEmpty) return product.stockState!;
    if (product.currentStock <= 0) return 'out-of-stock';
    if (product.currentStock <= product.minimumStock) return 'low-stock';
    return 'in-stock';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Color stockBg;
    Color stockFg;
    switch (_stockState) {
      case 'out-of-stock':
        stockBg = AppColors.dangerBg(context);
        stockFg = AppColors.danger(context);
        break;
      case 'low-stock':
        stockBg = AppColors.warningBg(context);
        stockFg = AppColors.warning(context);
        break;
      default:
        stockBg = AppColors.successBg(context);
        stockFg = AppColors.success(context);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/products/${product.id}'),
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
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: product.status?.slug ?? product.status?.name ?? 'unknown'),
                ],
              ),
              const SizedBox(height: 4),
              if (product.brand != null)
                Text(
                  product.brand!.name,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    formatCurrency(product.sellingPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      'Stock: ${product.currentStock}',
                      style: TextStyle(color: stockFg, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
