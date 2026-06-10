# Google Workspace Dashboard - Android App

## 이 파일의 역할
Claude Code에게 주는 프로젝트 전체 명세서입니다.
같은 폴더에 있는 `index.html`은 동일 기능을 구현한 웹 버전입니다.
API 호출 방식, 엔드포인트, 응답 처리 로직을 참고하되
UI는 모바일에 맞게 새로 설계해주세요.

---

## 프로젝트 목표

Google Tasks + Google Calendar + Gmail을 하나의 앱에서 관리하는
**Android 전용 Flutter 앱**을 만든다.

- 누구나 자신의 Google 계정으로 로그인해서 사용 가능
- 공개 배포 목적 (Play Store)
- 홈화면 위젯 포함

---

## 기술 스택

| 항목 | 선택 |
|------|------|
| Framework | Flutter (최신 안정 버전) |
| 언어 | Dart |
| 상태관리 | Riverpod |
| Google 인증 | google_sign_in |
| HTTP | dio |
| 홈화면 위젯 | home_widget |
| 로컬 저장 | shared_preferences |
| 토큰 저장 | flutter_secure_storage |
| 메일 본문 렌더링 | flutter_inappwebview |
| 로컬 알림 | flutter_local_notifications |

---

## Google API 스코프

```dart
const List<String> scopes = [
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/gmail.modify',
];
```

> ⚠️ **절대 `mail.google.com/` 스코프를 사용하지 말 것.**
>
> - `mail.google.com/`은 Restricted 스코프로 공개 배포 시
>   Google 보안 감사(유료, 수백만원~)가 필요하다.
> - `gmail.modify`로 할 수 없는 것: 메시지 영구 삭제
> - 대안: 영구 삭제 대신 휴지통 이동으로 대체
>   (Gmail은 휴지통 30일 후 자동 영구 삭제)

---

## 폴더 구조

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── api_client.dart         ← 공통 HTTP 클라이언트 (토큰 자동 첨부)
│   ├── auth_service.dart       ← Google Sign-In, 토큰 관리
│   └── theme.dart              ← 다크/라이트 테마
├── features/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── tasks/
│   │   ├── task_service.dart
│   │   ├── tasks_screen.dart
│   │   └── add_task_sheet.dart
│   ├── calendar/
│   │   ├── calendar_service.dart
│   │   ├── calendar_screen.dart
│   │   ├── event_form_screen.dart
│   │   └── event_detail_sheet.dart
│   └── gmail/
│       ├── gmail_service.dart
│       ├── gmail_screen.dart
│       └── email_detail_screen.dart
└── widget/
    └── app_widget.dart         ← home_widget 연동
