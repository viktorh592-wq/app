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

  // V2 POLLS.md §3 — visibility (FIX_PLAN S5-T2).
  test('create poll persists the visibility field', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Anonymous?',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
      visibility: PollVisibility.anonymous,
    );
    expect(poll.visibility, PollVisibility.anonymous.name);

    final fetched = await polls.getById(poll.id);
    expect(fetched!.visibility, PollVisibility.anonymous.name);
  });

  test('create poll defaults visibility to public', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Default?',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
    );
    expect(poll.visibility, PollVisibility.public.name);
  });

  // V2 POLLS.md §4 — auto-close on read when deadline passed (FIX_PLAN S5-T2).
  test('byEvent auto-closes a poll whose deadline has passed', () async {
    final pastDeadline = DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toUtc()
        .millisecondsSinceEpoch;
    final poll = await polls.create(
      eventId: eventId,
      question: 'Auto-close?',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
      deadlineAt: pastDeadline,
    );
    expect(poll.status, PollStatus.open.name);

    final list = await polls.byEvent(eventId);
    final fetched = list.firstWhere((p) => p.id == poll.id);
    expect(fetched.status, PollStatus.closed.name);

    final byId = await polls.getById(poll.id);
    expect(byId!.status, PollStatus.closed.name);
  });

  test('byEvent leaves an open poll with no deadline untouched', () async {
    final poll = await polls.create(
      eventId: eventId,
      question: 'Open?',
      optionTexts: ['A', 'B'],
      type: PollType.singleChoice,
    );
    final list = await polls.byEvent(eventId);
    final fetched = list.firstWhere((p) => p.id == poll.id);
    expect(fetched.status, PollStatus.open.name);
  });
}
