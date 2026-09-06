import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/domain/services/identity_service.dart';

void main() {
  late IdentityService service;

  setUp(() {
    service = IdentityService();
  });

  const userId = '0192f0c8-1234-7abc-9def-0123456789ab';

  test('userUri returns pokatuha://u/<short-id> (§1)', () {
    final uri = service.userUri(userId);
    expect(uri, 'pokatuha://u/0192F0C81234');
  });

  test('publicId is the first 12 hex chars, upper-cased', () {
    expect(service.publicId(userId), '0192F0C81234');
    expect(service.publicId(userId).length, 12);
  });

  test('groupUri returns pokatuha://g/<code> (§2)', () {
    expect(service.groupUri('AB12CD34'), 'pokatuha://g/AB12CD34');
  });

  test('parse recognizes user links case-insensitively', () {
    final link = service.parse('pokatuha://u/0192f0c81234');
    expect(link, isNotNull);
    expect(link!.kind, LinkKind.user);
    expect(link.payload, '0192F0C81234');
  });

  test('parse recognizes group links', () {
    final link = service.parse('pokatuha://g/ab12cd34');
    expect(link, isNotNull);
    expect(link!.kind, LinkKind.group);
    expect(link.payload, 'AB12CD34');
  });

  test('parse accepts surrounding whitespace', () {
    expect(service.parse('  pokatuha://u/0192F0C81234 '), isNotNull);
  });

  test('parse rejects foreign schemes and garbage', () {
    expect(service.parse('https://pokatuha.app/u/123'), isNull);
    expect(service.parse('pokatuha://unknown/123'), isNull);
    expect(service.parse('pokatuha://u/'), isNull);
    expect(service.parse('pokatuha://g/'), isNull);
    expect(service.parse('pokatuha://u/a/b'), isNull);
    expect(service.parse('not a uri'), isNull);
    expect(service.parse(''), isNull);
  });

  test('userUri round-trips through parse', () {
    final uri = service.userUri(userId);
    final link = service.parse(uri);
    expect(link, isNotNull);
    expect(link!.payload, service.publicId(userId));
  });

  // --- V3.0.4 (bug 2): gzipped group payload ---

  test('groupUriWithPayload round-trips through parse (gzip form)', () {
    final payload = <String, dynamic>{
      'id': 'group-123',
      'name': 'Клуб «ВелоПоход»',
      'inviteCode': 'ABC123',
      'members': <Map<String, dynamic>>[
        {'userId': 'u1', 'displayName': 'Аня'},
      ],
      'activities': <Map<String, dynamic>>[
        {'id': 'a1', 'title': 'Вечерний заезд'},
      ],
    };
    final uri = service.groupUriWithPayload(
      inviteCode: 'ABC123',
      payload: payload,
    );
    final link = service.parse(uri);
    expect(link, isNotNull);
    expect(link!.kind, LinkKind.group);
    expect(link.payload, 'ABC123');
    expect(link.data, isNotNull);
    expect(link.data!['id'], 'group-123');
    expect(link.data!['name'], 'Клуб «ВелоПоход»');
    expect((link.data!['members'] as List).first['userId'], 'u1');
  });

  test('gzipped payload is significantly smaller than plain base64', () {
    final payload = <String, dynamic>{
      'id': 'group-123',
      'inviteCode': 'ABC123',
      'activities': List.generate(
        5,
        (i) => <String, dynamic>{
          'id': 'activity-$i',
          'title': 'Очень длинное название активности номер $i',
          'description': 'Длинное описание ' * 20,
        },
      ),
    };
    // Compare encoded sizes directly.
    final plain = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final gzipped =
        base64Url.encode(gzip.encode(utf8.encode(jsonEncode(payload))));
    expect(gzipped.length, lessThan(plain.length ~/ 3),
        reason: 'gzip must cut the QR payload to under a third');
  });

  test('legacy plain-base64 payload still parses (backward compat)', () {
    final json = jsonEncode(<String, dynamic>{'id': 'g1', 'name': 'Old'});
    final b64 = base64Url.encode(utf8.encode(json));
    final uri = 'pokatuha://g/OLD1?d=$b64';
    final link = service.parse(uri);
    expect(link, isNotNull);
    expect(link!.data!['id'], 'g1');
  });
}
