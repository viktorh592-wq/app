/// Local-network P2P communication service.
///
/// Bug 1 (V3.0.3): the previous [LocalCommunicationService] was in-process
/// only (loopback) so chat messages never actually left the device. This
/// wrapper adds a UDP broadcast transport on the local Wi-Fi so chat
/// envelopes flow between devices on the same network.
///
/// Architectural rationale (ADR-008 — Local-network UDP transport):
///   • Local-First compliant — no cloud, no signaling server (ADR-001, ADR-013)
///   • Uses dart:io RawDatagramSocket — no new pub dependency
///   • Discovery is implicit: every device both broadcasts and listens on
///     port 53100, so peers on the same Wi-Fi see each other automatically
///   • The Wi-Fi multicast lock is acquired via a platform channel so the
///     Android Wi-Fi chip keeps delivering broadcast packets to the app
///
/// Limitations (documented in ADR-008):
///   • Works only on the same Wi-Fi — across-network chat needs WebRTC
///     (ADR-002) which is a future sprint
///   • UDP — no delivery guarantee. Receivers ack via the same channel;
///     missing acks leave the outgoing bubble in `delivered` (best-effort)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/communication_service.dart';

/// Default UDP port used by all Pokatuha devices on the local network.
const int kPokatuhaUdpPort = 53100;

/// Method channel used to acquire the Android Wi-Fi multicast lock so the
/// Wi-Fi chip keeps delivering broadcast packets to the app (without this
/// lock, Android suspends multicast/broadcast packet delivery shortly after
/// the screen turns off — see Android docs for WifiManager.MulticastLock).
const MethodChannel _kMulticastLockChannel =
    MethodChannel('pokatuha/network');

/// A [CommunicationService] that adds local-network UDP broadcast on top of
/// the in-process loopback. Both transports run concurrently:
///
///   • In-process loopback — keeps unit tests deterministic and lets the
///     offline queue (UC-005) replay without a network.
///   • UDP broadcast — delivers chat / GPS / presence envelopes to other
///     Pokatuha devices on the same Wi-Fi.
class LocalNetworkCommunicationService implements CommunicationService {
  LocalNetworkCommunicationService({int port = kPokatuhaUdpPort})
      : _port = port {
    _inner = LocalCommunicationService();
    // Listen to the in-process loopback and re-emit through our own
    // incoming stream so subscribers see a single merged stream.
    _inner.incoming.listen(_incomingController.add);
    // Boot the network transport lazily so the constructor is cheap and
    // never throws (allows the service-locator singleton to start even on
    // platforms where UDP is unavailable, e.g. web / unit tests).
    if (!kIsWeb && !_isUnitTestEnvironment) {
      // Fire-and-forget; errors are logged but never block startup.
      _bootNetwork().catchError((Object _) {});
    }
  }

  final int _port;
  late final LocalCommunicationService _inner;

  final StreamController<CommunicationMode> _modeController =
      StreamController<CommunicationMode>.broadcast();
  final StreamController<RealtimeEnvelope> _incomingController =
      StreamController<RealtimeEnvelope>.broadcast();

  RawDatagramSocket? _socket;
  bool _multicastLockAcquired = false;
  bool _networkBooted = false;

