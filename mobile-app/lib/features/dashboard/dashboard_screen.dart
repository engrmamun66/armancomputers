import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme.dart' show AppColors;
import '../../models/dashboard.dart';
import '../../services/dashboard_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import 'widgets/dashboard_chart_colors.dart';
import 'widgets/dashboard_range_selector.dart';
import 'widgets/low_stock_list.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/sales_overview_chart.dart';
import 'widgets/stat_card.dart';
import 'widgets/stock_movement_chart.dart';
import 'widgets/top_products_list.dart';

final _intFmt = NumberFormat('#,##0');

/// The Dashboard tab: range-filterable KPI cards, two charts, and four
/// activity lists. Mirrors the web app's Dashboard.vue 1:1 (see its
/// RANGE_OPTIONS / cards / stock_movement / sales_overview / top-products /
/// low-stock / recent-stock-in / recent-stock-out sections), adapted to a
/// single scrolling column for a phone-width shell tab.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardRange _range = DashboardRange.month;
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loading = true;
  String? _error;
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(dashboardServiceProvider).get(
            range: _range.apiValue,
            dateFrom: _range == DashboardRange.custom && _customFrom != null ? apiDate(_customFrom!) : null,
            dateTo: _range == DashboardRange.custom && _customTo != null ? apiDate(_customTo!) : null,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      final apiEx = e is ApiException ? e : ApiClient.toApiException(e);
      if (!mounted) return;
      setState(() {
        _error = apiEx.message;
        _loading = false;
      });
      AppSnackbar.error(context, apiEx.message);
    }
  }

  void _onRangeChanged(DashboardRange range) {
    setState(() => _range = range);
    if (range != DashboardRange.custom) {
      _load();
    } else if (_customFrom != null && _customTo != null) {
      // Both custom dates were already picked in an earlier session — refetch
      // immediately instead of leaving stale data from the previous range on
      // screen under the "Custom Range" label.
      _load();
    }
  }

  void _onCustomFromChanged(DateTime date) {
    setState(() => _customFrom = date);
    if (_customTo != null) _load();
  }

  void _onCustomToChanged(DateTime date) {
    setState(() => _customTo = date);
    if (_customFrom != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: _loading
            ? const AppLoading()
            : _error != null
                ? _buildError(context)
                : _buildBody(context, _data!),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
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
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DashboardData data) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardRangeSelector(
              range: _range,
              customFrom: _customFrom,
              customTo: _customTo,
              onRangeChanged: _onRangeChanged,
              onCustomFromChanged: _onCustomFromChanged,
              onCustomToChanged: _onCustomToChanged,
            ),
            const SizedBox(height: 20),
            _StatsGrid(cards: data.cards),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Stock In vs Stock Out',
              child: StockMovementChart(points: data.stockMovement),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Sales Overview',
              child: SalesOverviewChart(points: data.salesOverview),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Top Selling Products',
              child: TopProductsList(products: data.topSellingProducts),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Low Stock Products',
              child: LowStockList(products: data.lowStockProducts),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Recent Stock In',
              child: RecentStockInList(items: data.recentStockIns),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Recent Stock Out',
              child: RecentStockOutList(items: data.recentStockOuts),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 9-card KPI grid. Uses a [Wrap] of fixed-width, content-sized tiles
/// (rather than a [GridView] with a guessed aspect ratio) so a 2-line stat
/// label at any font-scale setting never overflows its tile.
class _StatsGrid extends StatelessWidget {
  final DashboardCards cards;

  const _StatsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    final warning = AppColors.warning(context);
    final danger = AppColors.danger(context);
    final stockInTint = DashboardChartColors.slot1(context);
    final stockOutTint = DashboardChartColors.slot2(context);

    final items = <StatCardData>[
      StatCardData(
        label: 'Total Products',
        value: _intFmt.format(cards.totalProducts),
        icon: Icons.inventory_2_outlined,
      ),
      StatCardData(
        label: 'Total Stock Quantity',
        value: _intFmt.format(cards.totalStockQuantity),
        icon: Icons.layers_outlined,
      ),
      StatCardData(
        label: 'Stock In (period)',
        value: _intFmt.format(cards.totalStockIn),
        icon: Icons.arrow_circle_down_outlined,
        tint: stockInTint,
      ),
      StatCardData(
        label: 'Stock Out (period)',
        value: _intFmt.format(cards.totalStockOut),
        icon: Icons.arrow_circle_up_outlined,
        tint: stockOutTint,
      ),
      StatCardData(
        label: "Today's Sales",
        value: formatCurrency(cards.todaysSales),
        icon: Icons.payments_outlined,
        tint: stockInTint,
      ),
      StatCardData(
        label: "Today's Stock In",
        value: formatCurrency(cards.todaysStockIn),
        icon: Icons.local_shipping_outlined,
        tint: stockInTint,
      ),
      StatCardData(
        label: 'Total Customers',
        value: _intFmt.format(cards.totalCustomers),
        icon: Icons.groups_outlined,
      ),
      StatCardData(
        label: 'Low Stock Products',
        value: _intFmt.format(cards.lowStockProducts),
        icon: Icons.warning_amber_rounded,
        tint: warning,
      ),
      StatCardData(
        label: 'Out of Stock Products',
        value: _intFmt.format(cards.outOfStockProducts),
        icon: Icons.remove_shopping_cart_outlined,
        tint: danger,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: StatCard(data: item)),
          ],
        );
      },
    );
  }
}
