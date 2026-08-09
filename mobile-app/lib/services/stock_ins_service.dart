import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/stock_in.dart';

class StockInsService {
  final Ref ref;
  StockInsService(this.ref);

  Future<PaginatedResponse<StockInModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/stock-ins', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, StockInModel.fromJson);
  }

  Future<StockInModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/stock-ins/$id');
    return StockInModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<StockInModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/stock-ins', data: payload);
    return StockInModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<StockInModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/stock-ins/$id', data: payload);
    return StockInModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/stock-ins/$id');
}

final stockInsServiceProvider = Provider((ref) => StockInsService(ref));