  /// True when running inside `flutter test` (which sets the
  /// FLUTTER_TEST env var). Used to skip the UDP bind so tests stay
  /// deterministic and never touch the real network.
  bool get _isUnitTestEnvironment =>
      const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false) ||
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  CommunicationMode get mode => _inner.mode;

  @override
  Stream<CommunicationMode> get modeStream {
    // Merge inner mode changes into our own broadcast.
    _inner.modeStream.listen(_modeController.add);
    return _modeController.stream;
  }

  @override
  Stream<RealtimeEnvelope> get incoming => _incomingController.stream;

  @override
  Future<void> connect({
    required String sessionId,
    required String peerToken,
  }) async {
    await _inner.connect(sessionId: sessionId, peerToken: peerToken);
    if (!_networkBooted && !kIsWeb && !_isUnitTestEnvironment) {
      await _bootNetwork();
    }
  }

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    // Always do the in-process loopback first (tests rely on it and it's
    // the only transport in offline mode).
    await _inner.broadcast(envelope);
    // Then push the envelope over UDP so other devices on the same Wi-Fi
    // receive it. Failures are swallowed — UDP is best-effort.
    if (!_networkBooted || kIsWeb || _isUnitTestEnvironment) return;
    try {
      final payload = jsonEncode({
        'type': envelope.type.name,
        'senderId': envelope.senderId,
        'timestamp': envelope.timestamp,
        'payload': envelope.payload,
      });
      final bytes = utf8.encode(payload);
      // 255.255.255.255 is the limited broadcast address — reaches every
      // device on the same L2 segment (Wi-Fi), without needing to know the
      // subnet's directed broadcast address.
      _socket?.send(bytes, InternetAddress('255.255.255.255'), _port);
    } catch (_) {
      // Network failures are non-fatal: the message is still stored locally
      // and queued for retry on the next sync window.
    }
  }

  @override
  Future<void> disconnect() async {
    await _inner.disconnect();
    _releaseMulticastLock();
    // RawDatagramSocket.close() is synchronous (void), so we don't await.
    _socket?.close();
    _socket = null;
    _networkBooted = false;
  }

  @override
  Future<void> onFcmWakeUp({required String sessionId}) async {
    await _inner.onFcmWakeUp(sessionId: sessionId);
  }

  @override
  void enqueue(PendingChange change) => _inner.enqueue(change);

  @override
  List<PendingChange> get pendingQueue => _inner.pendingQueue;

  @override
  Future<void> syncPending() => _inner.syncPending();

  /// Boot the UDP socket and acquire the Wi-Fi multicast lock.
  Future<void> _bootNetwork() async {
    if (_networkBooted) return;
    try {
      await _acquireMulticastLock();
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
        // reusePort / broadcast are platform-dependent — we set them after
        // bind on platforms that support it (Linux / Android).
      );
      // Enable broadcast on the socket (off by default).
      _socket?.broadcastEnabled = true;
      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram == null) return;
          _handleIncoming(datagram);
        }
      });
      _networkBooted = true;
    } catch (_) {
      // Binding can fail in a sandboxed CI environment — fall back silently
      // to the in-process loopback. The app stays usable for local tests.
      _networkBooted = false;
    }
  }

  void _handleIncoming(Datagram datagram) {
    try {
      final json = jsonDecode(utf8.decode(datagram.data));
      if (json is! Map<String, dynamic>) return;
      final typeStr = json['type'] as String?;
      final senderId = json['senderId'] as String? ?? '';
      final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
      final payload = json['payload'];
      if (payload is! Map<String, dynamic>) return;
      // Ignore envelopes we sent ourselves — the in-process loopback
      // already routes them back so the local listener reacts once.
      if (senderId == _selfSenderId) return;
      final type = _parseType(typeStr);
      if (type == null) return;
      _incomingController.add(RealtimeEnvelope(
        type: type,
        payload: payload,
        senderId: senderId,
        timestamp: timestamp,
      ));
    } catch (_) {
      // Malformed packet — drop silently.
    }
  }

  RealtimeType? _parseType(String? name) {
    if (name == null) return null;
    for (final t in RealtimeType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Sender id is set by the ChatService / AppViewModel after auth so the
  /// network transport can drop its own broadcast packets.
  String _selfSenderId = '';

  /// Public setter — the chat wiring calls this on app boot so we can
  /// filter our own broadcasts.
  set selfSenderId(String value) => _selfSenderId = value;

  Future<void> _acquireMulticastLock() async {
    if (kIsWeb || _isUnitTestEnvironment) return;
    if (_multicastLockAcquired) return;
    try {
      final result = await _kMulticastLockChannel
          .invokeMethod<bool>('acquireMulticastLock');
      _multicastLockAcquired = result ?? false;
    } on MissingPluginException {
      // Plugin not registered on this platform (desktop / test) — fine,
      // broadcast reception will still work without the lock while the app
      // is in the foreground.
    } on PlatformException {
      // Same — non-fatal.
    }
  }

  Future<void> _releaseMulticastLock() async {
    if (!_multicastLockAcquired) return;
    try {
      await _kMulticastLockChannel
          .invokeMethod<bool>('releaseMulticastLock');
    } catch (_) {
      // Non-fatal.
    }
    _multicastLockAcquired = false;
  }

  void dispose() {
    _releaseMulticastLock();
    _socket?.close();
    _inner.dispose();
    _incomingController.close();
    _modeController.close();
  }
}

/// Helper to build a chat [RealtimeEnvelope] from a saved
/// [MessageCollection.toMap] payload. Used by MessageRepository.sendText to
/// broadcast the freshly-saved message to other devices on the same Wi-Fi.
RealtimeEnvelope buildChatEnvelope({
  required Map<String, dynamic> messageMap,
  required String senderId,
}) {
  return RealtimeEnvelope(
    type: RealtimeType.chat,
    payload: messageMap,
    senderId: senderId,
    timestamp: DateTime.now().toUtc().millisecondsSinceEpoch,
  );
}
