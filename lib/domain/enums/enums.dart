/// Activity / ride lifecycle stages (Glossary.md — Stage).
enum EventStatus {
  preparation,
  meeting,
  ride,
  pause,
  finished,
  archived,
  cancelled;

  bool get isArchived => this == EventStatus.archived;
  bool get isActive => this == EventStatus.ride || this == EventStatus.meeting;
}

/// How an activity is discovered (Privacy rules — user controls visibility).
enum EventVisibility { private, linkOnly, public }

/// Participant lifecycle (FR-003).
enum ParticipantStatus { invited, accepted, declined, left, removed }

/// Participant roles (BR-004).
enum ParticipantRole { organizer, moderator, member }

/// Group types (V2 GROUPS_AND_ACTIVITIES.md §2).
/// public — discoverable, join without approval (optional);
/// private — not discoverable, join by invitation only;
/// inviteOnly — optionally discoverable, requires admin approval.
enum GroupType { public, private, inviteOnly }

/// Group member roles (V2 GROUPS_AND_ACTIVITIES.md §4).
enum GroupRole { owner, admin, member }

/// Realtime communication mode (Communication.md).
enum CommunicationMode { live, sleep, offline }

/// Poll variants (FR-007).
enum PollType { singleChoice, multipleChoice }

/// Poll lifecycle.
enum PollStatus { open, closed }

/// Message kinds (FR-004).
enum MessageKind { text, image, reply, system, pinned }

/// Map providers (Maps rules — replaceable, no vendor lock-in).
enum MapProvider {
  openStreetMap,
  mapLibre,
  googleMaps,
  here,
  twoGis,
  yandexMaps,
}

/// Application appearance (Design_Language.md).
enum AppThemeMode { light, dark, amoled }

/// Notification categories (Notifications.md).
enum NotificationCategory {
  eventInvitation,
  eventUpdated,
  eventCancelled,
  eventStartsSoon,
  eventPostponed,
  eventArchived,
  newMessage,
  pinnedMessage,
  mention,
  reply,
  participantApproaching,
  participantArrived,
  organizerArrived,
  rideStarted,
  rideFinished,
  newPoll,
  pollUpdated,
  pollEndingSoon,
  pollClosed,
  pollResultsPublished,
  enableGpsReminder,
  leaveForMeetingReminder,
  weatherChanged,
}
