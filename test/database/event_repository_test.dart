import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';

void main() {
  late DatabaseService db;
  late EventRepository repo;

  setUp(() async {
    db = await DatabaseService.memory();
    repo = EventRepository(db);
  });

  tearDown(() => db.close());

  EventCollection makeEvent({String title = 'Weekend MTB', int startAt = 0}) =>
      EventCollection()
        ..title = title
        ..description = 'desc'
        ..startAt = startAt == 0
            ? DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch
            : startAt
        ..activityTypeId = 'MTB'
        ..organizerId = 'user-1';

  test('create persists with UUID and timestamps', () async {
    final e = await repo.create(makeEvent());
    expect(UuidGenerator.isValid(e.id), isTrue);
    expect(e.createdAt, greaterThan(0));
    expect(e.version, 1);
    expect(e.status, EventStatus.preparation.name);
    expect(e.visibility, EventVisibility.private.name);
  });

  test('create rejects empty title', () async {
    expect(
      () => repo.create(makeEvent(title: '   ')),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('getById returns only non-deleted', () async {
    final e = await repo.create(makeEvent());
    expect((await repo.getById(e.id))?.id, e.id);
    await repo.softDelete(e);
    expect(await repo.getById(e.id), isNull);
  });

  test('all returns sorted by startAt, excluding deleted', () async {
    final far = await repo.create(makeEvent(
        title: 'Far',
        startAt: DateTime.now()
            .add(const Duration(days: 10))
            .millisecondsSinceEpoch));
    final near = await repo.create(makeEvent(
        title: 'Near',
        startAt: DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch));
    final all = await repo.all();
    expect(all.length, 2);
    expect(all.first.id, near.id);
    expect(all.last.id, far.id);
  });

  test('upcoming filters past events', () async {
    await repo.create(makeEvent(
        startAt: DateTime.now()
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch));
    final future = await repo.create(makeEvent(
        title: 'Future',
        startAt: DateTime.now()
            .add(const Duration(days: 2))
            .millisecondsSinceEpoch));
    final list = await repo.upcoming();
    expect(list.length, 1);
    expect(list.first.id, future.id);
  });
}
