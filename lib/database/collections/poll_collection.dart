/// Poll collection (FR-007). Poll belongs to an event and contains votes
/// (Entity_Relationships.md).
///
/// V3 Sprint 5 (FIX_PLAN S5-T1) — extended to support the V2 POLLS.md spec:
/// • visibility (anonymous / public) — §3
/// • deadline auto-close on read — §4 (PollRepository)
/// • closed state final-results view — §5 (activity_polls_tab)
import 'package:pokatuha/database/base_entity.dart';
import 'package:pokatuha/database/collections/embedded/poll_option.dart';

class PollCollection extends BaseEntity {
  String eventId = '';
  String question = '';

  /// PollType enum stored as string.
  String type = 'singleChoice';

  /// PollStatus enum stored as string.
  String status = 'open';

  /// PollVisibility enum stored as string (V2 POLLS.md §3).
  /// anonymous = vote tally only; public = also show who voted for what.
  String visibility = 'public';

  /// At least two options (Data_Validation.md).
  List<PollOption> options = [];

  /// Deadline in UTC ms (nullable = no deadline).
  int? deadlineAt;

  bool allowCustomOptions = false;

  /// Whether votes are editable (FR-007 — Editable poll).
  bool editable = true;

  String? createdByParticipantId;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'question': question,
      'type': type,
      'status': status,
      'visibility': visibility,
      'options': options.map((o) => o.toMap()).toList(),
      'deadlineAt': deadlineAt,
      'allowCustomOptions': allowCustomOptions,
      'editable': editable,
      'createdByParticipantId': createdByParticipantId,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    question = m['question'] as String? ?? '';
    type = m['type'] as String? ?? 'singleChoice';
    status = m['status'] as String? ?? 'open';
    visibility = m['visibility'] as String? ?? 'public';
    final opts = m['options'];
    options = opts is List
        ? opts
            .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o as Map)))
            .toList()
        : [];
    deadlineAt = (m['deadlineAt'] as num?)?.toInt();
    allowCustomOptions = m['allowCustomOptions'] as bool? ?? false;
    editable = m['editable'] as bool? ?? true;
    createdByParticipantId = m['createdByParticipantId'] as String?;
  }

  static PollCollection fromMap(Map<String, dynamic> m) =>
      PollCollection()..applyMap(m);
}
