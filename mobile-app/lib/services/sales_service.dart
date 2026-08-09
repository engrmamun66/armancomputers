import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/sale.dart';

class SalesService {
  final Ref ref;
  SalesService(this.ref);

  Future<PaginatedResponse<SaleModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/sales', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, SaleModel.fromJson);
  }

  Future<SaleModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/sales/$id');
    return SaleModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<SaleModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/sales', data: payload);
    return SaleModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<SaleModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/sales/$id', data: payload);
    return SaleModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/sales/$id');
}

final salesServiceProvider = Provider((ref) => SalesService(ref));
