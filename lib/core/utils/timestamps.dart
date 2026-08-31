/// Timestamp policy — all timestamps stored as UTC milliseconds
/// (Timestamp_Policy.md). UI conversion happens only in the presentation layer.
import 'package:intl/intl.dart';

class Timestamps {
  Timestamps._();

  /// Current time in UTC milliseconds since epoch.
  static int nowUtc() => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Convert UTC milliseconds to a local [DateTime] for UI display.
  static DateTime toLocalDateTime(int utcMillis) =>
      DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true).toLocal();

  /// Format UTC millis to a readable local date string.
  static String formatLocalDate(int utcMillis, String locale) {
    final dt = toLocalDateTime(utcMillis);
    return DateFormat.yMd(locale).format(dt);
  }

  /// Format UTC millis to a readable local time string.
  static String formatLocalTime(int utcMillis, String locale) {
    final dt = toLocalDateTime(utcMillis);
    return DateFormat.Hm(locale).format(dt);
  }

  /// Format UTC millis to a readable local date + time string.
  static String formatLocalDateTime(int utcMillis, String locale) {
    final dt = toLocalDateTime(utcMillis);
    return DateFormat.yMd(locale).add_Hm().format(dt);
  }

  /// Relative "time ago" helper for chat / notifications.
  ///
  /// V3.0.2 — the short relative units ("now" / "5m" / "5h" / "5d") are now
  /// passed as localized strings by the call sites, so the chat / notifications
  /// UI matches the active locale. The default `now:` / `minutesLabel:` /
  /// `hoursLabel:` / `daysLabel:` keep the previous English behaviour so
  /// existing call sites that have not been migrated yet do not break.
  static String relativeFromNow(
    int utcMillis,
    String locale, {
    String? now,
    String Function(int)? minutesLabel,
    String Function(int)? hoursLabel,
    String Function(int)? daysLabel,
  }) {
    final dt = toLocalDateTime(utcMillis);
    final diff = DateTime.now().toLocal().difference(dt);
    if (diff.inMinutes < 1) return now ?? 'now';
    if (diff.inHours < 1) {
      return minutesLabel != null
          ? minutesLabel(diff.inMinutes)
          : '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return hoursLabel != null
          ? hoursLabel(diff.inHours)
          : '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return daysLabel != null
          ? daysLabel(diff.inDays)
          : '${diff.inDays}d';
    }
    return DateFormat.yMd(locale).format(dt);
  }
}
