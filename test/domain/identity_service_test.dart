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
}
