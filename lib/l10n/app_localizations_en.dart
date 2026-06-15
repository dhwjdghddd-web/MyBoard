// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get retryButton => 'Retry';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteButton => 'Delete';

  @override
  String get saveButton => 'Save';

  @override
  String get addButton => 'Add';

  @override
  String get closeButton => 'Close';

  @override
  String get openButton => 'Open';

  @override
  String get editButton => 'Edit';

  @override
  String get loginError => 'Login failed. Please try again.';

  @override
  String get loginButton => 'Sign in with Google';

  @override
  String get loginDescription =>
      'Sign in to access your Google\nTasks, Calendar, and Gmail.';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navCalendar => 'Calendar';

  @override
  String taskItemDeletedSnack(String title) {
    return '\"$title\" deleted';
  }

  @override
  String taskCompletedSection(int count) {
    return 'Completed ($count)';
  }

  @override
  String taskDueDate(int month, int day) {
    return '$month/$day';
  }

  @override
  String get taskOverdue => 'Overdue';

  @override
  String get taskEmptyTitle => 'No tasks';

  @override
  String get taskEmptyHint => 'Tap + to add a task';

  @override
  String get addTaskTitle => 'New Task';

  @override
  String get titleHint => 'Title (required)';

  @override
  String get dueDateHint => 'Select due date (optional)';

  @override
  String dateFormat(int year, int month, int day) {
    return '$month/$day/$year';
  }

  @override
  String get memoHint => 'Memo (optional)';

  @override
  String get taskAddFailed => 'Failed to add task. Please try again.';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarFilter => 'Calendar Filter';

  @override
  String calendarMonthFormat(int year, int month) {
    return '$year/$month';
  }

  @override
  String calendarMonthItemsHeader(int year, int month, int count) {
    return '$year/$month events ($count)';
  }

  @override
  String get calendarEmpty => 'No events this month';

  @override
  String get allDay => 'All day';

  @override
  String get taskDue => 'Due';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get showCalendars => 'Show Calendars';

  @override
  String get loginRequired => 'Please sign in to use this feature';

  @override
  String get newEventTitle => 'New Event';

  @override
  String get editEventTitle => 'Edit Event';

  @override
  String get titleRequiredError => 'Please enter a title';

  @override
  String get endTimeError => 'End time must be after start time';

  @override
  String get eventStart => 'Start';

  @override
  String get eventEnd => 'End';

  @override
  String get eventRepeat => 'Repeat';

  @override
  String get repeatNone => 'None';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekdays => 'Weekdays (Mon–Fri)';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventDescription => 'Description';

  @override
  String get eventGuestsHint => 'Invite email (comma-separated)';

  @override
  String get eventNotification => 'Notification';

  @override
  String get notifPopup => 'Popup';

  @override
  String get notifEmail => 'Email';

  @override
  String get minutesBefore => 'min before';

  @override
  String get calendarLabel => 'Calendar';

  @override
  String get eventColorLabel => 'Event Color';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String dateTimeFormat(
    int year,
    int month,
    int day,
    String hour,
    String minute,
  ) {
    return '$month/$day/$year $hour:$minute';
  }

  @override
  String eventDateLabel(String weekday, int month, int day) {
    return '$weekday, $month/$day';
  }

  @override
  String get noEventsForDay => 'No events for this day';

  @override
  String get eventDeleteTitle => 'Delete Event';

  @override
  String eventDeleteMessage(String summary) {
    return 'Delete \"$summary\"?';
  }

  @override
  String get eventDeletedSnack => 'Event deleted';

  @override
  String get taskCardLabel => 'Task';

  @override
  String get taskDeleteTitle => 'Delete Task';

  @override
  String taskDeleteMessage(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get taskDeletedSnack => 'Task deleted';

  @override
  String get gmailInbox => 'Inbox';

  @override
  String get gmailStarred => 'Starred';

  @override
  String get gmailSent => 'Sent';

  @override
  String get gmailSpam => 'Spam';

  @override
  String get gmailTrash => 'Trash';

  @override
  String get gmailSearchHint => 'Search mail…';

  @override
  String get composeButton => 'Compose';

  @override
  String get noSubject => '(No subject)';

  @override
  String get gmailEmpty => 'No mail';

  @override
  String get gmailLoadError => 'Could not load mail';

  @override
  String get emailTitle => 'Mail';

  @override
  String get emailFrom => 'From';

  @override
  String get emailTo => 'To';

  @override
  String get emailDateHeader => 'Date';

  @override
  String get emailLoadError => 'Could not load email';

  @override
  String get openInGmail => 'Open in Gmail';

  @override
  String fileOpenError(String error) {
    return 'Failed to open file: $error';
  }

  @override
  String get fileAlreadyDownloadedTitle => 'File Already Downloaded';

  @override
  String fileAlreadyDownloadedMessage(String filename) {
    return '\"$filename\" is already downloaded.\nDownload again?';
  }

  @override
  String get openFileButton => 'Open Now';

  @override
  String get redownloadButton => 'Re-download';

  @override
  String downloadCompleted(String filename) {
    return '\"$filename\" downloaded';
  }

  @override
  String downloadError(String error) {
    return 'Download failed: $error';
  }

  @override
  String attachmentCount(int count) {
    return '$count attachment(s)';
  }

  @override
  String get themeTitle => 'Display Theme';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get widgetScreenMode => 'Home Widget Screen Mode';

  @override
  String get widgetScreenModeDesc =>
      'You can manually set each widget to cover or home screen mode.\nAuto detection judges by widget size on foldable devices.';

  @override
  String get noWidgets => 'No widgets registered';

  @override
  String get appInfoSection => 'App Info';

  @override
  String get openSourceLicense => 'Open Source Licenses';

  @override
  String get logout => 'Sign Out';

  @override
  String get logoutConfirmMessage =>
      'Signing out will delete saved authentication data. Continue?';

  @override
  String get coverScreen => 'Cover';

  @override
  String get homeScreen => 'Home';

  @override
  String get tabletLabel => 'Tablet';

  @override
  String get coverButton => 'Cover';

  @override
  String get homeButton => 'Home';

  @override
  String get autoButton => 'Auto';

  @override
  String widgetSize(int width, int height) {
    return 'Size: ${width}dp × ${height}dp';
  }

  @override
  String get widgetThemeSetting => 'Widget Theme';

  @override
  String get widgetSystemTheme => 'System';

  @override
  String get widgetLightTheme => 'Light';

  @override
  String get widgetDarkTheme => 'Dark';

  @override
  String get widgetOpacitySetting => 'Widget Background Opacity';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyTitle => 'MyBoard Privacy Policy';

  @override
  String get privacyPolicyLastModified => 'Last Modified: June 12, 2026';

  @override
  String get privacySection1Title => '1. Information We Collect';

  @override
  String get privacySection1Body =>
      'This app accesses the following information through your Google account:\n• Google Tasks: View and manage to-do lists\n• Google Calendar: View and manage events\n• Gmail: View, send, and delete emails\n\nThis information is processed only on your device and is not sent to external servers.';

  @override
  String get privacySection2Title => '2. Data Storage';

  @override
  String get privacySection2Body =>
      '• Authentication tokens: Stored in the device\'s encrypted storage (EncryptedSharedPreferences)\n• Widget data: Cached in the device\'s SharedPreferences\n• All data is stored only on the device and is not transmitted externally.';

  @override
  String get privacySection3Title => '3. Data Deletion';

  @override
  String get privacySection3Body =>
      'Stored authentication tokens are deleted upon sign out. Uninstalling the app completely removes all local data.';

  @override
  String get privacySection4Title => '4. Third-Party Sharing';

  @override
  String get privacySection4Body =>
      'This app does not provide or sell user data to third parties. There is no data exchange with external servers other than communication through the Google API.';

  @override
  String get privacySection5Title => '5. Google API Policy Compliance';

  @override
  String get privacySection5Body =>
      'The use and transfer of Google user data by this app complies with the Google API Services User Data Policy (including the Limited Use requirements).';

  @override
  String get privacySection6Title => '6. Contact';

  @override
  String get privacySection6Body => 'Privacy inquiries: dhwjdghddd@gmail.com';

  @override
  String mailNotificationTitle(int count) {
    return '$count new emails';
  }

  @override
  String get mailNotificationDefaultSender => 'New mail arrived';

  @override
  String get mailChannelName => 'New mail';

  @override
  String get mailChannelDesc => 'Notifies when new Gmail arrives';

  @override
  String get errorTimeout => 'Connection timed out.';

  @override
  String get errorNetwork => 'Cannot connect to the network.';

  @override
  String errorHttpStatus(int status) {
    return 'An HTTP $status error occurred.';
  }

  @override
  String get errorUnknown => 'An unknown error occurred.';
}
