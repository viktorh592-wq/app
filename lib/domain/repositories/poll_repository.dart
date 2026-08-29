/// Poll repository (FR-007). A poll must contain at least two options
/// (Data_Validation.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/core/utils/validators.dart';
import 'package:pokatuha/database/collections/embedded/poll_option.dart';
import 'package:pokatuha/database/collections/poll_collection.dart';
import 'package:pokatuha/database/collections/vote_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class PollRepository {
  PollRepository(this._db);
  final DatabaseService _db;

  TypedStore<PollCollection> get _store => _db.pollsStore;
  TypedStore<VoteCollection> get _votes => _db.votesStore;

  Future<List<PollCollection>> byEvent(String eventId) async {
    final polls = await _store.find(
      filter: Filter.equals('eventId', eventId) &
          Filter.equals('isDeleted', false),
      sortOrders: [SortOrder('createdAt')],
    );
    // V2 POLLS.md §4 — auto-close when deadlineAt passed (FIX_PLAN S5-T2).
    final now = Timestamps.nowUtc();
    for (final p in polls) {
      if (p.status == PollStatus.open.name &&
          p.deadlineAt != null &&
          p.deadlineAt! <= now) {
        p
          ..status = PollStatus.closed.name
          ..touch(now);
        await _store.put(p);
      }
    }
    return polls;
  }

  Future<PollCollection?> getById(String id) async {
    final p = await _store.getById(id);
    if (p == null || p.isDeleted) return null;
    // V2 POLLS.md §4 — auto-close when deadlineAt passed (FIX_PLAN S5-T2).
    if (p.status == PollStatus.open.name &&
        p.deadlineAt != null &&
        p.deadlineAt! <= Timestamps.nowUtc()) {
      p
        ..status = PollStatus.closed.name
        ..touch(Timestamps.nowUtc());
      return _store.put(p);
    }
    return p;
  }

  Future<PollCollection> create({
    required String eventId,
    required String question,
    required List<String> optionTexts,
    required PollType type,
    PollVisibility visibility = PollVisibility.public,
    int? deadlineAt,
    bool allowCustomOptions = false,
    bool editable = true,
    String? createdByParticipantId,
  }) async {
    if (!Validators.isNonEmptyTrimmed(question)) {
      throw const ValidationError('Poll question is required');
    }
    if (!Validators.isValidPollOptions(optionTexts)) {
      throw const ValidationError('Poll must contain at least two options');
    }
    // V2 §4 — past deadlines are allowed; byEvent / getById auto-close the
    // poll on first read so the UI can present a sensible "Closed" state.
    final now = Timestamps.nowUtc();
    final options = optionTexts
        .where((t) => t.trim().isNotEmpty)
        .map((t) => PollOption(id: UuidGenerator.generate(), text: t.trim()))
        .toList();
    final poll = PollCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..question = question.trim()
      ..type = type.name
      ..status = PollStatus.open.name
      ..visibility = visibility.name
      ..options = options
      ..deadlineAt = deadlineAt
      ..allowCustomOptions = allowCustomOptions
      ..editable = editable
      ..createdByParticipantId = createdByParticipantId;
    return _store.put(poll);
  }

  Future<PollCollection> close(PollCollection poll) async {
    poll
      ..status = PollStatus.closed.name
      ..touch(Timestamps.nowUtc());
    return _store.put(poll);
  }

  /// Cast a vote. Recalculates per-option counts (FR-007 — editable poll).
  Future<void> vote({
    required PollCollection poll,
    required String participantId,
    required String userId,
    required List<String> optionIds,
    String? customOption,
  }) async {
    if (poll.status == PollStatus.closed.name) {
      throw const BusinessRuleError('Poll is closed');
    }
    if (typeFromString(poll.type) == PollType.singleChoice &&
        optionIds.length > 1) {
      throw const BusinessRuleError('Single-choice poll allows one option');
    }
    final now = Timestamps.nowUtc();

    await _db.raw.transaction((txn) async {
      // Remove previous votes by this participant for an editable poll.
      if (poll.editable) {
        final previous = await _votes.findInTxn(
          txn,
          filter: Filter.equals('pollId', poll.id) &
              Filter.equals('participantId', participantId),
        );
        for (final v in previous) {
          v.softDelete(now);
          await _votes.putInTxn(txn, v);
        }
      }

      final vote = VoteCollection()
        ..id = UuidGenerator.generate()
        ..createdAt = now
        ..updatedAt = now
        ..version = 1
        ..isDeleted = false
        ..pollId = poll.id
        ..participantId = participantId
        ..userId = userId
        ..optionIds = optionIds
        ..customOption = customOption?.trim();
      await _votes.putInTxn(txn, vote);

      // Recompute option counts from non-deleted votes.
      final allVotes = await _votes.findInTxn(
        txn,
        filter: Filter.equals('pollId', poll.id) &
            Filter.equals('isDeleted', false),
      );
      final counts = <String, int>{};
      for (final v in allVotes) {
        for (final optId in v.optionIds) {
          counts[optId] = (counts[optId] ?? 0) + 1;
        }
      }
      for (final opt in poll.options) {
        opt.voteCount = counts[opt.id] ?? 0;
      }
      poll.touch(now);
      await _store.putInTxn(txn, poll);
    });
  }

  Future<List<VoteCollection>> votesByPoll(String pollId) async => _votes.find(
        filter:
            Filter.equals('pollId', pollId) & Filter.equals('isDeleted', false),
      );

  PollType typeFromString(String value) => PollType.values
      .firstWhere((e) => e.name == value, orElse: () => PollType.singleChoice);
}
