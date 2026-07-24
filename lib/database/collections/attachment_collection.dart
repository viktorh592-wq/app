/// Generic attachment collection for documents / GPX imports / other media.
import 'package:pokatuha/database/base_entity.dart';

class AttachmentCollection extends BaseEntity {
  String eventId = '';
  String authorId = '';

  String fileName = '';
  String path = '';
  String mimeType = '';
  int sizeBytes = 0;
  String? hash;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'authorId': authorId,
      'fileName': fileName,
      'path': path,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'hash': hash,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    authorId = m['authorId'] as String? ?? '';
    fileName = m['fileName'] as String? ?? '';
    path = m['path'] as String? ?? '';
    mimeType = m['mimeType'] as String? ?? '';
    sizeBytes = (m['sizeBytes'] as num?)?.toInt() ?? 0;
    hash = m['hash'] as String?;
  }

  static AttachmentCollection fromMap(Map<String, dynamic> m) =>
      AttachmentCollection()..applyMap(m);
}
