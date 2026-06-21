import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

/// BuildContext 없이(알림, 백그라운드 폴러 등) 문자열을 얻기 위한 헬퍼.
/// 시스템 로캘을 기준으로 하되 지원하지 않는 언어는 영어로 폴백한다.
AppLocalizations appL10n() {
  final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return lookupAppLocalizations(Locale(code == 'ko' ? 'ko' : 'en'));
}

/// 시스템 로캘이 한국어가 아닌지 여부(지원하지 않는 언어는 영어로 취급).
bool isEnglishLocale() =>
    WidgetsBinding.instance.platformDispatcher.locale.languageCode != 'ko';
