/// Telegram-style chat bubble (TELEGRAM_STYLE_CHAT.md §3–§5).
/// Outgoing = activity accent (V2 §11) or lime default, incoming = yellow.
/// Incoming bubbles show the sender name and an avatar; only the last bubble
/// of a group shows the timestamp (Telegram-like grouping).
///
/// V3 Sprint 3 (FIX_PLAN S3-T2..T11) — the bubble now renders:
///   • a forward header (S3-T4) when [forwardedFromName] is set;
///   • a reply preview (S3-T3) when [replyPreview] is set;
///   • an attachment preview (S3-T6..S3-T9) when [attachment] is set;
///   • a reactions row (S3-T2) under the bubble;
///   • a delivery icon (S3-T10) for outgoing messages;
///   • a read-by count (S3-T11) for outgoing messages in group chats.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';

/// Compact reply-preview block used above the composer and inside bubbles.
class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    super.key,
    required this.senderName,
    required this.snippet,
    required this.accentColor,
    this.onTap,
    this.onClose,
  });

  final String senderName;
  final String snippet;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            border: Border(left: BorderSide(color: accentColor, width: 3)),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.pin(color: accentColor)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.pin(),
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline reactions row (S3-T2). Tapping a chip toggles the user's
/// reaction. Empty when the message has no reactions.
class ReactionsRow extends StatelessWidget {
  const ReactionsRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.accentColor,
    required this.onToggle,
  });

  /// Map {emoji: [userId, ...]} (already de-duplicated upstream).
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final Color accentColor;
  final void Function(String emoji) onToggle;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: reactions.entries.map((entry) {
        final mine = entry.value.contains(currentUserId);
        return ActionChip(
          label: Text('${entry.key} ${entry.value.length}',
              style: DesignTokens.pin()),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          backgroundColor:
              mine ? accentColor.withOpacity(0.25) : DesignTokens.chipLavender,
          onPressed: () => onToggle(entry.key),
        );
      }).toList(),
    );
  }
}

/// Delivery state icon for outgoing bubbles (S3-T10, FIX_PLAN §S3-T10).
class DeliveryIcon extends StatelessWidget {
  const DeliveryIcon({super.key, required this.state, this.readByCount = 0});

  final DeliveryState state;
  final int readByCount;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      DeliveryState.queued => const Icon(Icons.access_time_rounded, size: 14),
      DeliveryState.sending => const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      DeliveryState.delivered => const Icon(Icons.check_rounded, size: 14),
      DeliveryState.synced => const Icon(Icons.done_all_rounded, size: 14),
    };
    if (readByCount <= 0 || state != DeliveryState.synced) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 2),
        Text(
          '$readByCount',
          style: DesignTokens.pin(color: DesignTokens.textSecondary),
        ),
      ],
    );
  }
}

