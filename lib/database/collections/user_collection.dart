/// User collection — local profile (Authentication is local, not Firebase).
import 'package:pokatuha/database/base_entity.dart';

class UserCollection extends BaseEntity {
  String username = '';
  String displayName = '';
  String? avatarPath;
  String? bio;

  /// Indexable field (Indexes.md — email future).
  String? email;

  /// Public key material for peer validation (Communication.md — Security).
  String? publicKey;

  /// Whether the profile is visible to peers (Privacy — user control).
  bool profileVisible = true;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'username': username,
      'displayName': displayName,
      'avatarPath': avatarPath,
      'bio': bio,
      'email': email,
      'publicKey': publicKey,
      'profileVisible': profileVisible,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    username = m['username'] as String? ?? '';
    displayName = m['displayName'] as String? ?? '';
    avatarPath = m['avatarPath'] as String?;
    bio = m['bio'] as String?;
    email = m['email'] as String?;
    publicKey = m['publicKey'] as String?;
    profileVisible = m['profileVisible'] as bool? ?? true;
  }

  static UserCollection fromMap(Map<String, dynamic> m) =>
      UserCollection()..applyMap(m);
}
