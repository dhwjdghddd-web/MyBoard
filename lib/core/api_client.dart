import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'l10n_helper.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getToken: () => ref.read(authServiceProvider.notifier).getAccessToken(),
    refreshToken: () => ref.read(authServiceProvider.notifier).getAccessToken(forceRefresh: true),
    onAuthError: () => ref.read(authServiceProvider.notifier).signOut(),
  );
});

class ApiClient {
  late final Dio _dio;
  Completer<String?>? _refreshCompleter;

  ApiClient({
    required Future<String?> Function() getToken,
    required Future<String?> Function() refreshToken,
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
          // 재시도는 1회로 제한 — 갱신 후에도 401이면 무한 루프 방지
          if (err.response?.statusCode == 401 &&
              err.requestOptions.extra['retried'] != true) {
            String? newToken;
            if (_refreshCompleter != null) {
              // 다른 요청이 이미 토큰 갱신 중 — 완료될 때까지 대기
              try {
                newToken = await _refreshCompleter!.future;
              } catch (_) {
                newToken = null;
              }
            } else {
              // 첫 번째 401 — 캐시 무효화 후 강제 갱신
              _refreshCompleter = Completer<String?>();
              try {
                newToken = await refreshToken();
                _refreshCompleter!.complete(newToken);
              } catch (e) {
                debugPrint('토큰 갱신 요청 실패: $e');
                _refreshCompleter!.completeError(e);
                newToken = null;
              } finally {
                _refreshCompleter = null;
              }
            }

            if (newToken != null) {
              try {
                err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                err.requestOptions.extra['retried'] = true;
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
        LogInterceptor(requestHeader: false, requestBody: false, responseBody: false, error: true),
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
  final l = appL10n();
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return l.errorTimeout;
      case DioExceptionType.connectionError:
        return l.errorNetwork;
      default:
        final status = e.response?.statusCode;
        if (status != null) return l.errorHttpStatus(status);
    }
  }
  return l.errorUnknown;
}