/// Attachment preview card rendered inside the bubble for image / video /
/// voice / document / location / route attachments (S3-T6..S3-T9, S3-T12).
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.message,
    this.onTapMedia,
    this.onOpenMap,
    this.onOpenDocument,
  });

  final MessageCollection message;
  final VoidCallback? onTapMedia;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final type = message.attachment;
    if (type == null) return const SizedBox.shrink();
    return switch (type) {
      AttachmentType.image => _imagePreview(context),
      AttachmentType.video => _videoPreview(context),
      AttachmentType.voice => _voicePreview(context),
      AttachmentType.document => _documentPreview(context),
      AttachmentType.location => _locationPreview(context),
      AttachmentType.route => _routePreview(context),
      AttachmentType.poll => const SizedBox.shrink(),
    };
  }

  Widget _imagePreview(BuildContext context) {
    final path = message.attachmentPath;
    if (path == null) return const SizedBox.shrink();
    final file = File(path);
    return GestureDetector(
      onTap: onTapMedia,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: DesignTokens.chipLavender,
              padding: const EdgeInsets.all(12),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, size: 32),
                  SizedBox(height: 4),
                  Text('image'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoPreview(BuildContext context) {
    return GestureDetector(
      onTap: onTapMedia,
      child: Container(
        width: 200,
        height: 130,
        decoration: BoxDecoration(
          color: DesignTokens.chipLavender,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.play_circle_filled_rounded, size: 48),
            Positioned(
              bottom: 6,
              right: 6,
              child: Icon(Icons.videocam_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voicePreview(BuildContext context) {
    final meta = message.attachmentMetaMap;
    final durationSecs = (meta['duration'] as num?)?.toInt() ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow_rounded, size: 22),
        const SizedBox(width: 4),
        // Pseudo-waveform — purely visual placeholder (FIX_PLAN S3-T6 accepts
        // a stylised waveform; a true waveform extractor arrives with a
        // dedicated parser in a follow-up task).
        Expanded(
          child: Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: CustomPaint(
              painter: _WaveformPainter(seed: message.id.hashCode),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${durationSecs ~/ 60}:${(durationSecs % 60).toString().padLeft(2, '0')}',
          style: DesignTokens.pin(),
        ),
      ],
    );
  }

  Widget _documentPreview(BuildContext context) {
    final meta = message.attachmentMetaMap;
    final name = (meta['name'] as String?) ?? 'document';
    final sizeBytes = (meta['size'] as num?)?.toInt() ?? 0;
    final sizeLabel = sizeBytes > 0 ? _humanSize(sizeBytes) : '';
    return InkWell(
      onTap: onOpenDocument,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: DesignTokens.chipLavender,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTokens.pin()
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (sizeLabel.isNotEmpty)
                    Text(
                      sizeLabel,
                      style: DesignTokens.pin(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationPreview(BuildContext context) {
    final meta = message.attachmentMetaMap;
    final lat = (meta['lat'] as num?)?.toDouble() ?? 0;
    final lng = (meta['lng'] as num?)?.toDouble() ?? 0;
    return GestureDetector(
      onTap: onOpenMap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: SizedBox(
          width: 220,
          height: 130,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 13,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                serviceLocator<MapService>().tileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 24,
                      height: 24,
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routePreview(BuildContext context) {
    final meta = message.attachmentMetaMap;
    final waypoints = (meta['waypoints'] as List?)
            ?.map((e) => GeoPoint.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <GeoPoint>[];
    if (waypoints.isEmpty) {
      return InkWell(
        onTap: onOpenMap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DesignTokens.chipLavender,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_rounded),
              const SizedBox(width: 8),
              Text('route', style: DesignTokens.pin()),
            ],
          ),
        ),
      );
    }
    final points = waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    return GestureDetector(
      onTap: onOpenMap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: SizedBox(
          width: 220,
          height: 130,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 12,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                serviceLocator<MapService>().tileLayer(),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: DesignTokens.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i += 1;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.textSecondary
      ..style = PaintingStyle.fill;
    const barCount = 24;
    final barWidth = size.width / (barCount * 2 - 1);
    for (var i = 0; i < barCount; i++) {
      // Deterministic pseudo-random height in [0.2, 1.0] of the strip.
      final r = ((seed + i * 37) % 100) / 100.0;
      final h = (0.2 + r * 0.8) * size.height;
      final x = (i * 2) * barWidth;
      final y = (size.height - h) / 2;
      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.seed != seed;
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isOutgoing;
  final String? senderName;
  final DateTime? timestamp;
  final bool showAvatar;
  final bool showTimestamp;
  final String? avatarUrl;
  final Color? outgoingColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// V3 Sprint 3 — Telegram-style extras.
  /// Forwarded-from sender label (S3-T4); null for non-forwarded messages.
  final String? forwardedFromName;

  /// Reply preview data (S3-T3): sender name + text snippet of the original.
  /// Tapping the preview scrolls the chat to the original.
  final ({String sender, String snippet})? replyPreview;
  final VoidCallback? onTapReply;

  /// Reactions map (S3-T2) and current user id (for highlight + toggle).
  final Map<String, List<String>> reactions;
  final String? currentUserId;
  final void Function(String emoji)? onToggleReaction;

  /// Attachment payload (S3-T6..S3-T9). Bubble reads message.attachment.
  final MessageCollection? message;
  final VoidCallback? onTapMedia;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenDocument;

  /// Delivery state for outgoing messages (S3-T10) + read-by count (S3-T11).
  final DeliveryState? deliveryState;
  final int readByCount;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutgoing,
    this.senderName,
    this.timestamp,
    this.showAvatar = true,
    this.showTimestamp = true,
    this.avatarUrl,
    this.outgoingColor,
    this.onTap,
    this.onLongPress,
    this.forwardedFromName,
    this.replyPreview,
    this.onTapReply,
    this.reactions = const {},
    this.currentUserId,
    this.onToggleReaction,
    this.message,
    this.onTapMedia,
    this.onOpenMap,
    this.onOpenDocument,
    this.deliveryState,
    this.readByCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.of(context).size.width * DesignTokens.bubbleMaxWidth;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space3,
            vertical: DesignTokens.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOutgoing && showAvatar) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: DesignTokens.chipLavender,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: DesignTokens.space2),
              ],
              Flexible(
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space4,
                      vertical: DesignTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: isOutgoing
                          ? (outgoingColor ?? DesignTokens.limeAccent)
                          : DesignTokens.yellowAccent,
                      borderRadius: BorderRadius.only(
                        topLeft:
                            const Radius.circular(DesignTokens.bubbleRadius),
                        topRight:
                            const Radius.circular(DesignTokens.bubbleRadius),
                        bottomLeft: Radius.circular(
                          isOutgoing ? DesignTokens.bubbleRadius : 4,
                        ),
                        bottomRight: Radius.circular(
                          isOutgoing ? 4 : DesignTokens.bubbleRadius,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (forwardedFromName != null) ...[
                          _ForwardedHeader(name: forwardedFromName!),
                          const SizedBox(height: 2),
                        ],
                        if (replyPreview != null) ...[
                          ReplyPreview(
                            senderName: replyPreview!.sender,
                            snippet: replyPreview!.snippet,
                            accentColor: outgoingColor ?? DesignTokens.primary,
                            onTap: onTapReply,
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (!isOutgoing &&
                            senderName != null &&
                            senderName!.isNotEmpty &&
                            forwardedFromName == null) ...[
                          Text(
                            senderName!,
                            style: DesignTokens.pin(
                              color: DesignTokens.textSecondary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (message != null && message!.attachment != null) ...[
                          AttachmentPreview(
                            message: message!,
                            onTapMedia: onTapMedia,
                            onOpenMap: onOpenMap,
                            onOpenDocument: onOpenDocument,
                          ),
                          if (text.isNotEmpty) const SizedBox(height: 4),
                        ],
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: DesignTokens.body(
                                color: DesignTokens.textPrimary),
                          ),
                        if (reactions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ReactionsRow(
                            reactions: reactions,
                            currentUserId: currentUserId ?? '',
                            accentColor:
                                outgoingColor ?? DesignTokens.primary,
                            onToggle: (emoji) =>
                                onToggleReaction?.call(emoji),
                          ),
                        ],
                        if (showTimestamp && timestamp != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isOutgoing && deliveryState != null) ...[
                                DeliveryIcon(
                                  state: deliveryState!,
                                  readByCount: readByCount,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  _formatTime(timestamp!),
                                  style: DesignTokens.pin(
                                    color: DesignTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isOutgoing && deliveryState != null) ...[
                          const SizedBox(height: 2),
                          DeliveryIcon(
                            state: deliveryState!,
                            readByCount: readByCount,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ForwardedHeader extends StatelessWidget {
  const _ForwardedHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.shortcut_rounded,
          size: 14,
          color: DesignTokens.textSecondary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTokens.pin(
              color: DesignTokens.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
