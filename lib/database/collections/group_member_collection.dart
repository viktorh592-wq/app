/// Group member collection — many-to-many link User ↔ Group with a role
/// (V2 GROUPS_AND_ACTIVITIES.md §4). Soft-deleted when the member leaves or
/// is removed (Soft_Delete.md).
import 'package:pokatuha/database/base_entity.dart';

class GroupMemberCollection extends BaseEntity {
  String groupId = '';
  String userId = '';

  /// GroupRole enum name (owner / admin / member).
  String role = 'member';

  /// Who added this member (null — joined by invite link/QR).
  String? addedBy;

  /// When the member joined (UTC ms).
  int? joinedAt;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'groupId': groupId,
      'userId': userId,
      'role': role,
      'addedBy': addedBy,
      'joinedAt': joinedAt,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    groupId = m['groupId'] as String? ?? '';
    userId = m['userId'] as String? ?? '';
    role = m['role'] as String? ?? 'member';
    addedBy = m['addedBy'] as String?;
    joinedAt = (m['joinedAt'] as num?)?.toInt();
  }

  static GroupMemberCollection fromMap(Map<String, dynamic> m) =>
      GroupMemberCollection()..applyMap(m);
}
