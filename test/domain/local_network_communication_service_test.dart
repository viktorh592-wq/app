/// Unit tests for the local-network UDP transport wire format (V3.0.4).
/// The socket is never booted under `flutter test` (FLUTTER_TEST), so the
/// suite exercises the codec and the filter logic deterministically.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';

void main() {
  test('envelope roundtrip keeps type, payload, sender and timestamp',
      () async {
    final service = LocalNetworkCommunicationService();
    final envelope = RealtimeEnvelope(
      type: RealtimeType.chat,
      payload: <String, dynamic>{'id': 'm1', 'text': 'hello'},
      senderId: 'alice',
      timestamp: 1725600000000,
    );
    final wire = service.encodeEnvelopeForTest(envelope);
    final decoded = LocalNetworkCommunicationService.decodeEnvelope(
      wire,
      envelopeId: 'eid-1',
      origin: 'remote-device',
    );
    expect(decoded, isNotNull);
    expect(decoded!.type, RealtimeType.chat);
    expect(decoded.payload['text'], 'hello');
    expect(decoded.senderId, 'alice');
    expect(decoded.timestamp, 1725600000000);
    service.dispose();
  });

  test('new history/ack types survive the codec', () {
    final service = LocalNetworkCommunicationService();
    for (final type in {
      RealtimeType.chatAck,
      RealtimeType.chatHistoryRequest,
      RealtimeType.chatHistoryBatch,
    }) {
      final wire = service.encodeEnvelopeForTest(RealtimeEnvelope(
        type: type,
        payload: <String, dynamic>{'groupId': 'g1'},
        senderId: 'alice',
        timestamp: 1,
      ));
      final decoded = LocalNetworkCommunicationService.decodeEnvelope(
        wire,
        envelopeId: 'eid',
        origin: 'remote',
      );
      expect(decoded!.type, type);
    }
    service.dispose();
  });

  test('malformed and foreign envelopes are rejected', () {
    expect(
      LocalNetworkCommunicationService.decodeEnvelope(
        'not json at all',
        envelopeId: 'e',
        origin: 'o',
      ),
      isNull,
    );
    expect(
      // Valid JSON, wrong version.
      LocalNetworkCommunicationService.decodeEnvelope(
        jsonEncode(<String, dynamic>{'v': 99, 't': 'chat', 'p': <String, dynamic>{}}),
        envelopeId: 'e',
        origin: 'o',
      ),
      isNull,
    );
    expect(
      // Valid JSON, unknown type.
      LocalNetworkCommunicationService.decodeEnvelope(
        jsonEncode(<String, dynamic>{
          'v': 1,
          't': 'unknownType',
          'p': <String, dynamic>{},
        }),
        envelopeId: 'e',
        origin: 'o',
      ),
      isNull,
    );
  });

  test('receive path filters duplicates and self-originated datagrams',
      () async {
    final service = LocalNetworkCommunicationService();
    final received = <RealtimeEnvelope>[];
    final sub = service.incoming.listen(received.add);

    final body = jsonEncode(<String, dynamic>{
      'v': kEnvelopeVersion,
      'eid': UuidGenerator.generate(),
      'o': 'remote-origin',
      't': 'chat',
      's': 'alice',
      'ts': 1,
      'p': <String, dynamic>{'id': 'm1', 'text': 'hi'},
    });

    // The same datagram delivered twice (multi-target broadcast echo) ...
    service.receiveDatagramForTest(utf8.encode(body));
    service.receiveDatagramForTest(utf8.encode(body));
    // ... and our own envelope bounced back by the network.
    final selfBody = jsonEncode(<String, dynamic>{
      'v': kEnvelopeVersion,
      'eid': UuidGenerator.generate(),
      'o': service.originId,
      't': 'chat',
      's': 'me',
      'ts': 1,
      'p': <String, dynamic>{'id': 'm2'},
    });
    service.receiveDatagramForTest(utf8.encode(selfBody));

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received, hasLength(1), reason: 'duplicate + self must be dropped');
    expect(received.first.senderId, 'alice');
    await sub.cancel();
    service.dispose();
  });
}
