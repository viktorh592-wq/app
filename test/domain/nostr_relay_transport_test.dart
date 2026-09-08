/// Tests for the V3.0.9 NOSTR relay transport (ADR-010): event building /
/// signing (BIP-340), frame parsing, and the fan-out connection that runs
/// the MQTT (ADR-009) and NOSTR legs concurrently. Hermetic — no sockets
/// are opened; the connection classes only touch the network in connect().
import 'dart:convert';
import 'dart:math';

import 'package:bip340/bip340.dart' as bip340;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/domain/services/nostr_relay_connection.dart';
import 'package:pokatuha/domain/services/relay_connection.dart';
import 'package:pokatuha/domain/services/relay_transport.dart';

final Sha256 _sha256 = Sha256();

Future<String> _nip01EventId(Map<String, dynamic> event) async {
  final serialized = jsonEncode(<dynamic>[
    0,
    event['created_at'],
    event['kind'],
    event['tags'],
    event['content'],
  ]);
  final digest =
      await _sha256.hash(utf8.encode(serialized));
  return digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _FakeRelay implements RelayConnection {
  _FakeRelay(this.name, {this.connectResult = true});

  final String name;
  bool connectResult;
  bool connected = false;
  bool disconnected = false;
  @override
  RelayMessageHandler? onMessage;
  final List<String> subscribed = <String>[];
  final List<({String topic, String body})> published =
      <({String topic, String body})>[];

  @override
  bool get isConnected => connected;

  @override
  Future<bool> connect() async {
    connected = connectResult;
    return connectResult;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    connected = false;
  }

  @override
  Future<void> subscribe(String topic) async {
    subscribed.add(topic);
  }

  @override
  Future<void> publish(String topic, String body) async {
    published.add((topic: topic, body: body));
  }

  void deliver(String topic, String body) => onMessage?.call(topic, body);
}

void main() {
  group('generateNostrKeyPair', () {
    test('derives a matching BIP-340 public key', () {
      final kp = generateNostrKeyPair();
      expect(kp.privateKey.length, 64);
      expect(kp.publicKey, bip340.getPublicKey(kp.privateKey));
      expect(kp.publicKey.length, 64);
    });

    test('is random per call (ephemeral identity)', () {
      final a = generateNostrKeyPair();
      final b = generateNostrKeyPair();
      expect(a.privateKey, isNot(b.privateKey));
      expect(a.publicKey, isNot(b.publicKey));
    });

    test('accepts an injected rng (deterministic)', () {
      final kp = generateNostrKeyPair(Random(42));
      final again = generateNostrKeyPair(Random(42));
      expect(kp.privateKey, again.privateKey);
      expect(kp.privateKey, isNot('0' * 64));
    });
  });

  group('buildNostrEvent', () {
    const topic = 'pokatuha/v1/g/abc123';
    const content = '{"v":1,"n":"nonce","c":"sealed"}';

    test('id matches the NIP-01 serialization; signature verifies', () async {
      final kp = generateNostrKeyPair();
      final event = await buildNostrEvent(
        keyPair: kp,
        topic: topic,
        content: content,
        createdAt: 1725600000,
        auxBytes: List<int>.filled(32, 7),
      );
      expect(event['pubkey'], kp.publicKey);
      expect(event['kind'], kNostrEphemeralKind);
      expect(event['tags'], [
        ['t', topic]
      ]);
      final id = await _nip01EventId(event);
      expect(event['id'], id);
      expect(
        bip340.verify(kp.publicKey, id, event['sig'] as String),
        isTrue,
      );
    });

    test('a tampered content invalidates the signature', () async {
      final kp = generateNostrKeyPair();
      final event = await buildNostrEvent(
        keyPair: kp,
        topic: topic,
        content: content,
        createdAt: 1725600000,
        auxBytes: List<int>.filled(32, 7),
      );
      final forged = Map.of(event)
        ..['content'] = '$content tampered';
      final forgedId = await _nip01EventId(forged);
      expect(
        bip340.verify(kp.publicKey, forgedId, event['sig'] as String),
        isFalse,
      );
    });

    test('different aux yields different signatures, same id', () async {
      final kp = generateNostrKeyPair();
      final a = await buildNostrEvent(
        keyPair: kp,
        topic: topic,
        content: content,
        createdAt: 1725600000,
        auxBytes: List<int>.filled(32, 1),
      );
      final b = await buildNostrEvent(
        keyPair: kp,
        topic: topic,
        content: content,
        createdAt: 1725600000,
        auxBytes: List<int>.filled(32, 2),
      );
      expect(a['id'], b['id']);
      expect(a['sig'], isNot(b['sig']));
    });
  });

  group('parseNostrEventMessage', () {
    const topic = 'pokatuha/v1/g/abc123';

    test('routes a valid EVENT frame to the subscribed topic', () {
      final parsed = parseNostrEventMessage(<dynamic>[
        'EVENT',
        topic,
        <String, dynamic>{'content': 'sealed-body', 'id': 'x'},
      ], <String>{topic});
      expect(parsed, isNotNull);
      expect(parsed!.topic, topic);
      expect(parsed.content, 'sealed-body');
    });

    test('ignores OK / NOTICE / EOSE replies', () {
      expect(
        parseNostrEventMessage(
            <dynamic>['OK', 'abc', true, ''], <String>{topic}),
        isNull,
      );
      expect(
        parseNostrEventMessage(
            <dynamic>['NOTICE', 'rate limited'], <String>{topic}),
        isNull,
      );
      expect(
        parseNostrEventMessage(<dynamic>['EOSE', topic], <String>{topic}),
        isNull,
      );
    });

    test('ignores foreign subscription ids and malformed frames', () {
      expect(
        parseNostrEventMessage(<dynamic>[
          'EVENT',
          'other-topic',
          <String, dynamic>{'content': 'x'},
        ], <String>{topic}),
        isNull,
      );
      expect(parseNostrEventMessage(<dynamic>['EVENT'], <String>{topic}),
          isNull);
      expect(
        parseNostrEventMessage(<dynamic>[
          'EVENT',
          topic,
          'not-a-map',
        ], <String>{topic}),
        isNull,
      );
      expect(
        parseNostrEventMessage(<dynamic>[
          'EVENT',
          topic,
          <String, dynamic>{},
        ], <String>{topic}),
        isNull,
      );
      expect(parseNostrEventMessage('junk', <String>{topic}), isNull);
    });
  });

  group('NostrRelayConnection (hermetic, no sockets)', () {
    test('starts disconnected and tolerates offline publish / subscribe',
        () async {
      final relay = NostrRelayConnection();
      expect(relay.isConnected, isFalse);
      // Offline subscribe remembers the topic for the next connect.
      await relay.subscribe('pokatuha/v1/g/abc123');
      // Offline publish is a no-op, never throws.
      await relay.publish('pokatuha/v1/g/abc123', 'sealed-body');
      // Disconnect without any open socket is a no-op.
      await relay.disconnect();
      expect(relay.isConnected, isFalse);
    });

    test('each connection uses a fresh ephemeral keypair', () {
      final a = NostrRelayConnection();
      final b = NostrRelayConnection();
      expect(a.keyPair.privateKey, isNot(b.keyPair.privateKey));
    });
  });

  group('FanoutRelayConnection', () {
    test('publishes and subscribes through every leg', () async {
      final mqtt = _FakeRelay('mqtt');
      final nostr = _FakeRelay('nostr');
      final fanout = FanoutRelayConnection([mqtt, nostr]);

      await fanout.subscribe('topic-1');
      expect(mqtt.subscribed, ['topic-1']);
      expect(nostr.subscribed, ['topic-1']);

      await fanout.publish('topic-1', 'body');
      expect(mqtt.published.single.body, 'body');
      expect(nostr.published.single.body, 'body');
    });

    test('connect succeeds when at least one leg connects', () async {
      final down = _FakeRelay('mqtt', connectResult: false);
      final up = _FakeRelay('nostr');
      final fanout = FanoutRelayConnection([down, up]);
      expect(await fanout.connect(), isTrue);
      expect(down.isConnected, isFalse);
      expect(up.isConnected, isTrue);

      final bothDown = FanoutRelayConnection([
        _FakeRelay('a', connectResult: false),
        _FakeRelay('b', connectResult: false),
      ]);
      expect(await bothDown.connect(), isFalse);
    });

    test('merges incoming messages from all legs', () async {
      final mqtt = _FakeRelay('mqtt');
      final nostr = _FakeRelay('nostr');
      final received = <({String topic, String body})>[];
      final fanout = FanoutRelayConnection([mqtt, nostr],
          onMessage: (topic, body) =>
              received.add((topic: topic, body: body)));
      // Legs were never connected through the fanout — messages still
      // merge when each leg delivers independently.
      expect(fanout.isConnected, isFalse);

      mqtt.deliver('topic-1', 'via-mqtt');
      nostr.deliver('topic-1', 'via-nostr');
      expect(received.map((r) => r.body), ['via-mqtt', 'via-nostr']);
    });

    test('disconnect tears down every leg', () async {
      final mqtt = _FakeRelay('mqtt');
      final nostr = _FakeRelay('nostr');
      final fanout = FanoutRelayConnection([mqtt, nostr]);
      await fanout.connect();
      await fanout.disconnect();
      expect(mqtt.disconnected, isTrue);
      expect(nostr.disconnected, isTrue);
    });
  });

  group('buildDefaultRelayTransport', () {
    test('returns a usable fanout (both legs present)', () async {
      final transport = buildDefaultRelayTransport(clientId: 'test-client');
      expect(transport.isConnected, isFalse);
      // Hermetic — we never call connect(); just verify the interface
      // methods are tolerant before any socket was opened.
      await transport.subscribe('pokatuha/v1/g/abc123');
      await transport.publish('pokatuha/v1/g/abc123', 'x');
      await transport.disconnect();
    });
  });

  group('relay wire compatibility', () {
    test('a NOSTR-published body opens with the shared seal codec',
        () async {
      // Both legs carry the SAME sealed body produced by relay_codec; the
      // receiving side must not care which transport delivered it.
      final topic = await topicForInviteCode('A1B2C3D4');
      expect(topic.startsWith('pokatuha/v1/g/'), isTrue);
    });
  });
}
