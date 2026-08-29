/// Group collection — V2 Group-first model (GROUPS_AND_ACTIVITIES.md §1–§4).
/// The application is organized around permanent groups; activities are
/// always created inside a group. Local-First: groups live on the device
/// (ADR-001) and sync P2P later (ADR-002).
import 'package:pokatuha/database/base_entity.dart';

class GroupCollection extends BaseEntity {
  String name = '';
  String? avatarPath;
  String? description;

  /// GroupType enum name (public / private / inviteOnly).
  String type = 'private';

  /// Owner user id (GROUPS_AND_ACTIVITIES.md §4 — Owner).
  String ownerId = '';

  /// Default map provider for new activities in this group (optional).
  String? defaultMapProvider;

  /// Default activity accent color ARGB int (GROUPS_AND_ACTIVITIES.md §3).
  int? defaultAccentColor;

  /// Whether the group is discoverable in search (depends on type).
  bool discoverable = false;

  /// Invite code for pokatuha://g/<code> links (USER_DISCOVERY.md §2).
  String? inviteCode;

  /// Maximum 30 participants per group (ARCHITECTURE_V2.md §3).
  int get maxMembers => 30;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'name': name,
      'avatarPath': avatarPath,
      'description': description,
      'type': type,
      'ownerId': ownerId,
      'defaultMapProvider': defaultMapProvider,
      'defaultAccentColor': defaultAccentColor,
      'discoverable': discoverable,
      'inviteCode': inviteCode,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    name = m['name'] as String? ?? '';
    avatarPath = m['avatarPath'] as String?;
    description = m['description'] as String?;
    type = m['type'] as String? ?? 'private';
    ownerId = m['ownerId'] as String? ?? '';
    defaultMapProvider = m['defaultMapProvider'] as String?;
    defaultAccentColor = (m['defaultAccentColor'] as num?)?.toInt();
    discoverable = m['discoverable'] as bool? ?? false;
    inviteCode = m['inviteCode'] as String?;
  }

  static GroupCollection fromMap(Map<String, dynamic> m) =>
      GroupCollection()..applyMap(m);
}
