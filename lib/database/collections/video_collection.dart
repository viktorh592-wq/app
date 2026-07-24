/// Video metadata collection (Storage.md — database stores metadata only).
import 'package:pokatuha/database/base_entity.dart';

class VideoCollection extends BaseEntity {
  String eventId = '';
  String authorId = '';

  String path = '';
  String? thumbnailPath;
  String? hash;

  int durationSeconds = 0;
  int width = 0;
  int height = 0;
  int sizeBytes = 0;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'authorId': authorId,
      'path': path,
      'thumbnailPath': thumbnailPath,
      'hash': hash,
      'durationSeconds': durationSeconds,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    authorId = m['authorId'] as String? ?? '';
    path = m['path'] as String? ?? '';
    thumbnailPath = m['thumbnailPath'] as String?;
    hash = m['hash'] as String?;
    durationSeconds = (m['durationSeconds'] as num?)?.toInt() ?? 0;
    width = (m['width'] as num?)?.toInt() ?? 0;
    height = (m['height'] as num?)?.toInt() ?? 0;
    sizeBytes = (m['sizeBytes'] as num?)?.toInt() ?? 0;
  }

  static VideoCollection fromMap(Map<String, dynamic> m) =>
      VideoCollection()..applyMap(m);
}
