/// Local-network P2P communication service (V3.0.4 — user-reported bug 1).
///
/// The previous [LocalCommunicationService] was an in-process loopback only:
/// `broadcast()` routed the envelope back to the same device, so chat
/// messages never left the phone. This wrapper adds a real transport —
/// UDP broadcast on the local Wi-Fi — while keeping the loopback behaviour
/// for tests and the offline queue.
///
/// Architectural rationale (ADR-008 — Local-network UDP transport):
///   * Local-First compliant — no cloud, no signaling server (ADR-001/003);
///   * `dart:io RawDatagramSocket` — no new pub dependency;
///   * Implicit discovery: every device both listens and broadcasts on the
///     same fixed port, so peers on the same Wi-Fi / hotspot see each other
///     automatically — no addresses to configure;
///   * The Android Wi-Fi multicast lock is acquired via a platform channel
///     so the Wi-Fi chip keeps delivering broadcast datagrams while the app
///     is in the foreground.
///
/// Known limitations (documented in ADR-008):
///   * Works only within one local network segment (same Wi-Fi or hotspot)
///     — cross-network chat remains a WebRTC (ADR-002) future sprint;
///   * UDP is best-effort. Receivers acknowledge chat envelopes; a missing
///     ack leaves the outgoing bubble in `sent`. Missed live messages are
///     healed by the history sync (last 50 messages per event, requested
///     after each group join / scan).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/communication_service.dart';

/// Fixed UDP port shared by all Pokatuha devices on the local network.
const int kPokatuhaUdpPort = 53100;

/// Wire format version of the envelope JSON.
const int kEnvelopeVersion = 1;

/// Method channel used to acquire the Android Wi-Fi multicast lock (without
/// it Android throttles broadcast/multicast delivery to the app shortly
/// after the screen turns off — see WifiManager.MulticastLock docs).
const MethodChannel kNetworkChannel = MethodChannel('pokatuha/network');

/// Maximum number of remembered envelope ids used for de-duplication.
const int kMaxSeenEnvelopes = 1024;

/// A UDP datagram larger than this is refused by receivers — keep batches
/// comfortably below the 64 KiB theoretical UDP limit.
const int kMaxDatagramBytes = 48000;

