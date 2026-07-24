/// Notification service — local foreground notifications + background FCM
/// wake-up (ADR-003). Notifications are grouped by activity (Notifications.md)
/// and respect per-category settings + silent / DND modes.
import 'package:pokatuha/core/utils/geo_utils.dart';
import 'package:pokatuha/database/collections/notification_collection.dart';
import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/notification_repository.dart';

class NotificationService {
  NotificationService(this._repository);

  final NotificationRepository _repository;

  /// Whether a category is enabled given the user's settings (Notifications.md).
  bool isEnabled(SettingsCollection settings, NotificationCategory category) {
    if (settings.silentMode || settings.doNotDisturb) return false;
    return switch (category) {
      NotificationCategory.eventInvitation => settings.notifyEventInvitation,
      NotificationCategory.eventUpdated => settings.notifyEventUpdated,
      NotificationCategory.eventCancelled => settings.notifyEventCancelled,
      NotificationCategory.eventStartsSoon => settings.notifyEventStartsSoon,
      NotificationCategory.eventPostponed => settings.notifyEventUpdated,
      NotificationCategory.eventArchived => settings.notifyEventUpdated,
      NotificationCategory.newMessage => settings.notifyNewMessage,
      NotificationCategory.pinnedMessage => settings.notifyPinnedMessage,
      NotificationCategory.mention => settings.notifyMention,
      NotificationCategory.reply => settings.notifyNewMessage,
      NotificationCategory.participantApproaching =>
        settings.notifyParticipantApproaching,
      NotificationCategory.participantArrived =>
        settings.notifyParticipantArrived,
      NotificationCategory.organizerArrived =>
        settings.notifyParticipantArrived,
      NotificationCategory.rideStarted => settings.notifyEventStartsSoon,
      NotificationCategory.rideFinished => settings.notifyEventUpdated,
      NotificationCategory.newPoll => settings.notifyNewPoll,
      NotificationCategory.pollUpdated => settings.notifyNewPoll,
      NotificationCategory.pollEndingSoon => settings.notifyNewPoll,
      NotificationCategory.pollClosed => settings.notifyPollClosed,
      NotificationCategory.pollResultsPublished => settings.notifyPollClosed,
      NotificationCategory.enableGpsReminder =>
        settings.notifyEnableGpsReminder,
      NotificationCategory.leaveForMeetingReminder =>
        settings.notifyEnableGpsReminder,
      NotificationCategory.weatherChanged => settings.notifyWeatherChanged,
    };
  }

  /// Persist + (in a full deployment) surface a notification. Returns null
  /// when the category is disabled by the user.
  Future<NotificationCollection?> notify({
    required String userId,
    required SettingsCollection settings,
    required NotificationCategory category,
    required String title,
    required String body,
    String? eventId,
    bool viaFcm = false,
  }) async {
    if (!isEnabled(settings, category)) return null;
    return _repository.create(
      userId: userId,
      category: category,
      title: title,
      body: body,
      eventId: eventId,
      viaFcm: viaFcm,
    );
  }

  /// Build an arrival message (FR-006 / US-007).
  ({NotificationCategory category, String body}) arrivalMessage({
    required String name,
    required ArrivalStage stage,
  }) {
    return switch (stage) {
      ArrivalStage.near => (
          category: NotificationCategory.participantApproaching,
          body: '$name is 500 m away',
        ),
      ArrivalStage.close => (
          category: NotificationCategory.participantApproaching,
          body: '$name is arriving',
        ),
      ArrivalStage.arrived => (
          category: NotificationCategory.participantArrived,
          body: '$name has arrived',
        ),
    };
  }
}
