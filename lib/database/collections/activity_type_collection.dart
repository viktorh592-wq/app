/// Activity type collection (FR-002 — unlimited custom activity types).
import 'package:pokatuha/database/base_entity.dart';

class ActivityTypeCollection extends BaseEntity {
  String key = '';
  String label = '';

  /// Icon identifier (Material icon name).
  String icon = '';

  /// Whether this is a built-in default type (README.md) or user-created.
  bool isBuiltIn = false;

  String? ownerId;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'key': key,
      'label': label,
      'icon': icon,
      'isBuiltIn': isBuiltIn,
      'ownerId': ownerId,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    key = m['key'] as String? ?? '';
    label = m['label'] as String? ?? '';
    icon = m['icon'] as String? ?? '';
    isBuiltIn = m['isBuiltIn'] as bool? ?? false;
    ownerId = m['ownerId'] as String?;
  }

  static ActivityTypeCollection fromMap(Map<String, dynamic> m) =>
      ActivityTypeCollection()..applyMap(m);
}
