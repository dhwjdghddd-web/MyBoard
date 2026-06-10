# 시작 가이드 (내가 참고용 - 폴더에 안 넣어도 됨)

## 폴더에 넣어야 할 파일

```
my-dashboard-app/
├── PROMPT.md       ← Claude Code가 읽는 설계도
└── index.html      ← 웹 버전 (API 로직 참고용)
```

---

## Claude Code에게 처음 할 말

```
PROMPT.md 파일을 먼저 전부 읽어줘.
그리고 index.html도 읽어서 API 로직을 파악해줘.
다 읽었으면 어떤 앱을 만들 건지 요약해서 설명하고,
1단계(Flutter 프로젝트 생성)부터 시작해줘.
각 단계 끝나면 보고하고, 내가 OK 한 다음에 진행해줘.
```

---

## 막히는 상황별 대응

### Google 로그인 설정할 때
SHA-1 지문을 요구하면:
1. Android Studio → 우측 Gradle 탭
2. Tasks → android → signingReport 실행
3. 나오는 SHA-1 값을 Google Cloud Console에 등록

### google-services.json 파일이 필요할 때
1. console.cloud.google.com 접속
2. 프로젝트 → 사용자 인증 정보
3. **Android 클라이언트 ID** 새로 생성 (기존 웹 클라이언트 ID랑 다름)
4. 다운로드 → `android/app/` 폴더에 넣기

### 위젯 부분에서 Kotlin 코드가 나올 때
당황하지 말고 Claude Code가 안내하는 위치에 파일 배치

### Claude Code가 `mail.google.com/` 스코프를 쓰려 하면
반드시 `gmail.modify`로 바꾸라고 지시할 것

---

## 웹 버전 개발하면서 배운 것 (Flutter 앱에 반영 필요)

### 1. 이메일 본문 다크모드 문제
안드로이드 강제 다크모드가 WebView 안 이메일까지 어둡게 만듦.
HTML 래퍼에 반드시 `<meta name="color-scheme" content="only light">` 추가.
PROMPT.md의 이메일 렌더링 코드 참고.

### 2. 스팸 해제 기능
스팸함에서 메일 열면 "스팸" 버튼이 "스팸 해제"로 바뀌어야 함.
메시지의 labelIds에 'SPAM' 포함 여부로 판단.

### 3. 캘린더 필터
사용자마다 보고 싶은 캘린더가 다름 (공휴일 등 숨기고 싶어함).
SharedPreferences에 `{calendarId: false}` 형태로 저장하고
loadCalendar 시 필터 적용.

### 4. 삭제 동작 구분
- 일반 편지함 → 휴지통 이동
- 휴지통에서 → 영구 삭제 (gmail.modify로는 불가)
  → "30일 후 자동 삭제" 안내로 대체하거나
  → 이 기능만 별도 처리 고려

### 5. JS/코드 수정 시 주의
find/replace 사용 시 같은 문자열이 여러 곳에 있으면
의도치 않은 곳까지 바뀔 수 있음.
항상 수정 후 문법 검사 필수.
