/// User settings collection — covers general, map, notification, GPS and
/// privacy preferences (Database_Overview.md — Settings). Belongs to a User.
import 'package:pokatuha/database/base_entity.dart';

class SettingsCollection extends BaseEntity {
  String userId = '';

  // --- General ---
  // V3.0.2 — default locale is Russian (project's primary audience). The
  // user can still switch in Settings → Language. Stored as an ISO 639-1
  // code ('ru' / 'en').
  String locale = 'ru';

  /// AppThemeMode enum stored as string.
  String themeMode = 'dark';

  int accentColor = 0xFF3B82F6;

  /// Theme mode setter helper
  void setThemeMode(String value) => themeMode = value;

  // --- Maps (Maps rules) ---
  /// MapProvider enum stored as string.
  String mapProvider = 'openStreetMap';

  String? mapStyleId;

  // --- Notifications (Notifications.md — configurable per category) ---
  bool notifyEventInvitation = true;
  bool notifyEventUpdated = true;
  bool notifyEventCancelled = true;
  bool notifyEventStartsSoon = true;
  bool notifyNewMessage = true;
  bool notifyPinnedMessage = true;
  bool notifyMention = true;
  bool notifyParticipantApproaching = true;
  bool notifyParticipantArrived = true;
  bool notifyNewPoll = true;
  bool notifyPollClosed = true;
  bool notifyEnableGpsReminder = true;
  bool notifyWeatherChanged = true;
  bool silentMode = false;
  bool doNotDisturb = false;

  // --- GPS (FR-005, FR-006) ---
  double arrivalThresholdNear = 500.0;
  double arrivalThresholdClose = 200.0;
  double arrivalThresholdArrived = 50.0;

  // --- Privacy (Privacy rules — user control) ---
  bool shareGpsByDefault = false;
  bool sharePhotosByDefault = true;
  bool profileVisible = true;
  bool eventVisibleToPeers = true;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'userId': userId,
      'locale': locale,
      'themeMode': themeMode,
      'accentColor': accentColor,
      'mapProvider': mapProvider,
      'mapStyleId': mapStyleId,
      'notifyEventInvitation': notifyEventInvitation,
      'notifyEventUpdated': notifyEventUpdated,
      'notifyEventCancelled': notifyEventCancelled,
      'notifyEventStartsSoon': notifyEventStartsSoon,
      'notifyNewMessage': notifyNewMessage,
      'notifyPinnedMessage': notifyPinnedMessage,
      'notifyMention': notifyMention,
      'notifyParticipantApproaching': notifyParticipantApproaching,
      'notifyParticipantArrived': notifyParticipantArrived,
      'notifyNewPoll': notifyNewPoll,
      'notifyPollClosed': notifyPollClosed,
      'notifyEnableGpsReminder': notifyEnableGpsReminder,
      'notifyWeatherChanged': notifyWeatherChanged,
      'silentMode': silentMode,
      'doNotDisturb': doNotDisturb,
      'arrivalThresholdNear': arrivalThresholdNear,
      'arrivalThresholdClose': arrivalThresholdClose,
      'arrivalThresholdArrived': arrivalThresholdArrived,
      'shareGpsByDefault': shareGpsByDefault,
      'sharePhotosByDefault': sharePhotosByDefault,
      'profileVisible': profileVisible,
      'eventVisibleToPeers': eventVisibleToPeers,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    userId = m['userId'] as String? ?? '';
    locale = m['locale'] as String? ?? 'ru';
    themeMode = m['themeMode'] as String? ?? 'dark';
    accentColor = (m['accentColor'] as num?)?.toInt() ?? 0xFF3B82F6;
    mapProvider = m['mapProvider'] as String? ?? 'openStreetMap';
    mapStyleId = m['mapStyleId'] as String?;
    notifyEventInvitation = m['notifyEventInvitation'] as bool? ?? true;
    notifyEventUpdated = m['notifyEventUpdated'] as bool? ?? true;
    notifyEventCancelled = m['notifyEventCancelled'] as bool? ?? true;
    notifyEventStartsSoon = m['notifyEventStartsSoon'] as bool? ?? true;
    notifyNewMessage = m['notifyNewMessage'] as bool? ?? true;
    notifyPinnedMessage = m['notifyPinnedMessage'] as bool? ?? true;
    notifyMention = m['notifyMention'] as bool? ?? true;
    notifyParticipantApproaching =
        m['notifyParticipantApproaching'] as bool? ?? true;
    notifyParticipantArrived = m['notifyParticipantArrived'] as bool? ?? true;
    notifyNewPoll = m['notifyNewPoll'] as bool? ?? true;
    notifyPollClosed = m['notifyPollClosed'] as bool? ?? true;
    notifyEnableGpsReminder = m['notifyEnableGpsReminder'] as bool? ?? true;
    notifyWeatherChanged = m['notifyWeatherChanged'] as bool? ?? true;
    silentMode = m['silentMode'] as bool? ?? false;
    doNotDisturb = m['doNotDisturb'] as bool? ?? false;
    arrivalThresholdNear =
        (m['arrivalThresholdNear'] as num?)?.toDouble() ?? 500.0;
    arrivalThresholdClose =
        (m['arrivalThresholdClose'] as num?)?.toDouble() ?? 200.0;
    arrivalThresholdArrived =
        (m['arrivalThresholdArrived'] as num?)?.toDouble() ?? 50.0;
    shareGpsByDefault = m['shareGpsByDefault'] as bool? ?? false;
    sharePhotosByDefault = m['sharePhotosByDefault'] as bool? ?? true;
    profileVisible = m['profileVisible'] as bool? ?? true;
    eventVisibleToPeers = m['eventVisibleToPeers'] as bool? ?? true;
  }

  static SettingsCollection fromMap(Map<String, dynamic> m) =>
      SettingsCollection()..applyMap(m);

  /// Shallow copy used by the settings UI before persisting edits.
  SettingsCollection copy() => SettingsCollection()..applyMap(toMap());
}
