import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/dashboard.dart';

class DashboardService {
  final Ref ref;
  DashboardService(this.ref);

  /// range: today | week | month | year | custom (custom requires date_from/date_to)
  Future<DashboardData> get({String range = 'month', String? dateFrom, String? dateTo}) async {
    final res = await ref.read(dioProvider).get(
      '/dashboard',
      queryParameters: {
        'range': range,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
    );
    return DashboardData.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

final dashboardServiceProvider = Provider((ref) => DashboardService(ref));
