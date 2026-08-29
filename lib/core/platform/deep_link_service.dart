/// Deep link service — receives `pokatuha://` URIs from the platform
/// (Android intent-filter, FIX_PLAN S1-T7) through a lightweight platform
/// channel: a MethodChannel for the cold-start link and an EventChannel for
/// links arriving while the app runs.
///
/// Falls back gracefully (no links) on platforms where the channel is not
/// implemented — tests and desktop.
import 'dart:async';

import 'package:flutter/services.dart';

class DeepLinkService {
  static const MethodChannel _methodChannel =
      MethodChannel('pokatuha/deep_links');
  static const EventChannel _eventChannel =
      EventChannel('pokatuha/deep_links/events');

  StreamSubscription<dynamic>? _subscription;
  final _controller = StreamController<String>.broadcast();

  /// Broadcast stream of incoming pokatuha:// links.
  Stream<String> get links => _controller.stream;

  /// URI the app was launched with (cold start), null if none.
  Future<String?> initialLink() async {
    try {
      final link = await _methodChannel.invokeMethod<String>(
        'getInitialLink',
      );
      return (link == null || link.isEmpty) ? null : link;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Start listening for links while the app is running.
  void start() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic link) {
        if (link is String && link.isNotEmpty) {
          _controller.add(link);
        }
      },
      onError: (Object _) {},
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
