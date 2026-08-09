import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../models/purchase.dart';
import '../../services/lookups_service.dart';
import '../../services/purchases_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Sentinel value used by the status [SearchableSelect] to represent
/// "All Statuses" — kept distinct from real status ids (which are always
/// positive) rather than `null`, because the shared widget's bottom sheet
/// cannot distinguish "picked null" from "dismissed without picking".
const int _kAllStatuses = -1;

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  String _search = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _statusId;
  List<StatusModel> _statuses = [];
  int _page = 1;
  int _searchResetToken = 0;

  bool _loading = true;
  String? _error;
  List<PurchaseModel> _items = [];
  PageMeta? _meta;
  Map<String, dynamic>? _totals;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    _load();
  }

  bool get _hasFilters => _search.isNotEmpty || _dateFrom != null || _dateTo != null || _statusId != null;

  Future<void> _loadStatuses() async {
    try {
      final statuses = await ref.read(lookupsServiceProvider).statuses('purchase');
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (_) {
      // Non-fatal — the status filter simply has no options if this fails.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final params = <String, dynamic>{
      'sort_by': 'purchase_date',
      'sort_dir': 'desc',
      'page': _page,
    };
    if (_search.trim().isNotEmpty) params['search'] = _search.trim();
    if (_dateFrom != null) params['date_from'] = apiDate(_dateFrom!);
    if (_dateTo != null) params['date_to'] = apiDate(_dateTo!);
    if (_statusId != null) params['status_id'] = _statusId;

    try {
      final res = await ref.read(purchasesServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _items = res.data;
        _meta = res.meta;
        _totals = res.totals;
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
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _dateFrom = null;
      _dateTo = null;
      _statusId = null;
      _page = 1;
      _searchResetToken++;
    });
    _load();
  }

  void _onPageChange(int page) {
    setState(() => _page = page);
    _load();
  }

  num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Purchase',
            onPressed: () => context.push('/purchases/create').then((_) => _load()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(context),
            if (!_loading && _error == null && _totals != null) ...[
              const SizedBox(height: 16),
              _buildTotalsCard(context),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: AppLoading())
            else if (_error != null)
              _buildError(context)
            else if (_items.isEmpty)
              AppEmptyState(
                title: 'No purchase records found',
                message: _hasFilters ? 'Try adjusting your filters.' : 'Recorded purchases will appear here.',
                clearLabel: _hasFilters ? 'Reset filters' : null,
                onClear: _hasFilters ? _resetFilters : null,
              )
            else ...[
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PurchaseCard(
                    item: item,
                    onTap: () => context.push('/purchases/${item.id}').then((_) => _load()),
                  ),
                ),
              ),
              if (_meta != null) PaginationControls(meta: _meta!, onPageChange: _onPageChange),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          key: ValueKey(_searchResetToken),
          initialValue: _search,
          hint: 'Search by reference no. or supplier…',
          onChanged: (v) {
            setState(() {
              _search = v;
              _page = 1;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        AppDateRangeFilter(
          from: _dateFrom,
          to: _dateTo,
          onFromChanged: (d) {
            setState(() {
              _dateFrom = d;
              _page = 1;
            });
            _load();
          },
          onToChanged: (d) {
            setState(() {
              _dateTo = d;
              _page = 1;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        SearchableSelect<int>(
          label: 'Status',
          value: _statusId ?? _kAllStatuses,
          placeholder: 'All Statuses',
          options: [
            const SelectOption(_kAllStatuses, 'All Statuses'),
            ..._statuses.map((s) => SelectOption(s.id, s.name)),
          ],
          onChanged: (v) {
            setState(() {
              _statusId = v == _kAllStatuses ? null : v;
              _page = 1;
            });
            _load();
          },
        ),
        if (_hasFilters) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Reset filters'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalsCard(BuildContext context) {
    final totals = _totals!;
    return SectionCard(
      title: 'Totals (all matching results)',
      child: Row(
        children: [
          Expanded(
            child: _totalStat(context, 'Items', '${_asNum(totals['items_count'])?.toInt() ?? 0}'),
          ),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: _totalStat(context, 'Total Qty', '${_asNum(totals['total_qty'])?.toInt() ?? 0}'),
          ),
          Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: _totalStat(context, 'Amount', formatCurrency(_asNum(totals['total_amount']))),
          ),
        ],
      ),
    );
  }

  Widget _totalStat(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseModel item;
  final VoidCallback onTap;

  const _PurchaseCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      item.referenceNo,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: item.status?.slug ?? 'unknown'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(formatDate(item.purchaseDate), style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      (item.supplierName?.isNotEmpty ?? false) ? item.supplierName! : '—',
                      style: TextStyle(fontSize: 13, color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        Text('${item.itemsCount ?? item.items.length} item(s)', style: TextStyle(fontSize: 12, color: muted)),
                        Text('Qty ${item.totalQty ?? 0}', style: TextStyle(fontSize: 12, color: muted)),
                        if (formatWarranty(item.purchaseDate, item.warrantyEndDate) != null)
                          Text('Warranty: ${formatWarranty(item.purchaseDate, item.warrantyEndDate)}', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(item.grandTotal),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.primary),
                    overflow: TextOverflow.ellipsis,
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
