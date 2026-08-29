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

/// Poll visibility (V2 POLLS.md §3 — anonymous vs public).
///   • anonymous — votes hidden, only tallies shown
///   • public    — shows who voted for what
enum PollVisibility { anonymous, public }

/// Message kinds (FR-004).
enum MessageKind { text, image, reply, system, pinned }

/// Map providers (V2 MAPS_AND_GPS_FIX.md §1).
///
/// V2 providers (rendered natively via flutter_map):
///   • openStreetMap  — base / fallback
///   • cyclOSM        — cycling default
///   • openTopoMap    — relief / heights
///   • esriSatellite  — satellite
///   • cartoVoyager   — clean navigation
///
/// V1 default-style provider:
///   • mapLibre — renders the maplibre demotiles URL (kept selectable for
///     back-compat with persisted settings; not part of the V2 spec).
///
/// Deprecated (V2 forbids these — they fall back to OSM tiles, see
/// MapService._urlTemplate):
///   • googleMaps, here, twoGis, yandexMaps
enum MapProvider {
  openStreetMap,
  cyclOSM,
  openTopoMap,
  esriSatellite,
  cartoVoyager,

  // V1 default-style — not deprecated, just not part of V2 spec.
  mapLibre,

  // Deprecated — V2 forbids Google Maps (API key + ToS violation); others
  // remain selectable so old user settings don't break.
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
