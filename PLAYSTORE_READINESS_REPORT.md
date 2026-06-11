# Play Store 출시 준비 상태 분석 보고서

**분석 일시**: 2026-06-11  
**분석 대상**: google_dashboard (Flutter + Android Native)  
**분석자**: Claude Code (프로 개발자 시각)

---

## 최종 판정: 출시 불가 (5개 차단 요소)

---

## CRITICAL — 출시 즉시 차단 가능

### 1. Release 빌드가 Debug 키로 서명됨
**파일**: `android/app/build.gradle.kts:33`

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")  // ← Play Store 업로드 불가
}
```

Play Store는 debug keystore로 서명된 APK를 업로드 자체를 거부합니다.  
이것만으로도 출시 불가. Release keystore 생성 및 서명 설정 필수.

**해결 방법**:
```bash
# 1. keystore 생성
keytool -genkey -v -keystore release.keystore -alias mykey -keyalg RSA -keysize 2048 -validity 10000

# 2. build.gradle.kts에 signingConfig 추가
signingConfigs {
    create("release") {
        storeFile = file("release.keystore")
        storePassword = System.getenv("STORE_PASSWORD")
        keyAlias = "mykey"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
release {
    signingConfig = signingConfigs.getByName("release")
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
}
```

---

### 2. `android:usesCleartextTraffic="true"`
**파일**: `android/app/src/main/AndroidManifest.xml:12`

```xml
android:usesCleartextTraffic="true"
```

Google API는 전부 HTTPS라 실제 HTTP 통신은 없지만, Play Store 보안 정책 검토에서 플래그가 잡힙니다.  
특히 Gmail 접근 앱에서 이 설정은 출시 거부 사유가 될 수 있습니다.

**해결 방법**: 해당 속성 줄 제거 (기본값이 `false`이므로 별도 설정 불필요)

---

### 3. 앱 이름이 `google_dashboard`
**파일**: `android/app/src/main/AndroidManifest.xml:9`, `pubspec.yaml:1`

```xml
android:label="google_dashboard"
```

Google 브랜드 가이드라인에 따라 **"Google"이 포함된 앱 이름은 Play Store 출시 거부** 대상입니다.  
Google의 공식 파트너가 아닌 이상 불가.

**해결 방법**: 앱 이름을 "Dashboard", "MyBoard", "통합 대시보드" 등으로 변경

---

### 4. Google API OAuth 민감 권한 심사 미진행
Gmail, Google Calendar, Google Tasks는 Google이 **"민감한 범위(Sensitive Scopes)"** 로 분류합니다.  
앱을 일반 사용자에게 배포하려면 Google의 별도 OAuth 심사(보안 평가)를 통과해야 합니다.

- 심사 소요 기간: **1~4주**
- 심사 없이 배포 시: 본인 계정 포함 100명까지만 사용 가능 (테스트 모드)
- 필요 서류: 앱 데모 영상, 개인정보 보호정책 URL, 보안 평가서

**해결 방법**: Google Cloud Console → OAuth 동의 화면 → "앱 게시" 신청

---

### 5. 개인정보 보호정책 없음
Gmail 접근 앱은 Play Store 필수 요건으로 **반드시 개인정보 보호정책 URL**이 있어야 합니다.  
없으면 앱 등록 단계에서 차단됩니다.

**해결 방법**: GitHub Pages, Notion 등에 개인정보 보호정책 페이지 생성 후 URL 등록

---

## HIGH — 기기 호환성/안정성 문제

### 6. Adaptive Icon 없음
```
mipmap-hdpi/ic_launcher.png    ← 레거시 PNG만 존재
mipmap-anydpi-v26/             ← 없음 (Android 8.0+ 어댑티브 아이콘)
```

Android 8.0(API 26)부터 어댑티브 아이콘이 표준입니다.  
없으면 Play Store 등록 화면, 홈 런처에서 아이콘이 잘리거나 흰 배경으로 표시됩니다.

**해결 방법**: Android Studio → Image Asset 도구로 어댑티브 아이콘 생성

---

### 7. `cover_widget_info.xml` 없음 — 커버 위젯 등록 불완전
`cover_widget_layout.xml`은 존재하지만 `cover_widget_info.xml`이 없고  
`AndroidManifest.xml`에 커버 위젯 `<receiver>` 등록 여부 확인 필요.

안티그래비티(AI 에디터)가 레이아웃 파일만 생성하고 실제 등록을 누락했을 가능성 있음.

**확인 방법**: `AndroidManifest.xml`에서 `CoverWidgetProvider` 또는 유사한 receiver 존재 여부 검색

---

### 8. JobService Thread + jobFinished() 구조 불안정
**파일**: `GmailSyncJobService.kt:25-35`

```kotlin
Thread {
    executeSyncInternal(ctx)
    jobFinished(params, false)  // Thread 내에서 호출
}.start()
return true
```

`onStopJob`이 먼저 호출되면 Thread가 종료되기 전에 params가 무효화되어 `jobFinished()`가 죽거나 무시됩니다.  
Samsung 기기에서 배터리 최적화가 공격적으로 작동할 때 위젯 동기화가 무작위로 멈추는 원인.

**영향 기기**: Samsung Galaxy 계열, Xiaomi, OPPO (배터리 최적화 공격적 제조사)

---

### 9. 위젯 갱신 시 SharedPreferences ~200회 반복 읽기
**파일**: `HomeWidgetProvider.kt:328~884` (캘린더 그리드 루프)

```
42개 날짜 셀 × 루프당 4~5회 prefs.getString() = ~200회 I/O 호출
```

저가 기기(RAM 2GB 이하)에서 위젯 갱신 한 번에 최대 1초 이상 걸릴 수 있으며,  
ANR(Application Not Responding) 또는 위젯 업데이트 실패로 이어질 수 있습니다.

**해결 방법**: 루프 시작 전 전체 prefs를 Map으로 한 번에 로드 후 캐싱

---

### 10. `updatePeriodMillis="900000"` — 실제 동작과 불일치
**파일**: `android/app/src/main/res/xml/home_widget_info.xml:7`

```xml
android:updatePeriodMillis="900000"  <!-- 15분으로 설정 -->
```

Android는 이 값을 **최소 30분(1800000ms)으로 강제 클램핑**합니다.  
기기 재부팅 후 첫 자동 갱신까지 최대 30분 공백이 생깁니다.  
(사용자가 위젯을 직접 탭하는 경우는 즉시 갱신으로 보완됨)

---

## MEDIUM — 코드 품질 개선 필요

### 11. 예외 처리 전반적 미흡
```dart
} catch (_) {}  // 여러 곳에 존재 (widget_service.dart, main_screen.dart 등)
```

출시 앱에서 에러를 조용히 무시하면 사용자 버그 리포트가 와도 재현이 불가능합니다.  
최소한 `debugPrint()` 추가, 이상적으로는 Firebase Crashlytics 연동 권장.

---

### 12. Dio interceptor 경합 상태 (동시 401 처리)
**파일**: `lib/core/api_client.dart:39-53`

```dart
if (err.response?.statusCode == 401 && !_isRefreshing) {
    _isRefreshing = true;
    try {
        final newToken = await getToken();
        _isRefreshing = false;  // ← finally 블록이 아님
        // ...
    } catch (_) {
        _isRefreshing = false;
    }
}
```

2개 이상의 API 요청이 동시에 401을 받으면 토큰 갱신이 2중으로 실행될 수 있습니다.

**해결 방법**: `_isRefreshing = false`를 `finally` 블록으로 이동

---

### 13. 테스트 코드 없음
```
dev_dependencies:
  flutter_test:   ← SDK만 있고 test/ 디렉토리 내 파일 없음
```

다양한 기기 대응 앱에서 테스트 없이 회귀 방어가 불가능합니다.  
Play Store 자체는 테스트를 강제하지 않지만, 출시 후 업데이트 안정성에 직결됩니다.

---

### 14. ProGuard/R8 설정 없음
Release 빌드에 코드 난독화 및 최적화가 적용되지 않아:
- APK 크기가 불필요하게 큼
- 역컴파일 보호 없음
- Dead code 제거 안 됨

**해결 방법**: `android/app/proguard-rules.pro` 생성 및 build.gradle.kts에 연결

---

## LOW — Play Store 등록 필수 항목 (코드 외)

| 항목 | 현재 상태 | 비고 |
|------|----------|------|
| 개인정보 보호정책 URL | 없음 | Gmail 접근 앱 필수 |
| 콘텐츠 등급 설문 | 미작성 | 등록 시 직접 작성 |
| 스토어 스크린샷 | 없음 | 최소 2장 필수 |
| 앱 설명 (한/영) | 없음 | 등록 시 작성 |
| 앱 이름 | google_dashboard | 변경 필수 (항목 3 참고) |
| Feature Graphic (1024×500) | 없음 | Play Store 헤더 이미지 |
| OAuth 동의 화면 앱 이름 | 미설정 | Google Cloud Console 변경 필요 |

---

## 출시까지 필요한 작업 로드맵

### Phase 1 — 필수 차단 해제 (1~3일)
1. 앱 이름 변경 (google 제거)
2. `usesCleartextTraffic` 제거
3. Release keystore 생성 및 서명 설정 적용
4. Adaptive Icon 생성

### Phase 2 — Google 심사 신청 (별도 진행, 1~4주 소요)
5. Google Cloud Console OAuth 동의 화면 설정
6. 개인정보 보호정책 작성 및 호스팅
7. Google OAuth 민감 권한 심사 신청 (데모 영상 필요)

### Phase 3 — 품질 개선 (Phase 2 진행 중 병행)
8. ProGuard 설정 추가
9. 위젯 SharedPreferences 성능 최적화
10. 커버 위젯 등록 상태 점검

### Phase 4 — Play Store 등록
11. 스토어 스크린샷 캡처 (다양한 기기)
12. 앱 설명 작성
13. 콘텐츠 등급 설문 작성
14. 내부 테스트 트랙 → 공개 테스트 → 프로덕션 순차 배포

---

## 참고: 현재 잘 된 부분

- **targetSdk = 36** (flutter.targetSdkVersion 기본값) — Play Store 요구사항(34+) 충족
- **minSdk = 24** — Android 7.0 이상 지원, 합리적
- **토큰 보안** — flutter_secure_storage + EncryptedSharedPreferences 사용, 적절
- **64비트 지원** — Flutter가 arm64-v8a 자동 빌드
- **MailPoller dispose** — `_poller?.stop()` 정확히 구현됨
- **Dio timeout 설정** — 15s connect / 30s receive, 적절
- **WorkManager 초기화** — `App.kt`에서 예외 처리 포함한 안전한 초기화 구현

---

*본 보고서는 2026-06-11 기준 코드베이스 직접 분석 결과입니다.*
