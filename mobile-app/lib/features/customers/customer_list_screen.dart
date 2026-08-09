import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../providers/auth_provider.dart';
import '../../services/customers_service.dart';
import '../../services/lookups_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/status_badge.dart';
import 'customer_form_sheet.dart';

/// Sentinel used for the "All Statuses" filter option. Real status ids from
/// the API start at 1, so 0 can never collide with a genuine status. This is
/// needed because SearchableSelect only invokes onChanged for non-null
/// selections, which would make a real `null` option unselectable.
const int _kAllStatuses = 0;

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _search = '';
  int _statusFilter = _kAllStatuses;
  int _page = 1;
  int _searchFieldTick = 0;

  bool _loading = true;
  String? _error;
  PaginatedResponse<CustomerModel>? _response;
  List<StatusModel> _statuses = [];

  bool get _hasFilters => _search.isNotEmpty || _statusFilter != _kAllStatuses;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    _load();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await ref.read(lookupsServiceProvider).statuses('general');
      if (mounted) setState(() => _statuses = statuses);
    } catch (_) {
      // Non-fatal: the status filter simply stays empty; the customer list
      // itself still loads and works fine without it.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'page': _page,
        if (_search.isNotEmpty) 'search': _search,
        if (_statusFilter != _kAllStatuses) 'status_id': _statusFilter,
      };
      final response = await ref.read(customersServiceProvider).list(params);
      if (!mounted) return;
      setState(() => _response = response);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load customers.');
      AppSnackbar.error(context, 'Failed to load customers.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _search = value;
      _page = 1;
    });
    _load();
  }

  void _onStatusChanged(int value) {
    setState(() {
      _statusFilter = value;
      _page = 1;
    });
    _load();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _statusFilter = _kAllStatuses;
      _page = 1;
      _searchFieldTick++;
    });
    _load();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openCreate() async {
    await showCustomerFormSheet(context, onSaved: (_) => _load());
  }

  Future<void> _openEdit(CustomerModel customer) async {
    await showCustomerFormSheet(context, customer: customer, onSaved: (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).roleSlug;
    final canManage = can(role, 'customers.manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          if (canManage)
            IconButton(icon: const Icon(Icons.add), tooltip: 'Add customer', onPressed: _openCreate),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    key: ValueKey(_searchFieldTick),
                    initialValue: _search,
                    hint: 'Search name, phone, or email…',
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: SearchableSelect<int>(
                          label: 'Status',
                          value: _statusFilter,
                          options: [
                            const SelectOption<int>(_kAllStatuses, 'All Statuses'),
                            ..._statuses.map((s) => SelectOption<int>(s.id, s.name)),
                          ],
                          onChanged: _onStatusChanged,
                        ),
                      ),
                      if (_hasFilters)
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                          label: const Text('Reset filters'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, canManage)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool canManage) {
    if (_loading && _response == null) return const AppLoading();

    if (_error != null && _response == null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load customers',
        message: _error,
        clearLabel: 'Retry',
        onClear: _load,
      );
    }

    final response = _response;
    if (response == null) return const SizedBox.shrink();

    if (response.data.isEmpty) {
      return AppEmptyState(
        title: 'No customers found',
        message: _hasFilters ? 'No records match your current filters.' : 'Get started by adding your first customer.',
        clearLabel: _hasFilters ? 'Reset filters' : null,
        onClear: _hasFilters ? _resetFilters : null,
      );
    }

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: response.data.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final customer = response.data[index];
              return _CustomerCard(
                customer: customer,
                canManage: canManage,
                onTap: () => context.push('/customers/${customer.id}'),
                onEdit: () => _openEdit(customer),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PaginationControls(meta: response.meta, onPageChange: _onPageChanged),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CustomerCard({
    required this.customer,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = customer.totalDue ?? 0;
    final dueColor = due > 0 ? AppColors.danger(context) : scheme.onSurface;
    final hasPhone = customer.phone != null && customer.phone!.isNotEmpty;
    final hasEmail = customer.email != null && customer.email!.isNotEmpty;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      customer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: customer.status?.slug ?? customer.status?.name ?? ''),
                ],
              ),
              const SizedBox(height: 8),
              if (hasPhone) _InfoRow(icon: Icons.call_outlined, text: customer.phone!),
              if (hasPhone && hasEmail) const SizedBox(height: 4),
              if (hasEmail) _InfoRow(icon: Icons.email_outlined, text: customer.email!),
              if (!hasPhone && !hasEmail) _InfoRow(icon: Icons.info_outline, text: 'No contact info'),
              const SizedBox(height: 12),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${customer.totalPurchases ?? 0} purchases',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const Spacer(),
                  Text('Due  ', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  Text(
                    formatCurrency(due),
                    style: TextStyle(color: dueColor, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: muted, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
