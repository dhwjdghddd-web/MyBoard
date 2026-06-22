import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'widget_service.dart';

const _scopes = [
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/calendar.readonly',
];

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final _googleSignIn = GoogleSignIn(scopes: _scopes);

final authServiceProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<GoogleSignInAccount?>>((ref) {
  return AuthNotifier();
});

/// 현재 로그인 계정의 id. 데이터 provider(tasks/calendar/gmail)가 이 값을 watch 하여
/// 계정이 바뀌면(로그아웃·전환) Riverpod 의존성 그래프가 자동으로 notifier 를 재생성
/// → 이전 계정 데이터가 새 계정 화면에 남지 않도록 한다.
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).valueOrNull?.id;
});

class AuthNotifier extends StateNotifier<AsyncValue<GoogleSignInAccount?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _sub = _googleSignIn.onCurrentUserChanged.listen((user) async {
      state = AsyncValue.data(user);
      if (user != null) await _cacheToken(user);
    });

    try {
      final user = await _googleSignIn.signInSilently();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _cacheToken(GoogleSignInAccount user) async {
    try {
      final auth = await user.authentication;
      if (auth.accessToken != null) {
        await _storage.write(key: 'access_token', value: auth.accessToken!);
      }
    } catch (e) {
      debugPrint('토큰 캐시 실패: $e');
    }
  }

  Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: 'access_token');
    await WidgetService.clearAllData();
    state = const AsyncValue.data(null);
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    var user = _googleSignIn.currentUser;
    if (user == null) {
      user = await _googleSignIn.signInSilently();
      if (user == null) return null;
    }
    try {
      if (forceRefresh) await user.clearAuthCache();
      final auth = await user.authentication;
      if (auth.accessToken != null) await _cacheToken(user);
      return auth.accessToken;
    } catch (e) {
      debugPrint('토큰 갱신 실패: $e');
      return null;
    }
  }
}
