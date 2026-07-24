import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/utils/uuid.dart';

void main() {
  test('generates a valid UUID v7 string', () {
    final id = UuidGenerator.generate();
    expect(id.length, 36);
    expect(UuidGenerator.isValid(id), isTrue);
  });

  test('two generated ids are unique', () {
    expect(UuidGenerator.generate(), isNot(UuidGenerator.generate()));
  });

  test('rejects invalid uuids', () {
    expect(UuidGenerator.isValid('not-a-uuid'), isFalse);
    expect(UuidGenerator.isValid(''), isFalse);
  });

  test('v7 ids are chronologically sortable', () async {
    final a = UuidGenerator.generate();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = UuidGenerator.generate();
    expect(a.compareTo(b), lessThan(0));
  });
}
