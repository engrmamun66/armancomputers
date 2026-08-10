import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/products_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/product_thumbnail.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;

  const ProductDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductModel? _product;
  bool _loading = true;
  String? _error;

  List<StockHistoryEntry>? _history;
  bool _historyLoading = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await ref.read(productsServiceProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
      });
      _loadHistory();
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

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final history = await ref.read(productsServiceProvider).stockHistory(widget.id);
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final ex = ApiClient.toApiException(e);
      setState(() {
        _historyError = ex.message;
        _historyLoading = false;
      });
    }
  }

  String _resolvedStockState(ProductModel p) {
    if (p.stockState != null && p.stockState!.isNotEmpty) return p.stockState!;
    if (p.currentStock <= 0) return 'out-of-stock';
    if (p.currentStock <= p.minimumStock) return 'low-stock';
    return 'in-stock';
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).roleSlug;
    final canManage = can(role, 'products.manage');

    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Product'),
        actions: [
          if (canManage && _product != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit product',
              onPressed: () => context.push('/products/${widget.id}/edit'),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const AppLoading();
    if (_error != null || _product == null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load product',
        message: _error,
        clearLabel: 'Retry',
        onClear: _loadProduct,
      );
    }

    final product = _product!;
    final state = _resolvedStockState(product);
    Color stockBg;
    Color stockFg;
    switch (state) {
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

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProduct();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ProductThumbnail(url: product.imageUrl, size: 120, radius: 12),
                if (product.images.length > 1) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: product.images
                        .map((img) => ProductThumbnail(url: img.url, size: 40, radius: 6))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Product Details',
            trailing: StatusBadge(status: product.status?.slug ?? product.status?.name ?? 'unknown'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(context, 'Brand', product.brand?.name ?? '—'),
                if ((product.barcode ?? '').isNotEmpty) _infoRow(context, 'Barcode', product.barcode!),
                if ((product.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Description', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
                  const SizedBox(height: 4),
                  Text(product.description!, style: theme.textTheme.bodyMedium),
                ],
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                Row(
                  children: [
                    Expanded(child: _statBlock(context, 'Purchase Price', formatCurrency(product.purchasePrice))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statBlock(
                        context,
                        'Selling Price',
                        formatCurrency(product.sellingPrice),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Text(
                        'CURRENT STOCK',
                        style: TextStyle(color: stockFg, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.currentStock}',
                        style: theme.textTheme.headlineMedium?.copyWith(color: stockFg, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Minimum stock: ${product.minimumStock}',
                        style: TextStyle(color: stockFg.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (product.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text('Added ${formatDate(product.createdAt)}', style: TextStyle(color: muted, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Stock History',
            child: _buildHistory(context),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _statBlock(BuildContext context, String label, String value, {Color? color}) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    if (_historyLoading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: AppLoading());
    }
    if (_historyError != null) {
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(_historyError!, style: TextStyle(color: muted), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      );
    }
    final history = _history ?? const <StockHistoryEntry>[];
    if (history.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No stock movements yet',
        message: 'Purchase and sale activity for this product will appear here.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < history.length; i++) ...[
          _HistoryTile(entry: history[i]),
          if (i != history.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final StockHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIn = entry.type == 'in';
    final color = isIn ? AppColors.success(context) : AppColors.danger(context);
    final bg = isIn ? AppColors.successBg(context) : AppColors.dangerBg(context);
    final icon = isIn ? Icons.arrow_downward : Icons.arrow_upward;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: bg, child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.reference,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatDate(entry.date), style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${isIn ? '+' : '-'}${entry.quantity}  ·  stock: ${entry.stockBefore} → ${entry.stockAfter}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
