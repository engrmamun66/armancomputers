import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/product.dart';

class ProductsService {
  final Ref ref;
  ProductsService(this.ref);

  Future<PaginatedResponse<ProductModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/products', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, ProductModel.fromJson);
  }

  Future<List<ProductModel>> search(String query) async {
    final res = await ref.read(dioProvider).get('/products', queryParameters: {'search': query, 'per_page': 8});
    return (res.data['data'] as List).map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/products/$id');
    return ProductModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<ProductModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/products', data: payload);
    return ProductModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<ProductModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/products/$id', data: payload);
    return ProductModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/products/$id');

  Future<ProductImageModel> uploadImage(int productId, String filePath, {bool isDefault = false}) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
      if (isDefault) 'is_default': '1',
    });
    final res = await ref.read(dioProvider).post('/products/$productId/images', data: formData);
    return ProductImageModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteImage(int productId, int imageId) =>
      ref.read(dioProvider).delete('/products/$productId/images/$imageId');

  Future<void> setDefaultImage(int productId, int imageId) =>
      ref.read(dioProvider).patch('/products/$productId/images/$imageId/default');

  Future<List<StockHistoryEntry>> stockHistory(int id) async {
    final res = await ref.read(dioProvider).get('/products/$id/stock-history');
    final history = (res.data['data'] as Map<String, dynamic>)['history'] as List;
    return history.map((e) => StockHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final productsServiceProvider = Provider((ref) => ProductsService(ref));
