import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getToken: () => ref.read(authServiceProvider.notifier).getAccessToken(),
    onAuthError: () => ref.read(authServiceProvider.notifier).signOut(),
  );
});

class ApiClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  ApiClient({
    required Future<String?> Function() getToken,
    required VoidCallback onAuthError,
  }) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (!options.headers.containsKey('Content-Type')) {
            options.headers['Content-Type'] = 'application/json';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401 && !_isRefreshing) {
            _isRefreshing = true;
            String? newToken;
            try {
              newToken = await getToken();
            } catch (e) {
              debugPrint('토큰 갱신 요청 실패: $e');
            } finally {
              _isRefreshing = false;
            }

            if (newToken != null) {
              try {
                err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                final response = await _dio.fetch(err.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                debugPrint('재시도 요청 실패: $e');
              }
            }
            // 갱신 실패 → 로그아웃 유도
            debugPrint('인증 토큰 갱신 실패 — 자동 로그아웃');
            onAuthError();
          }
          handler.next(err);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false, error: true),
      );
    }
  }

  Future<dynamic> get(String url, {Map<String, dynamic>? params}) async {
    final r = await _dio.get(url, queryParameters: params);
    return r.data;
  }

  Future<dynamic> post(String url, {dynamic body}) async {
    final r = await _dio.post(url, data: body);
    return r.data;
  }

  Future<dynamic> patch(String url, {dynamic body}) async {
    final r = await _dio.patch(url, data: body);
    return r.data;
  }

  Future<void> delete(String url) async {
    await _dio.delete(url);
  }
}

// 서비스 레이어에서 공통으로 쓰는 에러 메시지 변환
String apiErrorMessage(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '연결 시간이 초과되었습니다.';
      case DioExceptionType.connectionError:
        return '네트워크에 연결할 수 없습니다.';
      default:
        final status = e.response?.statusCode;
        if (status != null) return 'HTTP $status 오류가 발생했습니다.';
    }
  }
  return '알 수 없는 오류가 발생했습니다.';
}
