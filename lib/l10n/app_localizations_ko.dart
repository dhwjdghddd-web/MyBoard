// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get settingsTitle => '설정';

  @override
  String get retryButton => '다시 시도';

  @override
  String get refreshTooltip => '새로고침';

  @override
  String get taskListLabel => '목록';

  @override
  String get cancelButton => '취소';

  @override
  String get deleteButton => '삭제';

  @override
  String get saveButton => '저장';

  @override
  String get addButton => '추가';

  @override
  String get closeButton => '닫기';

  @override
  String get openButton => '열기';

  @override
  String get editButton => '수정';

  @override
  String get loginError => '로그인 실패. 다시 시도해주세요.';

  @override
  String get loginButton => 'Google로 로그인';

  @override
  String get loginDescription => '로그인하면 Google 계정의 Tasks,\nCalendar에 접근합니다.';

  @override
  String get navTasks => '태스크';

  @override
  String get navCalendar => '캘린더';

  @override
  String taskItemDeletedSnack(String title) {
    return '\"$title\" 삭제됨';
  }

  @override
  String taskCompletedSection(int count) {
    return '완료 ($count)';
  }

  @override
  String taskDueDate(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String get taskOverdue => '기한 초과';

  @override
  String get taskEmptyTitle => '태스크가 없어요';

  @override
  String get taskEmptyHint => '+ 버튼으로 추가해보세요';

  @override
  String get addTaskTitle => '새 태스크';

  @override
  String get titleHint => '제목 (필수)';

  @override
  String get dueDateHint => '마감일 선택 (선택사항)';

  @override
  String dateFormat(int year, int month, int day) {
    return '$year년 $month월 $day일';
  }

  @override
  String get memoHint => '메모 (선택사항)';

  @override
  String get taskAddFailed => '태스크 추가에 실패했습니다. 다시 시도해주세요.';

  @override
  String get calendarToday => '오늘';

  @override
  String get calendarFilter => '캘린더 필터';

  @override
  String get calendarPrevYear => '이전 해';

  @override
  String get calendarNextYear => '다음 해';

  @override
  String get calendarYearPickerTitle => '연도 이동';

  @override
  String get calendarYearPickerApply => '이동';

  @override
  String calendarMonthFormat(int year, int month) {
    return '$year년 $month월';
  }

  @override
  String calendarMonthItemsHeader(int year, int month, int count) {
    return '$year년 $month월 일정 ($count)';
  }

  @override
  String calendarMonthRemainingHeader(int count) {
    return '📅 다가오는 일정 목록 ($count)';
  }

  @override
  String get calendarEmpty => '이번 달 일정이 없어요';

  @override
  String get calendarNoRemaining => '이번 달 남은 일정이 없어요';

  @override
  String get tasksShowCompleted => '완료된 할 일 표시';

  @override
  String get tasksHideCompleted => '완료된 할 일 숨기기';

  @override
  String get allDay => '종일';

  @override
  String get taskDue => '마감';

  @override
  String get weekdaySun => '일';

  @override
  String get weekdayMon => '월';

  @override
  String get weekdayTue => '화';

  @override
  String get weekdayWed => '수';

  @override
  String get weekdayThu => '목';

  @override
  String get weekdayFri => '금';

  @override
  String get weekdaySat => '토';

  @override
  String get showCalendars => '캘린더 표시';

  @override
  String get loginRequired => '로그인 후 이용 가능해요';

  @override
  String get newEventTitle => '새 일정';

  @override
  String get editEventTitle => '일정 수정';

  @override
  String get titleRequiredError => '제목을 입력해주세요';

  @override
  String get endTimeError => '종료 시간이 시작 시간보다 늦어야 해요';

  @override
  String get eventStart => '시작';

  @override
  String get eventEnd => '종료';

  @override
  String get allDayStart => '시작일';

  @override
  String get allDayEnd => '종료일';

  @override
  String get recurringDeleteTitle => '반복 일정 삭제';

  @override
  String get recurringEditTitle => '반복 일정 수정';

  @override
  String get recurringScopeThis => '이 일정만';

  @override
  String get recurringScopeAll => '모든 일정';

  @override
  String get recurringEditAllNote =>
      '‘모든 일정’ 수정은 제목·장소·설명·색상·알림에만 적용돼요(날짜·시간 제외).';

  @override
  String get eventRepeat => '반복';

  @override
  String get repeatNone => '없음';

  @override
  String get repeatDaily => '매일';

  @override
  String get repeatWeekdays => '주중(월~금)';

  @override
  String get repeatWeekly => '매주';

  @override
  String get repeatMonthly => '매월';

  @override
  String get repeatYearly => '매년';

  @override
  String get eventLocation => '장소';

  @override
  String get eventDescription => '설명';

  @override
  String get eventGuestsHint => '초대 이메일 (쉼표로 구분)';

  @override
  String get eventNotification => '알림';

  @override
  String get notifPopup => '팝업';

  @override
  String get notifEmail => '메일';

  @override
  String get minutesBefore => '분 전';

  @override
  String get calendarLabel => '캘린더';

  @override
  String get eventColorLabel => '이벤트 색상';

  @override
  String saveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String dateTimeFormat(
    int year,
    int month,
    int day,
    String hour,
    String minute,
  ) {
    return '$year년 $month월 $day일 $hour:$minute';
  }

  @override
  String eventDateLabel(String weekday, int month, int day) {
    return '$month월 $day일 ($weekday)';
  }

  @override
  String get noEventsForDay => '이 날은 일정이 없어요';

  @override
  String get eventDeleteTitle => '일정 삭제';

  @override
  String eventDeleteMessage(String summary) {
    return '\"$summary\"을 삭제할까요?';
  }

  @override
  String get eventDeletedSnack => '일정이 삭제되었습니다';

  @override
  String get taskCardLabel => '할 일';

  @override
  String get taskDeleteTitle => '할 일 삭제';

  @override
  String taskDeleteMessage(String title) {
    return '\"$title\"을 삭제할까요?';
  }

  @override
  String get taskDeletedSnack => '할 일이 삭제되었습니다';

  @override
  String get noSubject => '(제목 없음)';

  @override
  String get themeTitle => '화면 테마';

  @override
  String get darkMode => '다크 모드';

  @override
  String get lightMode => '라이트 모드';

  @override
  String get widgetScreenMode => '홈 위젯 화면 모드';

  @override
  String get widgetScreenModeDesc =>
      '위젯마다 커버화면/홈화면 여부를 수동으로 지정할 수 있어요.\n자동 감지는 폴더블 기기에서 위젯 크기로 판단해요.';

  @override
  String get noWidgets => '등록된 위젯이 없습니다';

  @override
  String get appInfoSection => '앱 정보';

  @override
  String get openSourceLicense => '오픈소스 라이선스';

  @override
  String get logout => '로그아웃';

  @override
  String get logoutConfirmMessage => '로그아웃하면 저장된 인증 정보가 삭제됩니다. 계속할까요?';

  @override
  String get coverScreen => '커버화면';

  @override
  String get homeScreen => '홈화면';

  @override
  String get tabletLabel => '태블릿';

  @override
  String get coverButton => '커버';

  @override
  String get homeButton => '홈';

  @override
  String get autoButton => '자동';

  @override
  String widgetSize(int width, int height) {
    return '크기: ${width}dp × ${height}dp';
  }

  @override
  String get widgetThemeSetting => '위젯 테마 설정';

  @override
  String get widgetSystemTheme => '시스템';

  @override
  String get widgetLightTheme => '라이트';

  @override
  String get widgetDarkTheme => '다크';

  @override
  String get widgetOpacitySetting => '위젯 배경 투명도 설정';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get privacyPolicyTitle => '마이보드 개인정보 처리방침';

  @override
  String get privacyPolicyLastModified => '최종 수정일: 2026년 6월 12일';

  @override
  String get privacySection1Title => '1. 수집하는 정보';

  @override
  String get privacySection1Body =>
      '본 앱은 Google 계정을 통해 다음 정보에 접근합니다:\n• Google Tasks: 할 일 목록 조회 및 관리\n• Google Calendar: 일정 조회 및 관리\n\n이 정보는 기기에서만 처리되며, 외부 서버로 전송되지 않습니다.';

  @override
  String get privacySection2Title => '2. 데이터 저장';

  @override
  String get privacySection2Body =>
      '• 인증 토큰: 기기의 암호화된 저장소(EncryptedSharedPreferences)에 저장\n• 위젯 데이터: 기기의 SharedPreferences에 캐시\n• 모든 데이터는 기기에만 저장되며 외부로 전송되지 않습니다.';

  @override
  String get privacySection3Title => '3. 데이터 삭제';

  @override
  String get privacySection3Body =>
      '로그아웃 시 저장된 인증 토큰이 삭제됩니다. 앱을 삭제하면 모든 로컬 데이터가 완전히 제거됩니다.';

  @override
  String get privacySection4Title => '4. 제3자 제공';

  @override
  String get privacySection4Body =>
      '본 앱은 사용자 데이터를 제3자에게 제공하거나 판매하지 않습니다. Google API를 통한 통신 외에 외부 서버와의 데이터 교환은 없습니다.';

  @override
  String get privacySection5Title => '5. Google API 정책 준수';

  @override
  String get privacySection5Body =>
      '본 앱의 Google 사용자 데이터 사용 및 전송은 Google API Services User Data Policy(제한적 사용 요건 포함)를 준수합니다.';

  @override
  String get privacySection6Title => '6. 문의';

  @override
  String get privacySection6Body => '개인정보 관련 문의: dhwjdghddd@gmail.com';

  @override
  String get errorTimeout => '연결 시간이 초과되었습니다.';

  @override
  String get errorNetwork => '네트워크에 연결할 수 없습니다.';

  @override
  String errorHttpStatus(int status) {
    return 'HTTP $status 오류가 발생했습니다.';
  }

  @override
  String get errorUnknown => '알 수 없는 오류가 발생했습니다.';
}
