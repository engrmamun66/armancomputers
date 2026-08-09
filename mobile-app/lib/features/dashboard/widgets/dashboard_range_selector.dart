import 'package:flutter/material.dart';

import '../../../shared/widgets/app_date_field.dart';

/// The 5 ranges the dashboard API accepts, mirroring the web app's
/// `RANGE_OPTIONS` (today | week | month | year | custom).
enum DashboardRange { today, week, month, year, custom }

extension DashboardRangeX on DashboardRange {
  String get apiValue => switch (this) {
        DashboardRange.today => 'today',
        DashboardRange.week => 'week',
        DashboardRange.month => 'month',
        DashboardRange.year => 'year',
        DashboardRange.custom => 'custom',
      };

  String get label => switch (this) {
        DashboardRange.today => 'Today',
        DashboardRange.week => 'This Week',
        DashboardRange.month => 'This Month',
        DashboardRange.year => 'This Year',
        DashboardRange.custom => 'Custom Range',
      };
}

/// Range dropdown + (when Custom is selected) a from/to date-field pair.
///
/// A dropdown is used instead of a segmented control so all 5 options
/// (including the longer "Custom Range" label) always fit on a phone-width
/// screen without wrapping or horizontal scrolling.
class DashboardRangeSelector extends StatelessWidget {
  final DashboardRange range;
  final DateTime? customFrom;
  final DateTime? customTo;
  final ValueChanged<DashboardRange> onRangeChanged;
  final ValueChanged<DateTime> onCustomFromChanged;
  final ValueChanged<DateTime> onCustomToChanged;

  const DashboardRangeSelector({
    super.key,
    required this.range,
    required this.customFrom,
    required this.customTo,
    required this.onRangeChanged,
    required this.onCustomFromChanged,
    required this.onCustomToChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DashboardRange>(
          initialValue: range,
          decoration: const InputDecoration(
            labelText: 'Date Range',
            prefixIcon: Icon(Icons.date_range_outlined),
          ),
          items: DashboardRange.values
              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
              .toList(),
          onChanged: (value) {
            if (value != null) onRangeChanged(value);
          },
        ),
        if (range == DashboardRange.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppDateField(
                  label: 'From',
                  value: customFrom,
                  lastDate: customTo ?? DateTime.now(),
                  onChanged: onCustomFromChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDateField(
                  label: 'To',
                  value: customTo,
                  firstDate: customFrom,
                  lastDate: DateTime.now(),
                  onChanged: onCustomToChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
