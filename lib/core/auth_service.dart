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
  'https://www.googleapis.com/auth/gmail.readonly',
];

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final _googleSignIn = GoogleSignIn(scopes: _scopes);

final authServiceProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<GoogleSignInAccount?>>((ref) {
  return AuthNotifier();
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
        // 토큰 캐시 시간 기록 (Google 토큰은 보통 1시간 유효)
        await _storage.write(
          key: 'access_token_cached_at',
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        );
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
    await _storage.delete(key: 'access_token_cached_at');
    await WidgetService.clearAllData();
    state = const AsyncValue.data(null);
  }

  Future<String?> getAccessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    try {
      final auth = await user.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint('토큰 갱신 실패: $e');
      return null;
    }
  }
}
