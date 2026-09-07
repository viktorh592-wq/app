/// Relay wire codec (V3.0.5 — user-reported bug 2: chat must work over
/// mobile networks, ADR-009).
///
/// The LAN UDP transport (ADR-008) is confined to one network segment. To
/// reach a peer over the internet, envelopes are relayed through a public
/// MQTT broker. The broker is UNTRUSTED infrastructure, so every relayed
/// envelope is end-to-end encrypted before it ever touches the network:
///
///   * Key derivation (both sides know the group invite code + id from the
///     QR payload):
///         key  = SHA-256("pokatuha-relay-v1|gid=`groupId`|code=`CODE`")
///         aad  = "pokatuha-relay-v1|gid=`groupId`"   (integrity binding)
///   * Cipher: AES-GCM-256 (128-bit tag, random 96-bit nonce per message).
///   * Topic (route discovery): SHA-256 over the code only —
///         topic = "pokatuha/v1/g/" + hex(SHA-256("pokatuha-relay-topic-v1|`CODE`"))[:20]
///     A passive observer who guesses the topic (the invite code has ~32
///     bits of entropy — see ADR-009) still cannot read anything: the
///     decryption key additionally requires the 122-bit group UUID.
///
/// The codec is pure Dart — it also runs inside the keep-alive task
/// isolate, which has no access to the database.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Wire format version of the relay seal.
const int kRelaySealVersion = 1;

/// Topic namespace of the relay (v1).
const String kRelayTopicPrefix = 'pokatuha/v1/g/';

final AesGcm _aesGcm = AesGcm.with256bits();

String _normalizeCode(String inviteCode) => inviteCode.trim().toUpperCase();

Future<List<int>> _sha256(List<int> input) async =>
    (await Sha256().hash(input)).bytes;

/// Topic a group's envelopes are published to / subscribed on.
Future<String> topicForInviteCode(String inviteCode) async {
  final digest = await _sha256(
      utf8.encode('pokatuha-relay-topic-v1|${_normalizeCode(inviteCode)}'));
  final hex =
      digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$kRelayTopicPrefix${hex.substring(0, 20)}';
}

/// Wraps an envelope JSON string into an encrypted relay body.
/// Returns the relay JSON map `{v, n, c, t}` (all binary fields base64Url) or
/// null when sealing failed (never throws — relay is best-effort).
Future<String?> sealEnvelope({
  required String envelopeJson,
  required String groupId,
  required String inviteCode,
}) async {
  try {
    final key = await deriveRelayKey(groupId: groupId, inviteCode: inviteCode);
    final aad = utf8.encode('pokatuha-relay-v1|gid=$groupId');
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(envelopeJson),
      secretKey: SecretKey(key),
      aad: aad,
    );
    return jsonEncode(<String, dynamic>{
      'v': kRelaySealVersion,
      'n': base64Url.encode(secretBox.nonce),
      'c': base64Url.encode(secretBox.cipherText),
      't': base64Url.encode(secretBox.mac.bytes),
    });
  } catch (_) {
    return null;
  }
}

/// Opens a relay body produced by [sealEnvelope]. Returns the original
/// envelope JSON string, or null when the seal is malformed, was produced
/// for another group, or fails authentication (wrong key / tampering).
Future<String?> openSeal({
  required String relayJson,
  required String groupId,
  required String inviteCode,
}) async {
  try {
    final raw = jsonDecode(relayJson);
    if (raw is! Map<String, dynamic>) return null;
    if ((raw['v'] as int? ?? 0) != kRelaySealVersion) return null;
    final nonce = base64Url.decode(raw['n'] as String? ?? '');
    final cipherText = base64Url.decode(raw['c'] as String? ?? '');
    final mac = base64Url.decode(raw['t'] as String? ?? '');
    if (nonce.isEmpty || cipherText.isEmpty) return null;
    final key = await deriveRelayKey(groupId: groupId, inviteCode: inviteCode);
    final aad = utf8.encode('pokatuha-relay-v1|gid=$groupId');
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );
    final clear = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return utf8.decode(clear);
  } catch (_) {
    return null;
  }
}

/// Shared key derivation — exposed for tests.
Future<List<int>> deriveRelayKey({
  required String groupId,
  required String inviteCode,
}) async {
  return _sha256(utf8.encode(
      'pokatuha-relay-v1|gid=$groupId|code=${_normalizeCode(inviteCode)}'));
}
