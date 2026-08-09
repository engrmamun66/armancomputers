import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/customer.dart';
import '../models/paginated.dart';

class CustomersService {
  final Ref ref;
  CustomersService(this.ref);

  Future<PaginatedResponse<CustomerModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/customers', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, CustomerModel.fromJson);
  }

  Future<List<CustomerRef>> search(String query) async {
    final res = await ref.read(dioProvider).get('/customers', queryParameters: {'search': query, 'per_page': 8});
    return (res.data['data'] as List).map((e) => CustomerRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/customers/$id');
    return CustomerModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<CustomerModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/customers', data: payload);
    return CustomerModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<CustomerModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/customers/$id', data: payload);
    return CustomerModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/customers/$id');
}

final customersServiceProvider = Provider((ref) => CustomersService(ref));
