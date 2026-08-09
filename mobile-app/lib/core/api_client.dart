import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Set by AuthProvider at app start; called when the API returns 401 so the
/// whole app can react (clear session, redirect to login) without api_client
/// needing to import the provider layer directly.
typedef UnauthorizedHandler = void Function();

class ApiClient {
  final Dio dio;
  UnauthorizedHandler? onUnauthorized;

  ApiClient._(this.dio);

  factory ApiClient() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    final client = ApiClient._(dio);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            client.onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    return client;
  }

  /// Normalizes any Dio error into an ApiException with the backend's
  /// message + field errors, so UI code never touches DioException directly.
  static ApiException toApiException(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String? ?? 'Something went wrong.';
        final rawErrors = data['errors'];
        Map<String, List<String>>? errors;
        if (rawErrors is Map) {
          errors = rawErrors.map(
            (key, value) => MapEntry(key.toString(), (value as List).map((e) => e.toString()).toList()),
          );
        }
        return ApiException(message, errors: errors, statusCode: error.response?.statusCode);
      }
      if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
        return ApiException('Could not reach the server. Check your connection.');
      }
      return ApiException('Something went wrong. Please try again.');
    }
    return ApiException(error.toString());
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
