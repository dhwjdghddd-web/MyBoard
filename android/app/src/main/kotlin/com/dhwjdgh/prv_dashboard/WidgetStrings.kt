package com.dhwjdgh.prv_dashboard

import java.util.Locale

/**
 * 네이티브(위젯/백그라운드 알림/빠른추가)에서 사용자에게 표시되는 문자열의 다국어 처리.
 * 위젯 데이터는 Flutter(WidgetService)와 네이티브(*SyncJobService) 양쪽에서 기록되므로
 * 종일/제목없음 같은 표시 문자열의 포맷을 양쪽이 동일하게 맞춘다.
 */
object WidgetStrings {
    private val isKorean: Boolean
        get() = Locale.getDefault().language == "ko"

    // ── 위젯 ──
    val allDay: String get() = if (isKorean) "종일" else "All day"
    val noSubject: String get() = if (isKorean) "(제목 없음)" else "(No subject)"
    val noSender: String get() = if (isKorean) "(이름 없음)" else "(No name)"

    // 시간 문자열이 "HH:mm" 형태가 아니면 종일로 간주 — 언어에 의존하지 않는 판별.
    private val timePattern = Regex("""\d{1,2}:\d{2}""")
    fun isAllDayTime(time: String): Boolean = !timePattern.matches(time)

    // ── 메일 알림 (백그라운드 워커) ──
    fun mailNotificationTitle(count: Int): String =
        if (isKorean) "새 메일 ${count}통" else "$count new emails"
    val mailNotificationDefaultSender: String get() = if (isKorean) "새 메일이 도착했습니다" else "New mail arrived"
    val mailChannelName: String get() = if (isKorean) "새 메일 알림" else "New mail"
    val mailChannelDesc: String get() = if (isKorean) "새 Gmail 메일 도착 시 알림" else "Notifies when new Gmail arrives"

    // ── 빠른 태스크 추가 ──
    val taskNameRequired: String get() = if (isKorean) "이름을 입력해주세요" else "Please enter a name"
    val taskAdding: String get() = if (isKorean) "추가 중…" else "Adding…"
    val taskAdded: String get() = if (isKorean) "태스크가 추가됐어요 ✓" else "Task added ✓"
    val taskAddedPending: String get() = if (isKorean) "태스크가 추가됐어요 (대기 중) ✓" else "Task added (pending) ✓"

    // ── 기타 ──
    val fileChooserTitle: String get() = if (isKorean) "파일 열기" else "Open file"
}
