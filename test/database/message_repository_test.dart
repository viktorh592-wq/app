import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';

void main() {
  late DatabaseService db;
  late MessageRepository repo;
  const eventId = 'event-1';

  setUp(() async {
    db = await DatabaseService.memory();
    repo = MessageRepository(db);
  });

  tearDown(() => db.close());

  test('sendText persists and orders by createdAt', () async {
    final a = await repo.sendText(
        eventId: eventId, authorId: 'u1', text: 'Hello');
    final b = await repo.sendText(
        eventId: eventId, authorId: 'u1', text: 'World');
    final list = await repo.byEvent(eventId);
    expect(list.length, 2);
    expect(list.first.id, a.id);
    expect(list.last.id, b.id);
  });

  test('empty message is rejected', () async {
    expect(
      () => repo.sendText(eventId: eventId, authorId: 'u1', text: '   '),
      throwsA(isA<ValidationError>()),
    );
  });

  test('unreadCount tracks unread messages', () async {
    await repo.sendText(eventId: eventId, authorId: 'u2', text: 'a');
    await repo.sendText(eventId: eventId, authorId: 'u2', text: 'b');
    expect(await repo.unreadCount(eventId), 2);
    final list = await repo.byEvent(eventId);
    await repo.markRead(list.first);
    expect(await repo.unreadCount(eventId), 1);
  });

  test('togglePin flips the pinned flag', () async {
    final m = await repo.sendText(
        eventId: eventId, authorId: 'u1', text: 'pin me');
    expect(m.pinned, isFalse);
    await repo.togglePin(m);
    expect(m.pinned, isTrue);
  });
}
