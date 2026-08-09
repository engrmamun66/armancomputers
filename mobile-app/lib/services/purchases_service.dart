import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/purchase.dart';

class PurchasesService {
  final Ref ref;
  PurchasesService(this.ref);

  Future<PaginatedResponse<PurchaseModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/purchases', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, PurchaseModel.fromJson);
  }

  Future<PurchaseModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/purchases/$id');
    return PurchaseModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<PurchaseModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/purchases', data: payload);
    return PurchaseModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<PurchaseModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/purchases/$id', data: payload);
    return PurchaseModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/purchases/$id');
}

final purchasesServiceProvider = Provider((ref) => PurchasesService(ref));
