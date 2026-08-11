import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../models/sale.dart';
import '../../services/lookups_service.dart';
import '../../services/sales_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Bottom-nav shell tab — the single most business-critical screen in the
/// app, since every Sale here auto-creates a linked Invoice server-side.
class SaleListScreen extends ConsumerStatefulWidget {
  const SaleListScreen({super.key});

  @override
  ConsumerState<SaleListScreen> createState() => _SaleListScreenState();
}

class _SaleListScreenState extends ConsumerState<SaleListScreen> {
  String _search = '';
  DateTime? _from;
  DateTime? _to;
  int? _statusId;
  String _paymentStatus = '';
  int _page = 1;
  bool _filtersExpanded = false;

  List<StatusModel> _statuses = [];

  PaginatedResponse<SaleModel>? _response;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    _fetch();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await ref.read(lookupsServiceProvider).statuses('sale');
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (_) {
      // Non-fatal — the status filter simply falls back to "All Statuses".
    }
  }

  bool get _hasFilters =>
      _search.isNotEmpty || _from != null || _to != null || _statusId != null || _paymentStatus.isNotEmpty;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'sort_by': 'id',
        'sort_dir': 'desc',
        'page': _page,
      };
      if (_search.isNotEmpty) params['search'] = _search;
      if (_from != null) params['date_from'] = apiDate(_from!);
      if (_to != null) params['date_to'] = apiDate(_to!);
      if (_statusId != null) params['status_id'] = _statusId;
      if (_paymentStatus.isNotEmpty) params['payment_status'] = _paymentStatus;

      final response = await ref.read(salesServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load sales.';
        _loading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _from = null;
      _to = null;
      _statusId = null;
      _paymentStatus = '';
      _page = 1;
    });
    _fetch();
  }

  Future<void> _openDetail(int id) async {
    final result = await context.push('/sales/$id');
    if (result == true) _fetch();
  }

  Future<void> _openCreate() async {
    final result = await context.push('/sales/create');
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          // Any role may create a Sale — this is never permission-gated.
          IconButton(icon: const Icon(Icons.add), tooltip: 'Add Sale', onPressed: _openCreate),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(context),
            const SizedBox(height: 16),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  int get _hiddenFilterCount =>
      [_from != null, _to != null, _statusId != null, _paymentStatus.isNotEmpty].where((v) => v).length;

  Widget _buildFilters(BuildContext context) {
    return SectionCard(
      title: 'Filters',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
        icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(_hiddenFilterCount > 0 ? 'More ($_hiddenFilterCount)' : 'More'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            hint: 'Search reference, customer, or product',
            onChanged: (v) {
              setState(() {
                _search = v;
                _page = 1;
              });
              _fetch();
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !_filtersExpanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      AppDateRangeFilter(
                        from: _from,
                        to: _to,
                        onFromChanged: (d) {
                          setState(() {
                            _from = d;
                            _page = 1;
                          });
                          _fetch();
                        },
                        onToChanged: (d) {
                          setState(() {
                            _to = d;
                            _page = 1;
                          });
                          _fetch();
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SearchableSelect<int?>(
                              label: 'Status',
                              value: _statusId,
                              placeholder: 'All Statuses',
                              options: [
                                const SelectOption<int?>(null, 'All Statuses'),
                                ..._statuses.map((s) => SelectOption<int?>(s.id, s.name)),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _statusId = v;
                                  _page = 1;
                                });
                                _fetch();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SearchableSelect<String>(
                              label: 'Payment Status',
                              value: _paymentStatus,
                              placeholder: 'All',
                              options: const [
                                SelectOption('', 'All'),
                                SelectOption('paid', 'Paid'),
                                SelectOption('partial', 'Partial'),
                                SelectOption('due', 'Due'),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _paymentStatus = v;
                                  _page = 1;
                                });
                                _fetch();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_hasFilters) ...[
                        const SizedBox(height: 8),
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
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: AppLoading());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load sales',
          message: _error,
          clearLabel: 'Retry',
          onClear: _fetch,
        ),
      );
    }
    final response = _response;
    if (response == null || response.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: AppEmptyState(
          title: 'No sales found',
          message: _hasFilters ? 'Try adjusting your filters.' : 'Record your first sale to get started.',
          clearLabel: _hasFilters ? 'Reset filters' : null,
          onClear: _hasFilters ? _resetFilters : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (response.totals != null) _buildTotals(context, response.totals!),
        const SizedBox(height: 12),
        for (final sale in response.data) _buildItem(context, sale),
        PaginationControls(
          meta: response.meta,
          onPageChange: (p) {
            setState(() => _page = p);
            _fetch();
          },
        ),
      ],
    );
  }

  Widget _buildTotals(BuildContext context, Map<String, dynamic> totals) {
    final success = AppColors.success(context);
    final danger = AppColors.danger(context);
    final profit = (totals['total_profit'] as num?)?.toDouble() ?? 0;
    final due = (totals['total_due'] as num?)?.toDouble() ?? 0;

    return SectionCard(
      title: 'Summary (filtered)',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _stat(context, 'Items', '${totals['items_count'] ?? 0}')),
              _statDivider(context),
              Expanded(child: _stat(context, 'Total Qty', '${totals['total_qty'] ?? 0}')),
              _statDivider(context),
              Expanded(child: _stat(context, 'Total Sale', formatCurrency(totals['total_amount'] as num?))),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stat(context, 'Purchase Cost', formatCurrency(totals['total_cost'] as num?))),
              _statDivider(context),
              Expanded(child: _stat(context, 'Profit', formatCurrency(profit), color: profit >= 0 ? success : danger)),
              _statDivider(context),
              Expanded(child: _stat(context, 'Due', formatCurrency(due), color: due > 0 ? danger : success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) =>
      Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant);

  Widget _stat(BuildContext context, String label, String value, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, SaleModel sale) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(sale.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      sale.referenceNo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(sale.grandTotal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(formatDate(sale.saleDate), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sale.customer?.name ?? 'Walk-in customer',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${sale.itemsCount ?? sale.items.length} item(s) · Qty ${sale.totalQty ?? 0}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (sale.status != null) StatusBadge(status: sale.status!.slug),
                  if (sale.paymentStatus != null) StatusBadge(status: sale.paymentStatus!),
                  if (sale.dueAmount > 0)
                    Text(
                      'Due: ${formatCurrency(sale.dueAmount)}',
                      style: TextStyle(color: AppColors.danger(context), fontWeight: FontWeight.w600, fontSize: 12),
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
