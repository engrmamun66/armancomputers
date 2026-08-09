import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../models/stock_out.dart';
import '../../services/lookups_service.dart';
import '../../services/stock_outs_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

/// Bottom-nav shell tab — the single most business-critical screen in the
/// app, since every Stock Out here auto-creates a linked Invoice server-side.
class StockOutListScreen extends ConsumerStatefulWidget {
  const StockOutListScreen({super.key});

  @override
  ConsumerState<StockOutListScreen> createState() => _StockOutListScreenState();
}

class _StockOutListScreenState extends ConsumerState<StockOutListScreen> {
  String _search = '';
  DateTime? _from;
  DateTime? _to;
  int? _statusId;
  String _paymentStatus = '';
  int _page = 1;

  List<StatusModel> _statuses = [];

  PaginatedResponse<StockOutModel>? _response;
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
      final statuses = await ref.read(lookupsServiceProvider).statuses('stock_out');
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
        'sort_by': 'sale_date',
        'sort_dir': 'desc',
        'page': _page,
      };
      if (_search.isNotEmpty) params['search'] = _search;
      if (_from != null) params['date_from'] = apiDate(_from!);
      if (_to != null) params['date_to'] = apiDate(_to!);
      if (_statusId != null) params['status_id'] = _statusId;
      if (_paymentStatus.isNotEmpty) params['payment_status'] = _paymentStatus;

      final response = await ref.read(stockOutsServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load stock outs.';
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
    final result = await context.push('/stock-out/$id');
    if (result == true) _fetch();
  }

  Future<void> _openCreate() async {
    final result = await context.push('/stock-out/create');
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Out'),
        actions: [
          // All roles (including staff) may create a Stock Out, so this is
          // never permission-gated.
          IconButton(icon: const Icon(Icons.add), tooltip: 'Add Stock Out', onPressed: _openCreate),
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

  Widget _buildFilters(BuildContext context) {
    return SectionCard(
      title: 'Filters',
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
          title: 'Could not load stock outs',
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
          title: 'No stock outs found',
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
        for (final so in response.data) _buildItem(context, so),
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
    return SectionCard(
      title: 'Summary (filtered)',
      child: Row(
        children: [
          Expanded(child: _stat(context, 'Items', '${totals['items_count'] ?? 0}')),
          Expanded(child: _stat(context, 'Total Qty', '${totals['total_qty'] ?? 0}')),
          Expanded(child: _stat(context, 'Total Amount', formatCurrency(totals['total_amount'] as num?))),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildItem(BuildContext context, StockOutModel so) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(so.id),
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
                      so.referenceNo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(so.grandTotal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(formatDate(so.saleDate), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      so.customer?.name ?? 'Walk-in customer',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${so.itemsCount ?? so.items.length} item(s) · Qty ${so.totalQty ?? 0}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (so.status != null) StatusBadge(status: so.status!.slug),
                  if (so.paymentStatus != null) StatusBadge(status: so.paymentStatus!),
                  if (so.dueAmount > 0)
                    Text(
                      'Due: ${formatCurrency(so.dueAmount)}',
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
