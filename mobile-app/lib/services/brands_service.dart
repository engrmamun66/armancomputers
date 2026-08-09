import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/brand.dart';
import '../models/paginated.dart';

class BrandsService {
  final Ref ref;
  BrandsService(this.ref);

  Future<PaginatedResponse<BrandModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/brands', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, BrandModel.fromJson);
  }

  Future<List<BrandModel>> all() async {
    final res = await ref.read(dioProvider).get('/brands', queryParameters: {'per_page': 100});
    return (res.data['data'] as List).map((e) => BrandModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BrandModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/brands', data: payload);
    return BrandModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<BrandModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/brands/$id', data: payload);
    return BrandModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/brands/$id');
}

final brandsServiceProvider = Provider((ref) => BrandsService(ref));
