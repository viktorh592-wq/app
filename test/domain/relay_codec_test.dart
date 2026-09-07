/// Tests for the V3.0.5 relay codec (bug 2 — chat over mobile networks).
/// The broker is untrusted, so the suite focuses on the end-to-end
/// encryption properties: deterministic key/topic derivation, round-trip,
/// wrong-key rejection and tamper detection.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/domain/services/relay_codec.dart';

void main() {
  const groupId = '0a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d';
  const inviteCode = 'A1B2C3D4';
  const envelopeJson =
      '{"v":1,"eid":"env-1","o":"origin-1","t":"chat","s":"alice",'
      '"ts":1725600000000,"p":{"id":"m-1","eventId":"e-1","text":"Привет"}}';

  test('topic derivation is deterministic and does not leak the code',
      () async {
    final a = await topicForInviteCode(inviteCode);
    final b = await topicForInviteCode('a1b2c3d4'); // case-insensitive
    expect(a, b);
    expect(a, startsWith('pokatuha/v1/g/'));
    expect(a.contains(inviteCode), isFalse,
        reason: 'the raw invite code must not appear in the topic');
    expect(a.length, 'pokatuha/v1/g/'.length + 20);
  });

  test('key derivation is deterministic and code-normalized', () async {
    final a = await deriveRelayKey(groupId: groupId, inviteCode: inviteCode);
    final b = await deriveRelayKey(
        groupId: groupId, inviteCode: ' a1b2c3d4 '.toUpperCase());
    expect(a, b);
    expect(a.length, 32, reason: 'AES-256 key');
  });

  test('seal → open round-trip restores the envelope JSON', () async {
    final sealed = await sealEnvelope(
      envelopeJson: envelopeJson,
      groupId: groupId,
      inviteCode: inviteCode,
    );
    expect(sealed, isNotNull);
    expect(sealed!.contains('Привет'), isFalse,
        reason: 'plaintext must never appear in the relay body');

    final opened = await openSeal(
      relayJson: sealed,
      groupId: groupId,
      inviteCode: inviteCode,
    );
    expect(opened, envelopeJson);
  });

  test('a different group cannot open the seal (wrong key)', () async {
    final sealed = await sealEnvelope(
      envelopeJson: envelopeJson,
      groupId: groupId,
      inviteCode: inviteCode,
    );
    final opened = await openSeal(
      relayJson: sealed!,
      groupId: 'another-group-uuid-entirely',
      inviteCode: inviteCode,
    );
    expect(opened, isNull);
  });

  test('a different code cannot open the seal', () async {
    final sealed = await sealEnvelope(
      envelopeJson: envelopeJson,
      groupId: groupId,
      inviteCode: inviteCode,
    );
    final opened = await openSeal(
      relayJson: sealed!,
      groupId: groupId,
      inviteCode: 'FFFFFF00',
    );
    expect(opened, isNull);
  });

  test('tampered ciphertext fails authentication', () async {
    final sealed = (await sealEnvelope(
      envelopeJson: envelopeJson,
      groupId: groupId,
      inviteCode: inviteCode,
    ))!;
    final raw = jsonDecode(sealed) as Map<String, dynamic>;
    final cipherText = base64Url.decode(raw['c'] as String);
    cipherText[0] = cipherText[0] ^ 0x01;
    raw['c'] = base64Url.encode(cipherText);
    final opened = await openSeal(
      relayJson: jsonEncode(raw),
      groupId: groupId,
      inviteCode: inviteCode,
    );
    expect(opened, isNull);
  });

  test('malformed bodies open to null (never throw)', () async {
    expect(await openSeal(relayJson: 'not-json', groupId: groupId, inviteCode: inviteCode), isNull);
    expect(await openSeal(relayJson: '{}', groupId: groupId, inviteCode: inviteCode), isNull);
    expect(await openSeal(
        relayJson: jsonEncode({'v': 99, 'n': '', 'c': '', 't': ''}),
        groupId: groupId,
        inviteCode: inviteCode), isNull);
    expect(
        await sealEnvelope(
            envelopeJson: envelopeJson,
            groupId: '',
            inviteCode: ''), isNotNull,
        reason: 'sealing never throws even for degenerate input');
  });
}
