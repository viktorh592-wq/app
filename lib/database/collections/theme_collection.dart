/// Theme collection — Telegram-like customization (Decision_Log — Themes).
/// Theme belongs to a User (Entity_Relationships.md).
import 'package:pokatuha/database/base_entity.dart';

class ThemeCollection extends BaseEntity {
  String userId = '';
  String name = '';

  /// AppThemeMode enum stored as string.
  String mode = 'dark';

  /// Accent color as 0xAARRGGBB int.
  int accentColor = 0xFF3B82F6;

  /// Map style URL / id.
  String? mapStyleId;

  bool isDefault = false;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'userId': userId,
      'name': name,
      'mode': mode,
      'accentColor': accentColor,
      'mapStyleId': mapStyleId,
      'isDefault': isDefault,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    userId = m['userId'] as String? ?? '';
    name = m['name'] as String? ?? '';
    mode = m['mode'] as String? ?? 'dark';
    accentColor = (m['accentColor'] as num?)?.toInt() ?? 0xFF3B82F6;
    mapStyleId = m['mapStyleId'] as String?;
    isDefault = m['isDefault'] as bool? ?? false;
  }

  static ThemeCollection fromMap(Map<String, dynamic> m) =>
      ThemeCollection()..applyMap(m);
}