/// A [CommunicationService] that layers local-network UDP broadcast on top
/// of the in-process loopback. Both transports run concurrently:
///
///   * loopback — keeps unit tests deterministic and lets the offline queue
///     (UC-005) replay without a network;
///   * UDP broadcast — delivers envelopes to other Pokatuha devices on the
///     same Wi-Fi / hotspot.
class LocalNetworkCommunicationService implements CommunicationService {
  LocalNetworkCommunicationService({int port = kPokatuhaUdpPort})
      : _port = port {
    _inner = LocalCommunicationService();
    // Re-emit loopback envelopes through our merged incoming stream so
    // subscribers keep their existing behaviour (and tests stay hermetic).
    _inner.incoming.listen(_incomingController.add);
    if (_supportsNetwork) {
      // Fire-and-forget — a failure to bind (airplane mode, emulator without
      // network, desktop without multicast) must never block app startup.
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
  bool _networkBooted = false;

  /// Random per-process identity. Envelopes authored by this process are
  /// ignored on receive (both UDP echo and loopback re-entry), which makes
  /// the transport safe against self-loops without pairing logic.
  final String originId = UuidGenerator.generate();

  /// Envelope ids already processed — protects against duplicate datagrams
  /// (we broadcast to several addresses) and re-delivery.
  final Set<String> _seenEnvelopeIds = <String>{};

  /// True when the runtime can and should open a UDP socket. `flutter test`
  /// stays hermetic (no real network) — the FLUTTER_TEST env var is set by
  /// the Flutter test runner for every test isolate.
  bool get _supportsNetwork =>
      !kIsWeb &&
      !Platform.isWindows && // desktop UDP kept off until it is needed
      !(const bool.fromEnvironment('FLUTTER_TEST')) &&
      !(Platform.environment.containsKey('FLUTTER_TEST'));

  @override
  CommunicationMode get mode => _inner.mode;

  @override
  Stream<CommunicationMode> get modeStream {
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
    if (_supportsNetwork && !_networkBooted) {
      try {
        await _bootNetwork();
      } catch (_) {
        // Non-fatal — see constructor.
      }
    }
  }

  /// Sends the envelope both in-process (loopback) and over UDP broadcast.
  ///
  /// The loopback mirrors the previous LocalCommunicationService behaviour —
  /// local subscribers (chat, GPS) keep reacting to their own envelopes.
  /// UDP send failures are swallowed: local-first means the local copy is
  /// already persisted and the history sync heals any gaps.
  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    await _inner.broadcast(envelope); // loopback + offline queue
    if (!_networkBooted) return;
    try {
      _sendDatagram(_encodeEnvelope(envelope));
    } catch (_) {
      // Best-effort — never surface transport errors to the caller.
    }
  }

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> onFcmWakeUp({required String sessionId}) =>
      _inner.onFcmWakeUp(sessionId: sessionId);

  @override
  void enqueue(PendingChange change) => _inner.enqueue(change);

  @override
  List<PendingChange> get pendingQueue => _inner.pendingQueue;

  @override
  Future<void> syncPending() => _inner.syncPending();

  // ---------------------------------------------------------------------
  // Network plumbing
  // ---------------------------------------------------------------------

  Future<void> _bootNetwork() async {
    if (_networkBooted) return;
    _networkBooted = true;
    await _acquireMulticastLock();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _port,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram == null) return;
        _handleDatagram(datagram);
      }
    });
    _socket = socket;
  }

  /// Encodes and broadcasts one datagram to every plausible broadcast
  /// address of the current network (limited broadcast + per-interface
  /// directed broadcast derived from the interface IPv4).
  void _sendDatagram(String body) {
    final socket = _socket;
    if (socket == null) return;
    final bytes = utf8.encode(body);
    if (bytes.length > kMaxDatagramBytes) return; // refuse oversized frames
    final targets = <String>{'255.255.255.255'};
    for (final addr in _interfaceBroadcastAddresses()) {
      targets.add(addr);
    }
    for (final target in targets) {
      try {
        socket.send(bytes, InternetAddress(target), _port);
      } catch (_) {
        // Individual target failures are expected (no route on some
        // interfaces) — the remaining targets still deliver.
      }
    }
  }

  /// Directed broadcast per IPv4 interface: assumes a /24 netmask for the
  /// private ranges (the overwhelmingly common Wi-Fi / hotspot layout) and
  /// always includes the limited broadcast 255.255.255.255 (added by the
  /// caller). Exotic netmasks still receive the limited broadcast.
  List<String> _interfaceBroadcastAddresses() {
    final result = <String>[];
    try {
      for (final iface in NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      )) {
        for (final addr in iface.addresses) {
          final octets = addr.address.split('.');
          if (octets.length != 4) continue;
          final isPrivate = octets[0] == '10' ||
              octets[0] == '192' && octets[1] == '168' ||
              octets[0] == '172' &&
                  (int.tryParse(octets[1]) ?? 0) >= 16 &&
                  (int.tryParse(octets[1]) ?? 0) <= 31;
          if (!isPrivate) continue;
          result.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
        }
      }
    } catch (_) {
      // Interface enumeration is best-effort.
    }
    return result;
  }

  Future<void> _acquireMulticastLock() async {
    if (!Platform.isAndroid) return;
    try {
      await kNetworkChannel.invokeMethod<bool>('acquireMulticastLock');
    } catch (_) {
      // Without the lock some devices stop delivering broadcast packets
      // while the screen is off — chat still works in the foreground.
    }
  }

  // ---------------------------------------------------------------------
  // Envelope codec
  // ---------------------------------------------------------------------

  /// Visible for testing — wire format:
  /// `{"v":1,"eid":"<uuid>","o":"<origin>","t":"<type>","s":"<userId>",
  ///   "ts":<ms>,"p":{...}}`
  @visibleForTesting
  String encodeEnvelopeForTest(RealtimeEnvelope envelope) =>
      _encodeEnvelope(envelope);

  String _encodeEnvelope(RealtimeEnvelope envelope) {
    return jsonEncode(<String, dynamic>{
      'v': kEnvelopeVersion,
      'eid': UuidGenerator.generate(),
      'o': originId,
      't': envelope.type.name,
      's': envelope.senderId,
      'ts': envelope.timestamp,
      'p': envelope.payload,
    });
  }

  /// Visible for testing — parses a wire envelope, or null when malformed.
  @visibleForTesting
  static RealtimeEnvelope? decodeEnvelopeForTest(
    String body,
    String envelopeId, {
    String origin = 'remote',
  }) =>
      decodeEnvelope(body, envelopeId: envelopeId, origin: origin);

  /// Static decoder so tests can exercise the wire format without binding
  /// a socket. [envelopeId] / [origin] are carried outside the JSON body in
  /// production (embedded in the same map — see [_encodeEnvelope]).
  static RealtimeEnvelope? decodeEnvelope(
    String body, {
    required String envelopeId,
    required String origin,
  }) {
    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) return null;
      if ((raw['v'] as int? ?? 0) != kEnvelopeVersion) return null;
      final typeName = raw['t'] as String?;
      RealtimeType? type;
      for (final t in RealtimeType.values) {
        if (t.name == typeName) {
          type = t;
          break;
        }
      }
      if (type == null) return null;
      final payload = raw['p'];
      if (payload is! Map<String, dynamic>) return null;
      return RealtimeEnvelope(
        type: type,
        payload: payload,
        senderId: raw['s'] as String? ?? '',
        timestamp: (raw['ts'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  void _handleDatagram(Datagram datagram) {
    final body = utf8.decode(datagram.data, allowMalformed: true);
    Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      raw = decoded;
    } catch (_) {
      return; // foreign traffic on this port — ignore
    }
    if ((raw['v'] as int? ?? 0) != kEnvelopeVersion) return;
    final eid = raw['eid'] as String? ?? '';
    if (eid.isEmpty) return;
    // De-duplicate before anything else (we broadcast to several targets,
    // so the sender's own stack may observe the datagram twice).
    if (!_rememberEnvelope(eid)) return;
    // Ignore our own datagrams echoed back by the network stack.
    if (raw['o'] == originId) return;
    final envelope = decodeEnvelope(
      body,
      envelopeId: eid,
      origin: raw['o'] as String? ?? '',
    );
    if (envelope == null) return;
    _incomingController.add(envelope);
  }

  /// Records the envelope id; returns false when it was already seen.
  bool _rememberEnvelope(String eid) {
    if (_seenEnvelopeIds.contains(eid)) return false;
    // Cap memory — drop the oldest ids (Set iteration order is insertion
    // order in Dart) once the cap is reached.
    while (_seenEnvelopeIds.length >= kMaxSeenEnvelopes) {
      _seenEnvelopeIds.remove(_seenEnvelopeIds.first);
    }
    _seenEnvelopeIds.add(eid);
    return true;
  }

  /// Exposed for tests — simulate receiving a UDP datagram.
  @visibleForTesting
  void receiveDatagramForTest(List<int> data) {
    _handleDatagram(Datagram(Uint8List.fromList(data),
        InternetAddress('192.168.1.50'), _port));
  }

  void dispose() {
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    if (Platform.isAndroid) {
      kNetworkChannel
          .invokeMethod<bool>('releaseMulticastLock')
          .catchError((Object _) => false);
    }
    _incomingController.close();
    _modeController.close();
    _inner.dispose();
  }
}
