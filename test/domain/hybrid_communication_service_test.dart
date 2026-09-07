/// Tests for the V3.0.5 hybrid transport (bug 2 — chat over mobile
/// networks): relay publishing is type- and route-gated, relay arrivals
/// are decrypted and dispatched into the same incoming stream, and relay
/// re-deliveries are de-duplicated.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/hybrid_communication_service.dart';
import 'package:pokatuha/domain/services/relay_connection.dart';

class _FakeRelay implements RelayConnection {
  bool connected = true;
  @override
  RelayMessageHandler? onMessage;
  final List<({String topic, String body})> published =
      <({String topic, String body})>[];

  @override
  bool get isConnected => connected;

  @override
  Future<bool> connect() async => connected;

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> publish(String topic, String body) async {
    published.add((topic: topic, body: body));
  }

  /// Simulates the broker delivering a message to the subscriber.
  void deliver(String topic, String body) => onMessage?.call(topic, body);
}

RealtimeEnvelope _chatEnvelope({String text = 'привет по сети'}) {
  return RealtimeEnvelope(
    type: RealtimeType.chat,
    payload: <String, dynamic>{
      'id': UuidGenerator.generate(),
      'eventId': 'event-1',
      'authorId': 'alice',
      'kind': 'text',
      'text': text,
      'version': 1,
      'deliveryState': 'sending',
    },
    senderId: 'alice',
    timestamp: 1725600000000,
  );
}

void main() {
  const route = (groupId: 'group-1', inviteCode: 'A1B2C3D4');

  late HybridCommunicationService hybrid;
  late _FakeRelay relay;
  late String topic;

  setUp(() async {
    relay = _FakeRelay();
    hybrid = HybridCommunicationService(
      resolveRoute: (_) async => route,
      currentRoutes: () async => [route],
      relayConnection: relay,
    );
    topic = await topicForInviteCode(route.inviteCode);
    await hybrid.syncSubscriptions();
  });

  test('chat envelopes are relayed as an encrypted seal', () async {
    final envelope = _chatEnvelope();
    await hybrid.broadcast(envelope);

    expect(relay.published, hasLength(1));
    final body = relay.published.single.body;
    expect(body.contains('привет по сети'), isFalse,
        reason: 'relay body must be sealed');
    expect(relay.published.single.topic, topic);

    // The seal opens back to the exact wire envelope.
    final opened = await openSeal(
      relayJson: body,
      groupId: route.groupId,
      inviteCode: route.inviteCode,
    );
    expect(opened, isNotNull);
    final raw = jsonDecode(opened!) as Map<String, dynamic>;
    expect(raw['t'], 'chat');
    expect((raw['p'] as Map)['text'], 'привет по сети');
  });

  test('non-relayable types (gps/presence) never reach the broker',
      () async {
    await hybrid.broadcast(RealtimeEnvelope(
      type: RealtimeType.gps,
      payload: <String, dynamic>{'lat': 55.0, 'lng': 37.0},
      senderId: 'alice',
      timestamp: 1725600000000,
    ));
    expect(relay.published, isEmpty);
  });

  test('envelopes without a resolvable route are not relayed', () async {
    final noRoute = HybridCommunicationService(
      resolveRoute: (_) async => null,
      currentRoutes: () async => [],
      relayConnection: relay,
    );
    await noRoute.broadcast(_chatEnvelope());
    expect(relay.published, isEmpty);
    noRoute.dispose();
  });

  test('relay arrivals are decrypted and dispatched on incoming',
      () async {
    final received = <RealtimeEnvelope>[];
    final sub = hybrid.incoming.listen(received.add);

    final envelope = _chatEnvelope(text: 'через релей');
    // Seal exactly like the SENDER's hybrid service would.
    final sealed = (await sealEnvelope(
      envelopeJson: LocalNetworkCodecHelper.encode(
        envelope,
        originId: 'peer-origin',
      ),
      groupId: route.groupId,
      inviteCode: route.inviteCode,
    ))!;
    relay.deliver(topic, sealed);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(received.where((e) => e.payload['text'] == 'через релей'),
        hasLength(1));
    await sub.cancel();
  });

  test('relay re-delivery (QoS 1) is de-duplicated', () async {
    final received = <RealtimeEnvelope>[];
    final sub = hybrid.incoming.listen(received.add);

    final envelope = _chatEnvelope(text: 'dup-relay');
    final sealed = (await sealEnvelope(
      envelopeJson: LocalNetworkCodecHelper.encode(
        envelope,
        originId: 'peer-origin',
      ),
      groupId: route.groupId,
      inviteCode: route.inviteCode,
    ))!;
    relay.deliver(topic, sealed);
    relay.deliver(topic, sealed); // QoS-1 re-delivery
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(received.where((e) => e.payload['text'] == 'dup-relay'),
        hasLength(1));
    await sub.cancel();
  });

  test('seals for a foreign group are rejected (topic isolation)',
      () async {
    final received = <RealtimeEnvelope>[];
    final sub = hybrid.incoming.listen(received.add);

    final sealed = (await sealEnvelope(
      envelopeJson: LocalNetworkCodecHelper.encode(
        _chatEnvelope(text: 'foreign'),
        originId: 'peer-origin',
      ),
      groupId: 'some-other-group',
      inviteCode: route.inviteCode,
    ))!;
    relay.deliver(topic, sealed);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(received.where((e) => e.payload['text'] == 'foreign'), isEmpty);
    await sub.cancel();
  });
}

/// Small helper that produces wire-format envelopes for tests without
/// exposing production internals.
class LocalNetworkCodecHelper {
  static String encode(RealtimeEnvelope envelope, {required String originId}) {
    return jsonEncode(<String, dynamic>{
      'v': 1,
      'eid': UuidGenerator.generate(),
      'o': originId,
      't': envelope.type.name,
      's': envelope.senderId,
      'ts': envelope.timestamp,
      'p': envelope.payload,
    });
  }
}
