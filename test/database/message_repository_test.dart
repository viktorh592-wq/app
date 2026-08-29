import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
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

  group('Sprint 3 — V2 Telegram-style chat', () {
    test('S3-T1: new message defaults to deliveryState=queued', () async {
      final m = await repo.sendText(
          eventId: eventId, authorId: 'u1', text: 'queued?');
      expect(m.deliveryState, DeliveryState.queued.name);
      expect(m.delivery, DeliveryState.queued);
    });

    test('S3-T10: setDeliveryState transitions queued→delivered→synced',
        () async {
      final m = await repo.sendText(
          eventId: eventId, authorId: 'u1', text: 'hi');
      await repo.setDeliveryState(m, DeliveryState.delivered);
      expect(m.deliveryState, DeliveryState.delivered.name);
      await repo.setDeliveryState(m, DeliveryState.synced);
      expect(m.deliveryState, DeliveryState.synced.name);
    });

    test('S3-T2: setReaction toggles a user reaction on/off', () async {
      final m = await repo.sendText(
          eventId: eventId, authorId: 'u2', text: 'react');
      await repo.setReaction(message: m, emoji: '👍', userId: 'u1');
      await repo.setReaction(message: m, emoji: '👍', userId: 'u2');
      var reloaded = (await repo.getById(m.id))!;
      expect(reloaded.reactions['👍'], unorderedEquals(['u1', 'u2']));
      // Toggle off the same user
      await repo.setReaction(message: reloaded, emoji: '👍', userId: 'u1');
      reloaded = (await repo.getById(m.id))!;
      expect(reloaded.reactions['👍'], ['u2']);
      // Removing the last reader clears the emoji key
      await repo.setReaction(message: reloaded, emoji: '👍', userId: 'u2');
      reloaded = (await repo.getById(m.id))!;
      expect(reloaded.reactions['👍'], isNull);
      expect(reloaded.reactionsJson, isNull);
    });

    test('S3-T5: pin / unpin set the flag and pinned() returns them',
        () async {
      final a = await repo.sendText(
          eventId: eventId, authorId: 'u1', text: 'a');
      // Sprint 5 — small delay guarantees b.createdAt > a.createdAt so the
      // secondary SortOrder('id', false) in MessageRepository.pinned is not
      // the deciding factor (UUID v7 random suffix is not insertion-ordered).
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final b = await repo.sendText(
          eventId: eventId, authorId: 'u1', text: 'b');
      await repo.pin(a);
      await repo.pin(b);
      final list = await repo.pinned(eventId);
      expect(list.length, 2);
      // Newest first (descending createdAt)
      expect(list.first.id, b.id);
      await repo.unpin(a);
      expect((await repo.pinned(eventId)).length, 1);
    });

    test('S3-T11: markRead by user appends to readBy and de-duplicates',
        () async {
      final m = await repo.sendText(
          eventId: eventId, authorId: 'u2', text: 'read');
      await repo.markRead(m, userId: 'u1');
      var reloaded = (await repo.getById(m.id))!;
      expect(reloaded.readBy, ['u1']);
      // Re-marking the same user does not duplicate
      await repo.markRead(reloaded, userId: 'u1');
      reloaded = (await repo.getById(m.id))!;
      expect(reloaded.readBy, ['u1']);
      await repo.markRead(reloaded, userId: 'u2');
      reloaded = (await repo.getById(m.id))!;
      expect(reloaded.readBy, unorderedEquals(['u1', 'u2']));
    });

    test('S3-T4: forward copies payload and sets forwardedFrom', () async {
      final original = await repo.sendText(
          eventId: eventId, authorId: 'u-origin', text: 'forward me');
      await repo.forward(
          source: original, toEventId: 'event-2', byUserId: 'u-me');
      final inSecond = await repo.byEvent('event-2');
      expect(inSecond.length, 1);
      expect(inSecond.first.text, 'forward me');
      expect(inSecond.first.forwardedFrom, 'u-origin');
      expect(inSecond.first.authorId, 'u-me');
      expect(inSecond.first.delivery, DeliveryState.queued);
    });

    test('S3-T7: sendAttachment(image) stores path + type + caption',
        () async {
      final m = await repo.sendAttachment(
        eventId: eventId,
        authorId: 'u1',
        type: AttachmentType.image,
        attachmentPath: '/tmp/pic.jpg',
        caption: 'nice ride',
        meta: {'width': 1280, 'height': 720},
      );
      expect(m.attachmentPath, '/tmp/pic.jpg');
      expect(m.attachmentType, AttachmentType.image.name);
      expect(m.attachment, AttachmentType.image);
      expect(m.text, 'nice ride');
      expect(m.attachmentMetaMap['width'], 1280);
    });

    test('S3-T13: search / media / files / routes / exportJson', () async {
      await repo.sendText(eventId: eventId, authorId: 'u1', text: 'hello');
      await repo.sendText(
          eventId: eventId, authorId: 'u1', text: 'world hello');
      await repo.sendAttachment(
        eventId: eventId,
        authorId: 'u1',
        type: AttachmentType.image,
        attachmentPath: '/p1.jpg',
      );
      await repo.sendAttachment(
        eventId: eventId,
        authorId: 'u1',
        type: AttachmentType.document,
        attachmentPath: '/p2.pdf',
      );
      await repo.sendAttachment(
        eventId: eventId,
        authorId: 'u1',
        type: AttachmentType.route,
        attachmentPath: '/r.gpx',
      );
      expect((await repo.search(eventId: eventId, query: 'hello')).length, 2);
      expect((await repo.media(eventId)).length, 1);
      expect((await repo.files(eventId)).length, 1);
      expect((await repo.routes(eventId)).length, 1);
      final exported = await repo.exportJson(eventId);
      expect(exported, contains('hello'));
      expect(exported, contains('eventId'));
    });
  });
}
