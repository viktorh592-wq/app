/// Vote collection — belongs to a Participant and a Poll
/// (Entity_Relationships.md).
import 'package:pokatuha/database/base_entity.dart';

class VoteCollection extends BaseEntity {
  String pollId = '';
  String participantId = '';
  String userId = '';

  /// Chosen option ids (multiple for multipleChoice polls).
  List<String> optionIds = [];

  /// Optional custom option text when allowed.
  String? customOption;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'pollId': pollId,
      'participantId': participantId,
      'userId': userId,
      'optionIds': optionIds,
      'customOption': customOption,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    pollId = m['pollId'] as String? ?? '';
    participantId = m['participantId'] as String? ?? '';
    userId = m['userId'] as String? ?? '';
    final ids = m['optionIds'];
    optionIds = ids is List ? ids.cast<String>() : [];
    customOption = m['customOption'] as String?;
  }

  static VoteCollection fromMap(Map<String, dynamic> m) =>
      VoteCollection()..applyMap(m);
}
