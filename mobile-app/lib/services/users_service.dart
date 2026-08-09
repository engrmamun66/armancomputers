import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/paginated.dart';
import '../models/user.dart';

class UsersService {
  final Ref ref;
  UsersService(this.ref);

  Future<PaginatedResponse<UserModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/users', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, UserModel.fromJson);
  }

  Future<UserModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/users/$id');
    return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> create(Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).post('/users', data: payload);
    return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> update(int id, Map<String, dynamic> payload) async {
    final res = await ref.read(dioProvider).put('/users/$id', data: payload);
    return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => ref.read(dioProvider).delete('/users/$id');

  Future<void> resetPassword(int id, String password) =>
      ref.read(dioProvider).post('/users/$id/reset-password', data: {'password': password});
}

final usersServiceProvider = Provider((ref) => UsersService(ref));
