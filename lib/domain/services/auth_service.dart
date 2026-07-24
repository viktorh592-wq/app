/// Local authentication / profile service (ADR-001, Rule 6 — no Firebase
/// Auth). There is exactly one local profile per device.
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';

class AuthService {
  AuthService(this._userRepository);
  final UserRepository _userRepository;

  UserCollection? _current;
  UserCollection? get current => _current;
  bool get isAuthenticated => _current != null;

  Future<UserCollection?> loadCurrent() async {
    _current = await _userRepository.getCurrent();
    return _current;
  }

  Future<UserCollection> onboarding({
    required String displayName,
    String? username,
    String? bio,
  }) async {
    if (displayName.trim().isEmpty) {
      throw const ValidationError('Display name is required');
    }
    _current = await _userRepository.createProfile(
      displayName: displayName,
      username: username,
      bio: bio,
    );
    return _current!;
  }

  Future<UserCollection> updateProfile({
    String? displayName,
    String? bio,
    bool? profileVisible,
  }) async {
    final user = await _userRepository.requireCurrent();
    if (displayName != null) user.displayName = displayName.trim();
    if (bio != null) user.bio = bio.trim();
    if (profileVisible != null) user.profileVisible = profileVisible;
    _current = await _userRepository.updateProfile(user);
    return _current!;
  }
}
