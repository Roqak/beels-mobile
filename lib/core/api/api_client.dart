import 'package:dio/dio.dart';

import '../config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

/// Thin dio wrapper: bearer auth, 401 handling, and error normalization.
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    required void Function() onUnauthorized,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        _onUnauthorized = onUnauthorized,
        _dio = dio ?? _defaultDio() {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken));
  }

  final TokenStore _tokenStore;
  final void Function() _onUnauthorized;
  final Dio _dio;

  static Dio _defaultDio() => Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      );

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() send) async {
    try {
      final response = await send();
      return response.data;
    } on DioException catch (e) {
      throw await _asApiException(e);
    }
  }

  Future<ApiException> _asApiException(DioException e) async {
    final response = e.response;
    if (response?.statusCode == 401) {
      await _tokenStore.clear();
      _onUnauthorized();
      return ApiException.fromResponse(response?.data, 401);
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'You appear to be offline. Check your connection.',
          statusCode: 0,
        );
      default:
        if (response != null) {
          return ApiException.fromResponse(
            response.data,
            response.statusCode ?? 0,
          );
        }
        return const ApiException(
          'Something went wrong. Please try again.',
          statusCode: 0,
        );
    }
  }
}
