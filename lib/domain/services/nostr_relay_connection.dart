/// NOSTR relay transport (V3.0.9 — ADR-010).
///
/// Second internet relay leg next to the MQTT relay (ADR-009). Envelopes
/// are published as EPHEMERAL NOSTR events (kind 20001) tagged with the
/// same relay topic id the MQTT leg uses, so both transports share the
/// routing (topic derivation), the end-to-end seal (relay_codec) and the
/// idempotent ingest layer (HybridCommunicationService).
///
/// Why NOSTR: no account, no provider relationship, no server of our own —
/// just a handful of independent community relays speaking a trivial
/// websocket JSON protocol. Privacy properties:
///   * the signing keypair is RANDOM PER APP RUN and never persisted — it
///     carries zero identity; it exists only because relays reject
///     unsigned events (NIP-01);
///   * the event content is the AES-GCM seal from relay_codec (ADR-009) —
///     relays see ciphertext, random UUIDs and a hashed topic tag only;
///   * ephemeral kinds are not retained by relays, so — exactly like the
///     MQTT leg — delivery is best-effort and missed messages are healed
///     by the peer-to-peer history sync when a peer with the message is
///     reachable.
///
/// The protocol surface implemented here is minimal by design:
///   `["EVENT", event]` to publish, `["REQ", subId, filter]` to subscribe;
///   the subscription id IS the topic string, so incoming
///   `["EVENT", subId, event]` frames map straight back to (topic, body).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bip340/bip340.dart' as bip340;
import 'package:cryptography/cryptography.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:pokatuha/domain/services/relay_connection.dart';

/// Public NOSTR relays accepting ephemeral events, connected in parallel.
/// Any single healthy relay is enough for delivery; publishing goes to
/// every connected relay and receiving merges them all (cross-transport
/// de-duplication happens one layer up, in HybridCommunicationService).
const List<String> kNostrRelayUrls = <String>[
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://nostr.mom',
];

/// Ephemeral event kind (NIP-01: 20000–29999 are not retained by relays),
/// mirroring the MQTT leg's connected-subscribers-only semantics.
const int kNostrEphemeralKind = 20001;

/// Tag key used for topic routing.
const String kNostrTopicTag = 't';

/// WebSocket handshake timeout per relay.
const Duration kNostrConnectTimeout = Duration(seconds: 6);

/// Reconnect cadence for relays that dropped or never opened.
const Duration kNostrReconnectInterval = Duration(seconds: 15);

/// Order of the secp256k1 curve — a BIP-340 private key must be in
/// [1, n-1]. Random 32-byte strings violate this with probability ~2^-128,
/// but the check is cheap and keeps the generator total.
const String _kSecp256k1NHex =
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141';

