import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @openButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openButton;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginError;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginButton;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your Google\nTasks and Calendar.'**
  String get loginDescription;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @taskItemDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" deleted'**
  String taskItemDeletedSnack(String title);

  /// No description provided for @taskCompletedSection.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String taskCompletedSection(int count);

  /// No description provided for @taskDueDate.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String taskDueDate(int month, int day);

  /// No description provided for @taskOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskOverdue;

  /// No description provided for @taskEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get taskEmptyTitle;

  /// No description provided for @taskEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a task'**
  String get taskEmptyHint;

  /// No description provided for @addTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get addTaskTitle;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title (required)'**
  String get titleHint;

  /// No description provided for @dueDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select due date (optional)'**
  String get dueDateHint;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}/{year}'**
  String dateFormat(int year, int month, int day);

  /// No description provided for @memoHint.
  ///
  /// In en, this message translates to:
  /// **'Memo (optional)'**
  String get memoHint;

  /// No description provided for @taskAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add task. Please try again.'**
  String get taskAddFailed;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarFilter.
  ///
  /// In en, this message translates to:
  /// **'Calendar Filter'**
  String get calendarFilter;

  /// No description provided for @calendarPrevYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get calendarPrevYear;

  /// No description provided for @calendarNextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get calendarNextYear;

  /// No description provided for @calendarYearPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Year'**
  String get calendarYearPickerTitle;

  /// No description provided for @calendarYearPickerApply.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get calendarYearPickerApply;

  /// No description provided for @calendarMonthFormat.
  ///
  /// In en, this message translates to:
  /// **'{year}/{month}'**
  String calendarMonthFormat(int year, int month);

  /// No description provided for @calendarMonthItemsHeader.
  ///
  /// In en, this message translates to:
  /// **'{year}/{month} events ({count})'**
  String calendarMonthItemsHeader(int year, int month, int count);

  /// No description provided for @calendarMonthRemainingHeader.
  ///
  /// In en, this message translates to:
  /// **'📅 Upcoming events ({count})'**
  String calendarMonthRemainingHeader(int count);

  /// No description provided for @calendarEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events this month'**
  String get calendarEmpty;

  /// No description provided for @calendarNoRemaining.
  ///
  /// In en, this message translates to:
  /// **'No remaining events this month'**
  String get calendarNoRemaining;

  /// No description provided for @tasksShowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Show completed tasks'**
  String get tasksShowCompleted;

  /// No description provided for @tasksHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed tasks'**
  String get tasksHideCompleted;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @taskDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get taskDue;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @showCalendars.
  ///
  /// In en, this message translates to:
  /// **'Show Calendars'**
  String get showCalendars;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to use this feature'**
  String get loginRequired;

  /// No description provided for @newEventTitle.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEventTitle;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventTitle;

  /// No description provided for @titleRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get titleRequiredError;

  /// No description provided for @endTimeError.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get endTimeError;

  /// No description provided for @eventStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get eventStart;

  /// No description provided for @eventEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get eventEnd;

  /// No description provided for @eventRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get eventRepeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays (Mon–Fri)'**
  String get repeatWeekdays;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventLocation;

  /// No description provided for @eventDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventDescription;

  /// No description provided for @eventGuestsHint.
  ///
  /// In en, this message translates to:
  /// **'Invite email (comma-separated)'**
  String get eventGuestsHint;

  /// No description provided for @eventNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get eventNotification;

  /// No description provided for @notifPopup.
  ///
  /// In en, this message translates to:
  /// **'Popup'**
  String get notifPopup;

  /// No description provided for @notifEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get notifEmail;

  /// No description provided for @minutesBefore.
  ///
  /// In en, this message translates to:
  /// **'min before'**
  String get minutesBefore;

  /// No description provided for @calendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarLabel;

  /// No description provided for @eventColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Color'**
  String get eventColorLabel;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @dateTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}/{year} {hour}:{minute}'**
  String dateTimeFormat(
    int year,
    int month,
    int day,
    String hour,
    String minute,
  );

  /// No description provided for @eventDateLabel.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month}/{day}'**
  String eventDateLabel(String weekday, int month, int day);

  /// No description provided for @noEventsForDay.
  ///
  /// In en, this message translates to:
  /// **'No events for this day'**
  String get noEventsForDay;

  /// No description provided for @eventDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get eventDeleteTitle;

  /// No description provided for @eventDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{summary}\"?'**
  String eventDeleteMessage(String summary);

  /// No description provided for @eventDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Event deleted'**
  String get eventDeletedSnack;

  /// No description provided for @taskCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskCardLabel;

  /// No description provided for @taskDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get taskDeleteTitle;

  /// No description provided for @taskDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String taskDeleteMessage(String title);

  /// No description provided for @taskDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeletedSnack;

  /// No description provided for @noSubject.
  ///
  /// In en, this message translates to:
  /// **'(No subject)'**
  String get noSubject;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Theme'**
  String get themeTitle;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @widgetScreenMode.
  ///
  /// In en, this message translates to:
  /// **'Home Widget Screen Mode'**
  String get widgetScreenMode;

  /// No description provided for @widgetScreenModeDesc.
  ///
  /// In en, this message translates to:
  /// **'You can manually set each widget to cover or home screen mode.\nAuto detection judges by widget size on foldable devices.'**
  String get widgetScreenModeDesc;

  /// No description provided for @noWidgets.
  ///
  /// In en, this message translates to:
  /// **'No widgets registered'**
  String get noWidgets;

  /// No description provided for @appInfoSection.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfoSection;

  /// No description provided for @openSourceLicense.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicense;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get logout;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Signing out will delete saved authentication data. Continue?'**
  String get logoutConfirmMessage;

  /// No description provided for @coverScreen.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get coverScreen;

  /// No description provided for @homeScreen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeScreen;

  /// No description provided for @tabletLabel.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get tabletLabel;

  /// No description provided for @coverButton.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get coverButton;

  /// No description provided for @homeButton.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeButton;

  /// No description provided for @autoButton.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoButton;

  /// No description provided for @widgetSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {width}dp × {height}dp'**
  String widgetSize(int width, int height);

  /// No description provided for @widgetThemeSetting.
  ///
  /// In en, this message translates to:
  /// **'Widget Theme'**
  String get widgetThemeSetting;

  /// No description provided for @widgetSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get widgetSystemTheme;

  /// No description provided for @widgetLightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get widgetLightTheme;

  /// No description provided for @widgetDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get widgetDarkTheme;

  /// No description provided for @widgetOpacitySetting.
  ///
  /// In en, this message translates to:
  /// **'Widget Background Opacity'**
  String get widgetOpacitySetting;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'MyBoard Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyLastModified.
  ///
  /// In en, this message translates to:
  /// **'Last Modified: June 12, 2026'**
  String get privacyPolicyLastModified;

  /// No description provided for @privacySection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get privacySection1Title;

  /// No description provided for @privacySection1Body.
  ///
  /// In en, this message translates to:
  /// **'This app accesses the following information through your Google account:\n• Google Tasks: View and manage to-do lists\n• Google Calendar: View and manage events\n\nThis information is processed only on your device and is not sent to external servers.'**
  String get privacySection1Body;

  /// No description provided for @privacySection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Data Storage'**
  String get privacySection2Title;

  /// No description provided for @privacySection2Body.
  ///
  /// In en, this message translates to:
  /// **'• Authentication tokens: Stored in the device\'s encrypted storage (EncryptedSharedPreferences)\n• Widget data: Cached in the device\'s SharedPreferences\n• All data is stored only on the device and is not transmitted externally.'**
  String get privacySection2Body;

  /// No description provided for @privacySection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Data Deletion'**
  String get privacySection3Title;

  /// No description provided for @privacySection3Body.
  ///
  /// In en, this message translates to:
  /// **'Stored authentication tokens are deleted upon sign out. Uninstalling the app completely removes all local data.'**
  String get privacySection3Body;

  /// No description provided for @privacySection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Third-Party Sharing'**
  String get privacySection4Title;

  /// No description provided for @privacySection4Body.
  ///
  /// In en, this message translates to:
  /// **'This app does not provide or sell user data to third parties. There is no data exchange with external servers other than communication through the Google API.'**
  String get privacySection4Body;

  /// No description provided for @privacySection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Google API Policy Compliance'**
  String get privacySection5Title;

  /// No description provided for @privacySection5Body.
  ///
  /// In en, this message translates to:
  /// **'The use and transfer of Google user data by this app complies with the Google API Services User Data Policy (including the Limited Use requirements).'**
  String get privacySection5Body;

  /// No description provided for @privacySection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Contact'**
  String get privacySection6Title;

  /// No description provided for @privacySection6Body.
  ///
  /// In en, this message translates to:
  /// **'Privacy inquiries: dhwjdghddd@gmail.com'**
  String get privacySection6Body;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to the network.'**
  String get errorNetwork;

  /// No description provided for @errorHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'An HTTP {status} error occurred.'**
  String errorHttpStatus(int status);

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
