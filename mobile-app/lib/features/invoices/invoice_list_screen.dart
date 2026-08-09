import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/paginated.dart';
import '../../services/customers_service.dart';
import '../../services/invoices_service.dart';
import '../../shared/widgets/app_date_field.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/remote_search_field.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/status_badge.dart';

/// View-only list of invoices (auto-created 1:1 from Stock Out records —
/// there is no create/edit/delete here for any role). Mirrors the web app's
/// Invoices index: free-text search on invoice number, an optional customer
/// picker, and an invoice-date range filter.
class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _search = '';
  CustomerRef? _customer;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 1;

  // Bumped whenever filters are reset in bulk, so AppSearchField (which owns
  // its own TextEditingController) is recreated with a blank value instead
  // of silently keeping stale text on screen.
  int _searchFieldGeneration = 0;

  bool _loading = true;
  String? _error;
  PaginatedResponse<InvoiceModel>? _response;

  bool get _hasFilters => _search.isNotEmpty || _customer != null || _dateFrom != null || _dateTo != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hadData = _response != null;
    setState(() {
      _loading = true;
      if (!hadData) _error = null;
    });
    try {
      final response = await ref.read(invoicesServiceProvider).list({
        if (_search.isNotEmpty) 'search': _search,
        if (_customer != null) 'customer_id': _customer!.id,
        if (_dateFrom != null) 'date_from': apiDate(_dateFrom!),
        if (_dateTo != null) 'date_to': apiDate(_dateTo!),
        'sort_by': 'invoice_date',
        'sort_dir': 'desc',
        'page': _page,
      });
      if (!mounted) return;
      setState(() {
        _response = response;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = ApiClient.toApiException(e).message;
      setState(() {
        _loading = false;
        if (!hadData) _error = message;
      });
      if (hadData) AppSnackbar.error(context, message);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _search = value;
      _page = 1;
    });
    _load();
  }

  void _onCustomerSelected(CustomerRef customer) {
    setState(() {
      _customer = customer;
      _page = 1;
    });
    _load();
  }

  void _clearCustomer() {
    setState(() {
      _customer = null;
      _page = 1;
    });
    _load();
  }

  void _onDateFromChanged(DateTime? value) {
    setState(() {
      _dateFrom = value;
      _page = 1;
    });
    _load();
  }

  void _onDateToChanged(DateTime? value) {
    setState(() {
      _dateTo = value;
      _page = 1;
    });
    _load();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _customer = null;
      _dateFrom = null;
      _dateTo = null;
      _page = 1;
      _searchFieldGeneration++;
    });
    _load();
  }

  void _onPageChange(int page) {
    setState(() => _page = page);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    key: ValueKey(_searchFieldGeneration),
                    initialValue: _search,
                    hint: 'Search by invoice number',
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 12),
                  _buildCustomerFilter(context),
                  const SizedBox(height: 12),
                  AppDateRangeFilter(
                    from: _dateFrom,
                    to: _dateTo,
                    onFromChanged: _onDateFromChanged,
                    onToChanged: _onDateToChanged,
                  ),
                  if (_hasFilters)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                        label: const Text('Reset filters'),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildBody(context)),
            if (_response != null && !(_loading && _response!.data.isEmpty))
              PaginationControls(meta: _response!.meta, onPageChange: _onPageChange),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerFilter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customer = _customer;
    if (customer != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Customer: ${customer.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear customer filter',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              onPressed: _clearCustomer,
            ),
          ],
        ),
      );
    }

    return RemoteSearchField<CustomerRef>(
      hint: 'Filter by customer',
      search: (query) => ref.read(customersServiceProvider).search(query),
      itemBuilder: (context, item) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (item.phone != null && item.phone!.isNotEmpty)
            Text(item.phone!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      onSelected: _onCustomerSelected,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _response == null) {
      return const AppLoading();
    }
    if (_error != null && _response == null) {
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

    final invoices = _response?.data ?? [];
    if (invoices.isEmpty) {
      return AppEmptyState(
        title: 'No invoices found',
        message: _hasFilters
            ? 'Try adjusting or clearing your filters.'
            : 'Invoices are created automatically whenever a stock out is recorded.',
        icon: Icons.receipt_long_outlined,
        clearLabel: _hasFilters ? 'Reset filters' : null,
        onClear: _hasFilters ? _resetFilters : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: invoices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _InvoiceCard(invoice: invoices[index]),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDue = invoice.dueAmount > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/invoices/${invoice.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (invoice.status != null) ...[
                    const SizedBox(width: 8),
                    StatusBadge(status: invoice.status!.slug),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      invoice.customer?.name ?? 'Walk-in customer',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.event_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(formatDate(invoice.invoiceDate), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grand Total', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(formatCurrency(invoice.grandTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Due', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrency(invoice.dueAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: hasDue ? AppColors.danger(context) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (invoice.paymentStatus != null) StatusBadge(status: invoice.paymentStatus!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
