/// Identity service — builds and parses `pokatuha://` deep links
/// (V2 USER_DISCOVERY.md §1–§2).
///
/// Link kinds:
///   `pokatuha://u/<short-id>` — user profile (session-like public ID)
///   `pokatuha://g/<code>`     — group invite
///
/// The short public ID is the first 12 hex chars of the user UUID with the
/// dashes removed, upper-cased — compact enough for a QR payload, unique
/// enough for local discovery.
class IdentityService {
  static const String _scheme = 'pokatuha';
  static const String _userHost = 'u';
  static const String _groupHost = 'g';

  /// Length of the short public ID derived from a user UUID.
  static const int shortIdLength = 12;

  /// Builds `pokatuha://u/<short-id>` for the given user id.
  String userUri(String userId) => '$_scheme://$_userHost/${publicId(userId)}';

  /// Short public ID of a user: first 12 hex chars of the UUID (no dashes),
  /// upper-cased (USER_DISCOVERY.md §1 — session-like public ID).
  String publicId(String userId) =>
      userId.replaceAll('-', '').substring(0, shortIdLength).toUpperCase();

  /// Builds `pokatuha://g/<invite-code>` for the given group.
  String groupUri(String inviteCode) => '$_scheme://$_groupHost/$inviteCode';

  /// Parses a pokatuha:// URI. Returns null for anything else.
  PokatuhaLink? parse(String uri) {
    final u = Uri.tryParse(uri.trim());
    if (u == null || u.scheme != _scheme) return null;
    if (u.host == _userHost && u.pathSegments.length == 1) {
      final payload = u.pathSegments[0];
      if (payload.isEmpty) return null;
      return PokatuhaLink(kind: LinkKind.user, payload: payload.toUpperCase());
    }
    if (u.host == _groupHost && u.pathSegments.length == 1) {
      final payload = u.pathSegments[0];
      if (payload.isEmpty) return null;
      return PokatuhaLink(kind: LinkKind.group, payload: payload.toUpperCase());
    }
    return null;
  }
}

/// What a pokatuha:// link points to.
enum LinkKind { user, group }

/// A parsed pokatuha:// link: [kind] + [payload] (short id or invite code).
class PokatuhaLink {
  PokatuhaLink({required this.kind, required this.payload});

  final LinkKind kind;
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is PokatuhaLink && other.kind == kind && other.payload == payload;

  @override
  int get hashCode => Object.hash(kind, payload);

  @override
  String toString() => 'PokatuhaLink(${kind.name}, $payload)';
}
