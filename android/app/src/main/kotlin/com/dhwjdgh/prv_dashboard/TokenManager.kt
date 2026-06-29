package com.dhwjdgh.prv_dashboard

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.google.android.gms.auth.api.signin.GoogleSignIn

/**
 * 모든 Sync 서비스와 Activity에서 공통으로 사용하는 토큰 관리 유틸리티.
 * EncryptedSharedPreferences에서 캐시된 토큰을 읽거나,
 * GoogleAuthUtil을 통해 새 토큰을 발급받습니다.
 */
object TokenManager {
    private const val TAG = "TokenManager"

    // ⚠️ 결합 주의: 아래 두 상수는 Flutter 의 flutter_secure_storage 플러그인이
    // 내부적으로 쓰는 SharedPreferences 파일명("FlutterSecureStorage")과,
    // 키 'access_token' 을 플러그인이 해싱한 실제 저장 키 이름이다.
    // flutter_secure_storage 를 업그레이드하면 키 해싱/파일명 규칙이 바뀌어
    // readCachedToken() 이 조용히 null 을 반환할 수 있다.
    //   → 그 경우에도 fetchFreshToken()(GoogleAuthUtil) 으로 자동 폴백되어
    //     기능은 유지되지만, 위젯 동작이 매번 새 토큰 발급으로 느려진다.
    //   ★ 플러그인 버전을 올릴 때는 반드시 위젯 토큰 캐시 동작을 재검증하고,
    //     깨졌으면 아래 상수를 새 키 이름으로 갱신할 것.
    private const val SECURE_PREFS_NAME = "FlutterSecureStorage"
    private const val TOKEN_KEY = "VGtWcmJHbHVaMjl1_access_token"

    @Volatile private var espInstance: android.content.SharedPreferences? = null

    private fun getEsp(context: Context): android.content.SharedPreferences {
        return espInstance ?: synchronized(this) {
            espInstance ?: run {
                val alias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
                EncryptedSharedPreferences.create(
                    SECURE_PREFS_NAME, alias, context.applicationContext,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                ).also { espInstance = it }
            }
        }
    }

    /**
     * EncryptedSharedPreferences에서 캐시된 액세스 토큰을 읽습니다.
     */
    fun readCachedToken(context: Context): String? = runCatching {
        getEsp(context).getString(TOKEN_KEY, null)
    }.onFailure { Log.w(TAG, "readCachedToken failed", it) }.getOrNull()

    /**
     * GoogleAuthUtil을 통해 새 토큰을 발급받습니다.
     * @param scope OAuth 스코프 문자열 (예: "oauth2:https://www.googleapis.com/auth/tasks")
     */
    fun fetchFreshToken(context: Context, scope: String): String? = runCatching {
        val acct = GoogleSignIn.getLastSignedInAccount(context) ?: return null
        val account = acct.account ?: return null
        com.google.android.gms.auth.GoogleAuthUtil.getToken(context, account, scope)
    }.onFailure { Log.w(TAG, "fetchFreshToken failed", it) }.getOrNull()

    /**
     * 캐시된 토큰을 EncryptedSharedPreferences에 저장합니다.
     */
    fun writeCachedToken(context: Context, token: String) {
        runCatching {
            getEsp(context).edit().putString(TOKEN_KEY, token).apply()
        }.onFailure { Log.w(TAG, "writeCachedToken failed", it) }
    }

    /**
     * 캐시된 토큰을 무효화합니다 (401 응답 후 사용).
     */
    fun invalidateToken(context: Context, token: String) {
        runCatching {
            com.google.android.gms.auth.GoogleAuthUtil.invalidateToken(context, token)
        }.onFailure { Log.w(TAG, "invalidateToken failed", it) }
    }
}
