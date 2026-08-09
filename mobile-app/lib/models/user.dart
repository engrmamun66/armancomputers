import '../core/api_config.dart';
import 'lookup.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? lastLoginAt;
  final String? createdAt;
  final RoleModel? role;
  final StatusModel? status;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.lastLoginAt,
    this.createdAt,
    this.role,
    this.status,
  });

  String? get avatarUrl => avatar == null ? null : ApiConfig.resolveUrl(avatar!);

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        avatar: json['avatar'] as String?,
        lastLoginAt: json['last_login_at'] as String?,
        createdAt: json['created_at'] as String?,
        role: json['role'] != null ? RoleModel.fromJson(json['role'] as Map<String, dynamic>) : null,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
      );
}