```

---

## 화면 구성

### 로그인 화면
- Google 로그인 버튼 (Google 브랜드 가이드라인 준수)
- 로그인 성공 → 메인 화면으로 이동
- 이미 로그인된 경우 자동으로 메인으로 이동

### 메인 화면 (하단 탭바)
```
[ ✅ 태스크 ] [ 📅 캘린더 ] [ 📧 Gmail ]
```

---

## 기능 명세

### ✅ 태스크

**목록 화면**
- Google Tasks 첫 번째 리스트 로드
- 미완료 태스크 → 완료 태스크 순서로 표시
- 각 항목 표시: 제목 / 마감일(있으면, 초과 시 빨간색) / 메모
- 체크박스 탭 → 완료/미완료 즉시 전환
- 스와이프 → 삭제
- 우하단 FAB(+) → 추가 시트 열림

**추가 시트 (BottomSheet)**
- 제목 입력 (필수)
- 마감일 선택 (DatePicker, 선택사항)
- 메모 입력 (선택사항)

**참고: index.html 함수**
- `loadTasks()`, `addTask()`, `co()`, `unco()`, `delT()`

---

### 📅 캘린더

**월간 그리드**
- 7열 × 5~6행 그리드
- 각 날짜 셀에 이벤트 표시 (실제 구글 캘린더 색상)
- 마감일 있는 태스크 → 파란 점으로 표시 (index.html의 `addTasksToCal()` 참고)
- 이전/다음 달 이동 버튼 / 오늘 버튼

**캘린더 필터 (중요)**
- 사용자가 보고 싶은 캘린더만 선택할 수 있어야 함
- 예: 공휴일 캘린더, 특정 업무 캘린더 숨기기
- 설정은 SharedPreferences에 저장 (`g-cal-filter` 키)
- `loadCalendar()` 시 비활성화된 캘린더는 건너뜀
- index.html의 `setCalFilter()`, `renderCalFilterList()` 참고

**날짜 탭 시**
- 하단 시트로 해당 날 일정 목록 표시
- 일정마다 제목 / 시간 / 캘린더명 / 색상 표시
- "+ 새 일정" 버튼

**일정 생성/수정 폼** (하나의 폼으로 생성·수정 모두 처리)
- 제목 (필수)
- 종일 토글
- 날짜 / 시작시간 / 종료시간
- 반복 설정 (없음 / 매일 / 주중 / 매주 / 매월 / 매년)
- 장소
- 설명
- 초대 이메일 (쉼표 구분)
- 알림 (팝업/이메일, N분 전)
- 캘린더 선택 (각 캘린더 실제 색상 동그라미 표시)
- 이벤트 색상 선택 (11가지 구글 캘린더 색상)

**색상 로드 (index.html의 `loadCalColors()` 참고)**
- `GET /calendar/v3/colors` → 이벤트 색상 팔레트 11개
- `GET /calendar/v3/users/me/calendarList` → 캘린더별 실제 색상

**참고: index.html 함수**
- `loadCalColors()`, `loadCalendar()`, `renderCalGrid()`, `showEF()`, `saveEF()`, `delEv()`

---

### 📧 Gmail

**편지함 선택**
- 상단 드롭다운 또는 드로어
- 받은편지함 / 중요편지함 / 보낸편지함 / 스팸 / 휴지통
- 각 편지함 미읽음 수 뱃지

**메일 목록**
- 보낸사람 이니셜 아바타 (랜덤 색상)
- 보낸사람 / 제목 / 미리보기 / 날짜
- 미읽음 메일 굵은 글씨 + 파란 점
- 당겨서 새로고침
- 검색창
- 전체선택 → 일괄 삭제(휴지통 이동) / 읽음처리
- 스와이프 좌 → 삭제(휴지통 이동)
- 스와이프 우 → 읽음처리

**메일 상세 (중요: 다크모드 처리)**

> ⚠️ **반드시 아래 방식으로 HTML 이메일을 렌더링할 것**
>
> 안드로이드 Chrome은 강제 다크모드 기능으로
> WebView 내 콘텐츠도 강제로 어둡게 만든다.
> 배경이 어두워지면서 어두운 글씨가 안 보이는 문제가 생긴다.
> `color-scheme: only light`로 이를 막아야 한다.

```dart
// Flutter InAppWebView에서 이메일 렌더링 시
final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="color-scheme" content="only light">
  <style>
    :root { color-scheme: only light; }
    html, body {
      margin: 0; padding: 0;
      background: #ffffff !important;
      color: #202124 !important;
    }
    body {
      padding: 14px;
      font-family: sans-serif;
      font-size: 14px;
      line-height: 1.6;
      word-break: break-word;
    }
    * { max-width: 100%; box-sizing: border-box; }
    img { max-width: 100%; height: auto; }
    a { color: #1a73e8; }
    pre { white-space: pre-wrap; font-family: inherit; }
  </style>
</head>
<body>$emailBody</body>
</html>
''';
```

**메일 상세 - 액션 버튼 (중요: 스팸 해제)**

> 현재 편지함에 따라 버튼 동작이 달라져야 한다:
> - 스팸함에서 보는 메일: "🚫 스팸" 버튼 → "✅ 스팸 해제" 버튼으로 변경
> - 메시지의 labelIds에 'SPAM'이 포함되면 스팸 해제 버튼 표시
> - 스팸 해제: removeLabelIds: ['SPAM'], addLabelIds: ['INBOX']

```dart
// 메시지 열 때 라벨 확인
final isSpam = message.labelIds?.contains('SPAM') ?? false;
// isSpam이면 "스팸 해제" 버튼, 아니면 "스팸 처리" 버튼 표시
```

**메일 상세 - 삭제 동작**

> 현재 편지함에 따라 삭제 동작이 달라져야 한다:
> - 일반 편지함 → 휴지통으로 이동 (POST /messages/{id}/trash)
> - 휴지통 → 영구 삭제 (DELETE /messages/{id}) ← mail.google.com/ 필요
>
> ⚠️ gmail.modify 스코프로는 영구 삭제 불가
> 휴지통에서의 삭제는 "이미 휴지통에 있습니다. 30일 후 자동 삭제됩니다" 안내로 대체

**60초 자동 폴링 (index.html의 `pollMail()` 참고)**
- 로그인 후 60초마다 받은편지함 미읽음 수 확인
- 새 메일 감지 시 로컬 알림 표시
- "📬 새 메일 N개가 도착했습니다"

**휴지통 비우기**
- 휴지통 선택 시 상단에 "비우기" 버튼
- 확인 팝업 → 모든 휴지통 메시지 ID 조회 후 batchDelete
- index.html의 `emptyTrash()` 참고
- batchDelete는 mail.google.com/ 필요하지만
  휴지통 비우기는 사용자 명시적 동의 하에 실행되므로
  이 기능만 별도 스코프 추가 고려 가능

**더 복잡한 작업은 Gmail 앱으로**
```dart
final uri = Uri.parse('googlegmail:///');
await launchUrl(uri, mode: LaunchMode.externalApplication);
// 미설치 시 브라우저로 Gmail 열기
```

**참고: index.html 함수**
- `loadGmail()`, `openMsg()`, `pollMail()`, `emptyTrash()`
- `batchDel()`, `batchRead()`, `unmarkSpam()`

---

## 홈화면 위젯 (home_widget)

**크기**: 4×2 (중간)

**표시 내용**
```
┌─────────────────────────┐
│ 📅 오늘 일정             │
│  • 10:00 팀 미팅        │
│  • 14:00 점심           │
├─────────────────────────┤
│ ✅ 태스크  미완료 3개    │
│  □ 보고서 작성          │
│  □ 이메일 답장          │
├─────────────────────────┤
│ 📧 미읽음 5개           │
└─────────────────────────┘
```

**동작**
- 위젯 전체 탭 → 앱 열기
- 태스크 체크박스 탭 → API 호출 후 위젯 갱신
- 15분마다 자동 갱신
- 위젯 UI는 Kotlin XML로 작성 (Flutter 위젯 재사용 불가)

---

## 다크모드

- 시스템 다크모드 자동 감지
- 앱 내 수동 전환 버튼
- 선택값은 SharedPreferences에 저장

**주의: 이메일 본문은 항상 라이트모드**
앱이 다크모드여도 이메일 본문은 흰 배경 고정.
이메일 디자인이 어두운 배경을 가정하지 않기 때문.
위의 HTML 래퍼 코드 적용 필수.

**라이트 색상**
```dart
primaryColor: Color(0xFF1A73E8),
backgroundColor: Color(0xFFF0F2F5),
surfaceColor: Colors.white,
```

**다크 색상**
```dart
primaryColor: Color(0xFF8AB4F8),
backgroundColor: Color(0xFF121212),
surfaceColor: Color(0xFF1E1E1E),
```

---

## 에러 처리 원칙

- 네트워크 오류 → 스낵바로 안내
- 토큰 만료 → 자동 갱신 시도, 실패 시 재로그인 유도
- 빈 데이터 → 빈 화면 대신 안내 문구 표시
- 오프라인 → 마지막 캐시 데이터 표시 + 오프라인 배너

---

## 보안 원칙

- 토큰은 반드시 `flutter_secure_storage`에 저장
- 클라이언트 ID는 `google-services.json`으로 관리 (하드코딩 금지)
- 메일 본문 렌더링 시 XSS 방지 + 다크모드 강제 차단 처리
- Android 최소 버전: API 24 (Android 7.0)

---

## 개발 순서 (이 순서대로 진행)

1. Flutter 프로젝트 생성 + 의존성 추가
2. Google 로그인 + 토큰 관리
3. 공통 API 클라이언트 (dio + 인터셉터)
4. 태스크 화면 전체
5. 캘린더 화면 전체 (필터 기능 포함)
6. Gmail 화면 전체 (이메일 다크모드 처리 포함)
7. 다크모드 + 테마 정리
8. 홈화면 위젯
9. 60초 폴링 + 로컬 알림
10. 버그 수정 + 최종 점검

> 각 단계 완료 후 사용자 확인을 받고 다음 단계로 넘어갈 것.

---

## 참고 파일

`index.html`: 동일 기능의 웹 구현체.
특히 아래 함수들을 주의 깊게 볼 것:

| 함수 | 참고 내용 |
|------|----------|
| `loadCalColors()` | 캘린더 색상 로드 방법 |
| `loadCalendar()` | 이벤트 로드, 캘린더 필터 적용 |
| `addTasksToCal()` | 태스크 마감일을 캘린더에 표시 |
| `setCalFilter()` | 캘린더 보기 필터 저장/적용 |
| `showEF()` | 일정 생성/수정 통합 폼 |
| `saveEF()` | 일정 저장 API 호출 |
| `pollMail()` | 60초 자동 폴링 |
| `emptyTrash()` | 휴지통 비우기 |
| `unmarkSpam()` | 스팸 해제 |
| `openMsg()` | 메일 열기 + 라벨에 따른 버튼 전환 |
