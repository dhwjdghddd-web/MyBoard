# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class org.chromium.** { *; }

# Ignore missing Play Core classes referenced by Flutter engine
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# AndroidX Security Crypto (EncryptedSharedPreferences)
-keep class androidx.security.crypto.** { *; }

# Google Auth
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# App-specific classes referenced by AndroidManifest
-keep class com.dhwjdgh.prv_dashboard.HomeWidgetProvider { *; }
-keep class com.dhwjdgh.prv_dashboard.TaskWidgetService { *; }
-keep class com.dhwjdgh.prv_dashboard.TaskWidgetServiceCover { *; }
-keep class com.dhwjdgh.prv_dashboard.GmailWidgetService { *; }
-keep class com.dhwjdgh.prv_dashboard.GmailWidgetServiceCover { *; }
-keep class com.dhwjdgh.prv_dashboard.CalendarSyncJobService { *; }
-keep class com.dhwjdgh.prv_dashboard.GmailSyncJobService { *; }
-keep class com.dhwjdgh.prv_dashboard.TasksSyncJobService { *; }
-keep class com.dhwjdgh.prv_dashboard.TokenManager { *; }
