/// Base entity implementing the mandatory fields defined in
/// Entity_Standards.md:
///   - id        (UUID v7, immutable, unique)
///   - createdAt (UTC ms)
///   - updatedAt (UTC ms)
///   - version   (starts at 1, increments on update — Versioning.md)
///   - isDeleted (soft delete — Soft_Delete.md)
/// Optional: createdBy, updatedBy, deletedAt, deletedBy, notes, metadata.
///
/// Stored as JSON-compatible maps via Sembast (ADR-005). No incremental IDs
/// are ever used as business identifiers (Isar_Collections.md).
import 'dart:convert';

abstract class BaseEntity {
  String id = '';
  int createdAt = 0;
  int updatedAt = 0;
  int version = 1;
  bool isDeleted = false;
  int? deletedAt;
  String? createdBy;
  String? updatedBy;
  String? deletedBy;
  String? notes;
  Map<String, dynamic>? metadata;

  /// Map of common fields (subclasses merge their own fields with this).
  Map<String, dynamic> baseToMap() => {
        'id': id,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'version': version,
        'isDeleted': isDeleted,
        'deletedAt': deletedAt,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'deletedBy': deletedBy,
        'notes': notes,
        'metadata': metadata == null ? null : jsonEncode(metadata),
      };

  void baseFromMap(Map<String, dynamic> m) {
    id = m['id'] as String? ?? '';
    createdAt = (m['createdAt'] as num?)?.toInt() ?? 0;
    updatedAt = (m['updatedAt'] as num?)?.toInt() ?? 0;
    version = (m['version'] as num?)?.toInt() ?? 1;
    isDeleted = m['isDeleted'] as bool? ?? false;
    deletedAt = (m['deletedAt'] as num?)?.toInt();
    createdBy = m['createdBy'] as String?;
    updatedBy = m['updatedBy'] as String?;
    deletedBy = m['deletedBy'] as String?;
    notes = m['notes'] as String?;
    final metaJson = m['metadata'] as String?;
    metadata =
        metaJson == null ? null : jsonDecode(metaJson) as Map<String, dynamic>;
  }

  /// Subclasses implement these to (de)serialize their own fields.
  Map<String, dynamic> toMap();
  void applyMap(Map<String, dynamic> m);

  /// Mark the entity as updated: bump version and refresh [updatedAt].
  void touch(int utcMillis) {
    updatedAt = utcMillis;
    version += 1;
  }

  /// Apply a soft delete (Soft_Delete.md).
  void softDelete(int utcMillis, {String? by}) {
    isDeleted = true;
    deletedAt = utcMillis;
    deletedBy = by;
    touch(utcMillis);
  }
}
