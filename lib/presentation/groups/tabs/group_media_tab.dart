/// Group → Media tab (V2 GROUPS_AND_ACTIVITIES.md §5): gallery of photos and
/// videos from all chats of this group's activities. Metadata comes from the
/// local Sembast stores; files stay outside the database (Storage.md).
import 'package:flutter/material.dart';

import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/photo_collection.dart';
import 'package:pokatuha/database/collections/video_collection.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/media_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

class GroupMediaTab extends StatefulWidget {
  const GroupMediaTab({super.key, required this.group});

  final GroupCollection group;

  @override
  State<GroupMediaTab> createState() => _GroupMediaTabState();
}

class _GroupMediaTabState extends State<GroupMediaTab>
    with AutomaticKeepAliveClientMixin {
  late Future<_GroupMediaData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final events =
          await serviceLocator<EventRepository>().byGroup(widget.group.id);
      final media = serviceLocator<MediaRepository>();
      final photos = <PhotoCollection>[];
      final videos = <VideoCollection>[];
      for (final e in events) {
        photos.addAll(await media.photosByEvent(e.id));
        videos.addAll(await media.videosByEvent(e.id));
      }
      return _GroupMediaData(photos: photos, videos: videos);
    }();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: FutureBuilder<_GroupMediaData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final total = data.photos.length + data.videos.length;
          if (total == 0) {
            return ListView(children: [
              const SizedBox(height: 64),
              EmptyState(
                icon: Icons.photo_library_outlined,
                title: l.noMedia,
                subtitle: l.noMediaHint,
              ),
            ]);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: total,
            itemBuilder: (context, i) {
              final photo = i < data.photos.length ? data.photos[i] : null;
              final video = i >= data.photos.length
                  ? data.videos[i - data.photos.length]
                  : null;
              return _MediaTile(photo: photo, video: video);
            },
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({this.photo, this.video});

  final PhotoCollection? photo;
  final VideoCollection? video;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            video != null ? Icons.videocam_rounded : Icons.image_rounded,
            size: 32,
            color: scheme.outline,
          ),
          if (video != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${video!.durationSeconds}s',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupMediaData {
  _GroupMediaData({required this.photos, required this.videos});

  final List<PhotoCollection> photos;
  final List<VideoCollection> videos;
}
