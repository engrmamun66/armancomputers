import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/lookup.dart';

class LookupsService {
  final Ref ref;
  LookupsService(this.ref);

  Future<List<RoleModel>> roles() async {
    final res = await ref.read(dioProvider).get('/roles');
    return (res.data['data'] as List).map((e) => RoleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<StatusModel>> statuses(String type) async {
    final res = await ref.read(dioProvider).get('/statuses', queryParameters: {'type': type});
    return (res.data['data'] as List).map((e) => StatusModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final lookupsServiceProvider = Provider((ref) => LookupsService(ref));
