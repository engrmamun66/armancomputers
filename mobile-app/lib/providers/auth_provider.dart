import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading; // initial bootstrap (reading stored token)
  final bool isAuthenticated;

  const AuthState({this.user, this.isLoading = true, this.isAuthenticated = false});

  AuthState copyWith({UserModel? user, bool? isLoading, bool? isAuthenticated}) => AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );

  String get roleSlug => user?.role?.slug ?? '';

  bool hasAnyRole(List<String> roles) => roles.contains(roleSlug);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState()) {
    ref.read(apiClientProvider).onUnauthorized = () => forceLogout();
    _bootstrap();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> _bootstrap() async {
    final token = await TokenStorage.instance.read();
    if (token == null) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
      return;
    }
    try {
      final response = await _dio.get('/auth/me');
      final user = UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
      state = AuthState(user: user, isLoading: false, isAuthenticated: true);
    } catch (_) {
      await TokenStorage.instance.clear();
      state = const AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      final data = response.data['data'] as Map<String, dynamic>;
      await TokenStorage.instance.write(data['token'] as String);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(user: user, isLoading: false, isAuthenticated: true);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Best-effort — clear local session regardless of server response.
    }
    await forceLogout();
  }

  Future<void> forceLogout() async {
    await TokenStorage.instance.clear();
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
