import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/stock_out.dart';

class StockOutsService {
  final Ref ref;
  StockOutsService(this.ref);

  Future<PaginatedResponse<StockOutModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/stock-outs', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, StockOutModel.fromJson);
  }

  Future<StockOutModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/stock-outs/$id');
    return StockOutModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<StockOutModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/stock-outs', data: payload);
    return StockOutModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<StockOutModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/stock-outs/$id', data: payload);
    return StockOutModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/stock-outs/$id');
}

final stockOutsServiceProvider = Provider((ref) => StockOutsService(ref));