final Sha256 _sha256 = Sha256();

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// A secp256k1 keypair in BIP-340 hex encoding (32-byte lowercase hex).
class NostrKeyPair {
  const NostrKeyPair({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;
}

/// Generates a random ephemeral keypair. NEVER persisted — the identity
/// carries zero meaning (see ADR-010); each app run signs with a fresh key.
NostrKeyPair generateNostrKeyPair([Random? rng]) {
  final n = BigInt.parse(_kSecp256k1NHex, radix: 16);
  final random = rng ?? Random.secure();
  while (true) {
    final bytes =
        List<int>.generate(32, (_) => random.nextInt(256));
    final d = BigInt.parse(_bytesToHex(bytes), radix: 16);
    if (d == BigInt.zero || d >= n) continue;
    final privateKey = _bytesToHex(bytes);
    return NostrKeyPair(
      privateKey: privateKey,
      publicKey: bip340.getPublicKey(privateKey),
    );
  }
}

/// Builds a signed NOSTR event (NIP-01) carrying [content] under the
/// [topic] `t`-tag. Pure function — unit-testable and reusable from the
/// keep-alive task isolate (no Flutter imports here).
Future<Map<String, dynamic>> buildNostrEvent({
  required NostrKeyPair keyPair,
  required String topic,
  required String content,
  int kind = kNostrEphemeralKind,
  int? createdAt,
  List<int>? auxBytes,
}) async {
  final tags = <List<String>>[
    <String>[kNostrTopicTag, topic],
  ];
  final ts = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  // NIP-01 id serialization: [0, created_at, kind, tags, content] with no
  // whitespace (jsonEncode of a List is already compact).
  final serialized = jsonEncode(<dynamic>[0, ts, kind, tags, content]);
  final digest = await _sha256.hash(utf8.encode(serialized));
  final id = _bytesToHex(digest.bytes);
  final aux = _bytesToHex(auxBytes ??
      List<int>.generate(32, (_) => Random.secure().nextInt(256)));
  final sig = bip340.sign(keyPair.privateKey, id, aux);
  return <String, dynamic>{
    'id': id,
    'pubkey': keyPair.publicKey,
    'created_at': ts,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': sig,
  };
}

/// Parses one relay websocket frame. Returns (topic, content) for EVENT
/// frames routed to one of [expectedTopics] (our subscription id IS the
/// topic string), null for everything else — OK / NOTICE / CLOSED / EOSE
/// replies and foreign or malformed events are ignored. Pure function.
({String topic, String content})? parseNostrEventMessage(
  dynamic data,
  Set<String> expectedTopics,
) {
  if (data is! List || data.length < 3) return null;
  if (data[0] != 'EVENT') return null;
  final subId = data[1];
  final event = data[2];
  if (subId is! String || event is! Map) return null;
  if (!expectedTopics.contains(subId)) return null;
  final content = event['content'];
  if (content is! String || content.isEmpty) return null;
  return (topic: subId, content: content);
}

/// A [RelayConnection] that publishes / receives sealed envelopes over
/// public NOSTR relays (ADR-010). All relays are connected in parallel;
/// the connection reports healthy while at least one relay is up and
/// silently re-connects dropped relays on a fixed cadence. Like the MQTT
/// leg, every method is failure-tolerant — the relay transport must never
/// break local-first operation (ADR-001).
class NostrRelayConnection implements RelayConnection {
  NostrRelayConnection({
    this.relayUrls = kNostrRelayUrls,
    this.kind = kNostrEphemeralKind,
    this.connectTimeout = kNostrConnectTimeout,
    this.reconnectInterval = kNostrReconnectInterval,
    NostrKeyPair? keyPair,
    Random? rng,
  })  : keyPair = keyPair ?? generateNostrKeyPair(rng),
        _rng = rng;

  @override
  RelayMessageHandler? onMessage;

  final List<String> relayUrls;
  final int kind;
  final Duration connectTimeout;
  final Duration reconnectInterval;

  /// Ephemeral per-run signing keypair (never persisted).
  final NostrKeyPair keyPair;
  final Random? _rng;

  /// url → open channel. A missing entry means the relay is down.
  final Map<String, WebSocketChannel> _channels =
      <String, WebSocketChannel>{};

  /// Topics that must be subscribed on every (re)connected relay.
  final Set<String> _topics = <String>{};

  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _started = false;

  @override
  bool get isConnected => _channels.isNotEmpty;

  @override
  Future<bool> connect() async {
    _started = true;
    if (_connecting) return isConnected;
    _connecting = true;
    try {
      var any = isConnected;
      for (final url in relayUrls) {
        if (_channels.containsKey(url)) continue;
        if (await _connectOne(url)) any = true;
      }
      _ensureReconnectTimer();
      return any;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _connectOne(String url) async {
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(connectTimeout);
    } catch (_) {
      try {
        channel?.sink.close();
      } catch (_) {}
      return false;
    }
    _channels[url] = channel;
    channel.stream.listen(
      _handleFrame,
      onError: (Object _) => _markDown(url),
      onDone: () => _markDown(url),
      cancelOnError: true,
    );
    for (final topic in _topics) {
      _sendReq(channel, topic);
    }
    return true;
  }

  void _handleFrame(dynamic data) {
    if (data is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return; // malformed foreign traffic — ignore
    }
    final parsed = parseNostrEventMessage(decoded, _topics);
    if (parsed == null) return;
    onMessage?.call(parsed.topic, parsed.content);
  }

  void _markDown(String url) {
    _channels.remove(url);
  }

  void _ensureReconnectTimer() {
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer.periodic(reconnectInterval, (_) {
      if (!_started || _connecting) return;
      if (_channels.length >= relayUrls.length) return;
      unawaited(connect());
    });
  }

  void _sendReq(WebSocketChannel channel, String topic) {
    try {
      channel.sink.add(jsonEncode(<dynamic>[
        'REQ',
        topic,
        <String, dynamic>{
          'kinds': <int>[kind],
          '#$kNostrTopicTag': <String>[topic],
        },
      ]));
    } catch (_) {}
  }

  @override
  Future<void> subscribe(String topic) async {
    _topics.add(topic);
    for (final channel in _channels.values) {
      _sendReq(channel, topic);
    }
  }

  @override
  Future<void> publish(String topic, String body) async {
    if (_channels.isEmpty) return;
    final Map<String, dynamic> event;
    try {
      final rng = _rng;
      event = await buildNostrEvent(
        keyPair: keyPair,
        topic: topic,
        content: body,
        kind: kind,
        auxBytes: rng == null
            ? null
            : List<int>.generate(32, (_) => rng.nextInt(256)),
      );
    } catch (_) {
      return; // signing must never crash the caller — best-effort
    }
    final wire = jsonEncode(<dynamic>['EVENT', event]);
    for (final channel in _channels.values) {
      try {
        channel.sink.add(wire);
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final channels = List<WebSocketChannel>.of(_channels.values);
    _channels.clear();
    for (final channel in channels) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }
}
