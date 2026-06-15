import 'package:flutter/material.dart';

/// 일부 기기(Samsung One UI 등)에서 Flutter `ScaffoldMessenger` 의 SnackBar
/// 자동 닫힘 타이머(`Timer(snackBar.duration, …)`)가 발동하지 않아 스낵바가
/// 계속 떠 있는 현상이 있다. (logcat 으로 확인: accessibleNavigation=false,
/// 애니메이션 스케일 1.0 → 프레임워크 자동 닫힘 경로가 이 기기에서 성립 안 함.)
///
/// 이 확장은 스낵바를 띄운 뒤 표시 시간이 지나면 직접 제거해, 기기 환경과
/// 무관하게 항상 닫히도록 보장한다. `removeCurrentSnackBar` 는 애니메이션
/// 타이머에 의존하지 않고 컨트롤러 값을 직접 0으로 만들어 즉시 닫는다.
extension AutoDismissSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAutoDismissSnackBar(
    SnackBar snackBar,
  ) {
    final controller = showSnackBar(snackBar);
    bool closed = false;
    controller.closed.then((_) => closed = true);
    Future.delayed(snackBar.duration + const Duration(milliseconds: 300), () {
      if (!closed) {
        removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
      }
    });
    return controller;
  }
}
