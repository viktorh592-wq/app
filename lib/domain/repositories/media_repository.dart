/// Media repository — photos, videos and generic attachments
/// (Storage.md — database stores metadata only; large files stay outside).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/attachment_collection.dart';
import 'package:pokatuha/database/collections/photo_collection.dart';
import 'package:pokatuha/database/collections/video_collection.dart';
import 'package:pokatuha/database/database.dart';

class MediaRepository {
  MediaRepository(this._db);
  final DatabaseService _db;

  // --- Photos ---
  Future<List<PhotoCollection>> photosByEvent(String eventId) async =>
      _db.photosStore.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt', false)],
      );

  Future<PhotoCollection> addPhoto({
    required String eventId,
    required String authorId,
    required String path,
    String? thumbnailPath,
    String? hash,
    int width = 0,
    int height = 0,
    int sizeBytes = 0,
  }) async {
    final now = Timestamps.nowUtc();
    final photo = PhotoCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..authorId = authorId
      ..path = path
      ..thumbnailPath = thumbnailPath
      ..hash = hash
      ..width = width
      ..height = height
      ..sizeBytes = sizeBytes
      ..createdBy = authorId;
    return _db.photosStore.put(photo);
  }

  // --- Videos ---
  Future<List<VideoCollection>> videosByEvent(String eventId) async =>
      _db.videosStore.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt', false)],
      );

  Future<VideoCollection> addVideo({
    required String eventId,
    required String authorId,
    required String path,
    String? thumbnailPath,
    int durationSeconds = 0,
    int width = 0,
    int height = 0,
    int sizeBytes = 0,
  }) async {
    final now = Timestamps.nowUtc();
    final video = VideoCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..authorId = authorId
      ..path = path
      ..thumbnailPath = thumbnailPath
      ..durationSeconds = durationSeconds
      ..width = width
      ..height = height
      ..sizeBytes = sizeBytes
      ..createdBy = authorId;
    return _db.videosStore.put(video);
  }

  // --- Attachments ---
  Future<List<AttachmentCollection>> attachmentsByEvent(String eventId) async =>
      _db.attachmentsStore.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt', false)],
      );
}
