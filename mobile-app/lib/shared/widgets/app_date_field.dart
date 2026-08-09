import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Single date-picker field. Always used instead of any free-text date
/// entry, mirroring the web app's rule of never using a bare native date
/// input.
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final VoidCallback? onClear;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.onClear,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _pick(context),
          child: InputDecorator(
            decoration: InputDecoration(errorText: errorText),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? DateFormat('dd MMM yyyy').format(value!) : 'Select date',
                    style: TextStyle(color: value == null ? scheme.onSurfaceVariant : null),
                  ),
                ),
                if (onClear != null && value != null)
                  InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  Icon(Icons.calendar_today_outlined, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact from/to range filter with quick presets — used on list screens.
class AppDateRangeFilter extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;

  const AppDateRangeFilter({
    super.key,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  Future<void> _pick(BuildContext context, DateTime? initial, ValueChanged<DateTime?> onChanged) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case 'week':
        onFromChanged(now.subtract(Duration(days: now.weekday - 1)));
        onToChanged(now);
        break;
      case 'month':
        onFromChanged(DateTime(now.year, now.month, 1));
        onToChanged(now);
        break;
      case 'year':
        onFromChanged(DateTime(now.year, 1, 1));
        onToChanged(now);
        break;
      case 'clear':
        onFromChanged(null);
        onToChanged(null);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, from, onFromChanged),
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(from != null ? fmt.format(from!) : 'From', overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, to, onToChanged),
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(to != null ? fmt.format(to!) : 'To', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _presetChip(context, 'This Week', () => _applyPreset('week')),
            _presetChip(context, 'This Month', () => _applyPreset('month')),
            _presetChip(context, 'This Year', () => _applyPreset('year')),
            if (from != null || to != null)
              ActionChip(
                label: const Text('Clear'),
                onPressed: () => _applyPreset('clear'),
                labelStyle: TextStyle(color: scheme.error),
              ),
          ],
        ),
      ],
    );
  }

  Widget _presetChip(BuildContext context, String label, VoidCallback onTap) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
