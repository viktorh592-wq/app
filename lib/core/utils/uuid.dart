/// UUID policy — generate UUID Version 7 locally (UUID_Policy.md, Entity_Standards.md).
///
/// UUID v7 is chronologically sortable, globally unique and generated without
/// any central server, matching the Local-First architecture.
import 'package:uuid/uuid.dart';

class UuidGenerator {
  UuidGenerator._();

  static const _uuid = Uuid();

  /// Generate a new UUID v7 string.
  static String generate() => _uuid.v7();

  /// Validate that [value] looks like a UUID.
  static bool isValid(String value) {
    if (value.length != 36) return false;
    return Uuid.isValidUUID(fromString: value);
  }
}
