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
    private const val SECURE_PREFS_NAME = "FlutterSecureStorage"
    private const val TOKEN_KEY = "VGtWcmJHbHVaMjl1_access_token"

    /**
     * EncryptedSharedPreferences에서 캐시된 액세스 토큰을 읽습니다.
     */
    fun readCachedToken(context: Context): String? = runCatching {
        val alias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            SECURE_PREFS_NAME, alias, context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        ).getString(TOKEN_KEY, null)
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
            val alias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            EncryptedSharedPreferences.create(
                SECURE_PREFS_NAME, alias, context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            ).edit().putString(TOKEN_KEY, token).apply()
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
