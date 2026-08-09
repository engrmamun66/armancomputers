import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, HH:mm');

String formatCurrency(num? value) => '৳${_currencyFmt.format(value ?? 0)}';

String formatDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  final date = DateTime.tryParse(value);
  if (date == null) return '—';
  return _dateFmt.format(date);
}

String formatDateTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  final date = DateTime.tryParse(value);
  if (date == null) return '—';
  return _dateTimeFmt.format(date.toLocal());
}

String apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Warranty length as a friendly duration (e.g. "20 Days", "3 Months", "1
/// Year"), computed as warrantyEndDate - startDate (purchase/sale date).
/// Returns null when there's no warranty end date, so callers render their
/// own empty-state ("—").
String? formatWarranty(String? startDate, String? warrantyEndDate) {
  if (warrantyEndDate == null || warrantyEndDate.isEmpty) return null;
  final start = DateTime.tryParse(startDate ?? '');
  final end = DateTime.tryParse(warrantyEndDate);
  if (start == null || end == null) return null;
  final diffDays = end.difference(start).inDays;
  if (diffDays <= 0) return 'Expired';
  if (diffDays < 30) return '$diffDays Day${diffDays == 1 ? '' : 's'}';
  if (diffDays < 365) {
    final months = (diffDays / 30).round();
    return '$months Month${months == 1 ? '' : 's'}';
  }
  final years = (diffDays / 365).round();
  return '$years Year${years == 1 ? '' : 's'}';
}
