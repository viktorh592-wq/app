import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
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

  test('createActivity adds organizer as accepted participant (BR-001)',
      () async {
    final organizer =
        await users.createProfile(displayName: 'Alex', username: 'alex');
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = await service.createActivity(
      organizer: organizer,
      groupId: 'group-1',
      title: 'Night Ride',
      description: '',
      startAt: now,
      activityTypeId: 'MTB',
      meetingLat: 50.45,
      meetingLng: 30.52,
    );
    final list = await participants.byEvent(event.id);
    expect(list.length, 1);
    expect(list.first.userId, organizer.id);
    expect(list.first.role, ParticipantRole.organizer.name);
    expect(list.first.status, ParticipantStatus.accepted.name);
  });

  test('join then leave updates participant status (BR-009)', () async {
    final organizer =
        await users.createProfile(displayName: 'Alex', username: 'alex');
    final event = await service.createActivity(
      organizer: organizer,
      groupId: 'group-1',
      title: 'Ride',
      description: '',
      startAt: DateTime.now().millisecondsSinceEpoch,
      activityTypeId: 'MTB',
      meetingLat: 0,
      meetingLng: 0,
    );
    final synthetic = UserCollection()..id = 'guest-1';
    final joined = await service.join(event: event, user: synthetic);
    expect(joined.status, ParticipantStatus.accepted.name);
    final left = await service.leave(event: event, user: synthetic);
    expect(left.status, ParticipantStatus.left.name);
  });

  test('startRide then finishRide creates archive (UC-003, UC-004, BR-002)',
      () async {
    final organizer =
        await users.createProfile(displayName: 'Alex', username: 'alex');
    final event = await service.createActivity(
      organizer: organizer,
      groupId: 'group-1',
      title: 'Ride',
      description: '',
      startAt: DateTime.now().millisecondsSinceEpoch,
      activityTypeId: 'MTB',
      meetingLat: 0,
      meetingLng: 0,
    );
    await service.startRide(event);
    expect((await events.getById(event.id))?.status, EventStatus.ride.name);
    await service.finishRide(event);
    final finished = await events.getById(event.id);
    expect(finished?.status, EventStatus.archived.name);
    final archive = await archives.getByEventId(event.id);
    expect(archive, isNotNull);
    expect(archive?.eventId, event.id);
  });

  test('cannot join an archived activity (BR-002)', () async {
    final organizer =
        await users.createProfile(displayName: 'Alex', username: 'alex');
    final event = await service.createActivity(
      organizer: organizer,
      groupId: 'group-1',
      title: 'Ride',
      description: '',
      startAt: DateTime.now().millisecondsSinceEpoch,
      activityTypeId: 'MTB',
      meetingLat: 0,
      meetingLng: 0,
    );
    await service.startRide(event);
    await service.finishRide(event);
    expect(
      () => service.join(event: event, user: organizer..id = 'late'),
      throwsA(isA<BusinessRuleError>()),
    );
  });
}
