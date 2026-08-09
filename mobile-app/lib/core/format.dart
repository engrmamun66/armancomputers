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
