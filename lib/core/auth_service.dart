import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _scopes = [
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/gmail.modify',
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

  Future<void> _init() async {
    _googleSignIn.onCurrentUserChanged.listen((user) async {
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
    } catch (_) {}
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
    state = const AsyncValue.data(null);
  }

  Future<String?> getAccessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    try {
      final auth = await user.authentication;
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }
}

// 어디서든 쉽게 토큰을 가져오는 글로벌 헬퍼
Future<String?> getStoredToken() async {
  return _storage.read(key: 'access_token');
}
