import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/user.dart';

class ProfileService {
  final Ref ref;
  ProfileService(this.ref);

  Future<UserModel> update({required String name, required String email}) async {
    final res = await ref.read(dioProvider).put('/profile', data: {'name': name, 'email': email});
    return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateAvatar(String filePath) async {
    final formData = FormData.fromMap({'avatar': await MultipartFile.fromFile(filePath)});
    final res = await ref.read(dioProvider).post('/profile/avatar', data: formData);
    return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> updatePassword({required String currentPassword, required String newPassword}) {
    return ref.read(dioProvider).put(
      '/profile/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }
}

final profileServiceProvider = Provider((ref) => ProfileService(ref));
