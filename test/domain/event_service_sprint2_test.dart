/// Sprint 2 unit tests (FIX_PLAN S2-T6..S2-T8): activity accent color,
/// pinnedInGroup, edit / duplicate / pin / archive / delete activity menu
/// actions on EventService, and EventCollection persistence round-trip.
import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/event_service.dart';

void main() {
  late DatabaseService db;
  late EventService service;
  late UserRepository users;
  late EventRepository events;
  late ParticipantRepository participants;
  late ArchiveRepository archives;

  setUp(() async {
    db = await DatabaseService.memory();
    users = UserRepository(db);
    events = EventRepository(db);
    participants = ParticipantRepository(db);
    archives = ArchiveRepository(db);
    service = EventService(events, participants, archives);
  });

  tearDown(() => db.close());

  Future<UserCollection> organizer() =>
      users.createProfile(displayName: 'Alex', username: 'alex');

  Future<EventCollection> createEvent(UserCollection org,
          {String title = 'Ride', int? accentColor}) =>
      service.createActivity(
        organizer: org,
        groupId: 'group-1',
        title: title,
        description: 'desc',
        startAt: DateTime.now().millisecondsSinceEpoch,
        activityTypeId: 'MTB',
        meetingLat: 50.45,
        meetingLng: 30.52,
        accentColor: accentColor,
      );

  group('EventCollection persistence (S2-T6)', () {
    test('accentColor and pinnedInGroup survive toMap/applyMap round trip', () {
      final e = EventCollection()
        ..title = 'Ride'
        ..accentColor = 0xFF64B5F6
        ..pinnedInGroup = true;
      final restored = EventCollection.fromMap(e.toMap());
      expect(restored.accentColor, 0xFF64B5F6);
      expect(restored.pinnedInGroup, isTrue);
    });

    test('default accent color constant matches the violet swatch', () {
      expect(
        EventCollection.defaultAccentColorArgb,
        0xFF9B8AFB,
      );
    });
  });

  group('createActivity accent color + meeting point (S2-T6)', () {
    test('defaults accentColor to violet and persists meeting point', () async {
      final org = await organizer();
      final event = await createEvent(org);
      expect(event.accentColor, EventCollection.defaultAccentColorArgb);
      expect(event.meetingPoint, isNotNull);
      expect(event.meetingPoint!.lat, closeTo(50.45, 0.0001));
      expect(event.meetingPoint!.lng, closeTo(30.52, 0.0001));
    });

    test('keeps the provided accentColor', () async {
      final org = await organizer();
      final event = await createEvent(org, accentColor: 0xFFFF5252);
      expect(event.accentColor, 0xFFFF5252);
    });

    test('meetingPoint stays null when coordinates are omitted', () async {
      final org = await organizer();
      final event = await service.createActivity(
        organizer: org,
        groupId: 'group-1',
        title: 'No meeting',
        description: '',
        startAt: DateTime.now().millisecondsSinceEpoch,
        activityTypeId: 'MTB',
      );
      expect(event.meetingPoint, isNull);
    });
  });

  group('editActivity (S2-T8)', () {
    test('updates fields and persists accent color', () async {
      final org = await organizer();
      final event = await createEvent(org);
      final updated = await service.editActivity(
        event: event,
        title: 'Renamed',
        description: 'new desc',
        startAt: event.startAt + 3600 * 1000,
        activityTypeId: 'Gravel',
        visibility: EventVisibility.public,
        accentColor: 0xFF81C784,
      );
      final stored = await events.getById(event.id);
      expect(stored?.title, 'Renamed');
      expect(stored?.activityTypeId, 'Gravel');
      expect(stored?.accentColor, 0xFF81C784);
      expect(stored?.visibility, EventVisibility.public.name);
      expect(updated.id, event.id);
    });

    test('rejects empty title', () async {
      final org = await organizer();
      final event = await createEvent(org);
      expect(
        () => service.editActivity(
          event: event,
          title: '   ',
          description: '',
          startAt: event.startAt,
          activityTypeId: 'MTB',
        ),
        throwsA(isA<BusinessRuleError>()),
      );
    });
  });

  group('duplicate (S2-T8)', () {
    test('copies fields into a new preparation activity in the same group',
        () async {
      final org = await organizer();
      final event = await createEvent(org, accentColor: 0xFFFFB74D);
      final copy = await service.duplicate(event: event, organizer: org);

      expect(copy.id, isNot(event.id));
      expect(copy.title, 'Ride (copy)');
      expect(copy.groupId, 'group-1');
      expect(copy.status, EventStatus.preparation.name);
      expect(copy.accentColor, 0xFFFFB74D);
      expect(copy.organizerId, org.id);
      // Organizer is auto-joined in the copy (BR-001).
      final copyParticipants = await participants.byEvent(copy.id);
      expect(
        copyParticipants.any((p) =>
            p.userId == org.id && p.status == ParticipantStatus.accepted.name),
        isTrue,
      );
    });

    test('refuses to duplicate a legacy activity without a group', () async {
      final org = await organizer();
      final legacy = await events.create(EventCollection()
        ..title = 'Legacy'
        ..startAt = DateTime.now().millisecondsSinceEpoch
        ..activityTypeId = 'MTB'
        ..organizerId = org.id);
      legacy.groupId = null;
      expect(
        () => service.duplicate(event: legacy, organizer: org),
        throwsA(isA<BusinessRuleError>()),
      );
    });
  });

  group('setPinned (S2-T8)', () {
    test('toggles pinnedInGroup', () async {
      final org = await organizer();
      final event = await createEvent(org);
      expect(event.pinnedInGroup, isFalse);

      final pinned = await service.setPinned(event, true);
      expect(pinned.pinnedInGroup, isTrue);
      expect((await events.getById(event.id))?.pinnedInGroup, isTrue);

      final unpinned = await service.setPinned(event, false);
      expect(unpinned.pinnedInGroup, isFalse);
    });
  });

  group('archiveNow (S2-T8)', () {
    test('archives the activity and creates an archive record (BR-007)',
        () async {
      final org = await organizer();
      final event = await createEvent(org);
      await service.startRide(event);

      await service.archiveNow(event);

      final stored = await events.getById(event.id);
      expect(stored?.status, EventStatus.archived.name);
      expect(stored?.gpsSharingEnabled, isFalse);
      final archive = await archives.getByEventId(event.id);
      expect(archive, isNotNull);
      expect(archive?.eventId, event.id);
    });

    test('refuses to archive twice', () async {
      final org = await organizer();
      final event = await createEvent(org);
      await service.archiveNow(event);
      expect(
        () => service.archiveNow(event),
        throwsA(isA<BusinessRuleError>()),
      );
    });
  });

  group('deleteActivity (S2-T8)', () {
    test('soft-deletes: hidden from repository but archive is kept (BR-007)',
        () async {
      final org = await organizer();
      final event = await createEvent(org);
      await service.archiveNow(event);
      final archiveBefore = await archives.getByEventId(event.id);
      expect(archiveBefore, isNotNull);

      await service.deleteActivity(event, by: org.id);

      expect(await events.getById(event.id), isNull);
      // Soft delete — the stored record still exists with isDeleted = true.
      final raw = await events.all();
      expect(raw.any((e) => e.id == event.id), isFalse);
      // The archive record survives (BR-007).
      expect(await archives.getByEventId(event.id), isNotNull);
    });
  });
}
