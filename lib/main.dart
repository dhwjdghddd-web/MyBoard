import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app.dart';
import 'core/notification_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase Crashlytics 초기화. 설정 누락/실패 시에도 앱은 정상 구동되도록
    // try/catch 로 감싸고, 실패하면 기존 debugPrint 로깅으로 폴백한다.
    var crashlyticsReady = false;
    try {
      await Firebase.initializeApp();
      crashlyticsReady = true;
    } catch (e) {
      debugPrint('Firebase 초기화 실패(크래시 리포트 비활성): $e');
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (crashlyticsReady) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (crashlyticsReady) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('PlatformError: $error\n$stack');
      }
      return true;
    };

    await NotificationService.init();
    runApp(const ProviderScope(child: GoogleDashboardApp()));
  }, (error, stack) {
    debugPrint('ZoneError: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {/* Firebase 미초기화 시 무시 */}
  });
}
