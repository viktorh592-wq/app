import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/poll_repository.dart';

void main() {
  late DatabaseService db;
  late PollRepository polls;
  late ParticipantRepository participants;
  const eventId = 'event-1';

  setUp(() async {
    db = await DatabaseService.memory();
    polls = PollRepository(db);
    participants = ParticipantRepository(db);
  });

  tearDown(() => db.close());

  test('create poll requires at least two options', () async {
    expect(
      () => polls.create(
        eventId: eventId,
        question: 'When?',
        optionTexts: ['Only one'],
        type: PollType.singleChoice,
      ),
      throwsA(isA<ValidationError>()),
    );
  });

  test('single-choice vote records and counts', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Meet at 9 or 10?',
      optionTexts: ['9:00', '10:00'],
      type: PollType.singleChoice,
    );
    final p = await participants.invite(eventId: eventId, userId: 'u1');
    await polls.vote(
      poll: poll,
      participantId: p.id,
      userId: 'u1',
      optionIds: [poll.options.first.id],
    );
    final votes = await polls.votesByPoll(poll.id);
    expect(votes.length, 1);
    expect(poll.options.first.voteCount, 1);
    expect(poll.options.last.voteCount, 0);
  });

  test('single-choice poll rejects multiple options', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Pick one',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
    );
    final p = await participants.invite(eventId: eventId, userId: 'u2');
    expect(
      () => polls.vote(
        poll: poll,
        participantId: p.id,
        userId: 'u2',
        optionIds: [poll.options.first.id, poll.options.last.id],
      ),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('editable poll replaces previous vote', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Pick one',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
    );
    final p = await participants.invite(eventId: eventId, userId: 'u3');
    await polls.vote(
      poll: poll,
      participantId: p.id,
      userId: 'u3',
      optionIds: [poll.options.first.id],
    );
    await polls.vote(
      poll: poll,
      participantId: p.id,
      userId: 'u3',
      optionIds: [poll.options.last.id],
    );
    expect(poll.options.first.voteCount, 0);
    expect(poll.options.last.voteCount, 1);
  });

  test('cannot vote on a closed poll', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Pick one',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
    );
    await polls.close(poll);
    final p = await participants.invite(eventId: eventId, userId: 'u4');
    expect(
      () => polls.vote(
        poll: poll,
        participantId: p.id,
        userId: 'u4',
        optionIds: [poll.options.first.id],
      ),
      throwsA(isA<BusinessRuleError>()),
    );
  });
}
