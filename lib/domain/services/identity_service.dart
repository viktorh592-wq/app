/// Identity service — builds and parses `pokatuha://` deep links
/// (V2 USER_DISCOVERY.md §1–§2).
///
/// Link kinds:
///   `pokatuha://u/<short-id>`            — user profile (session-like public ID)
///   `pokatuha://g/<code>`                — group invite (legacy / minimal)
///   `pokatuha://g/<code>?d=<base64json>` — group invite WITH embedded
///                                          group payload (V3 fix — lets the
///                                          receiver materialize the group
///                                          even if it doesn't exist locally).
///
/// The short public ID is the first 12 hex chars of the user UUID with the
/// dashes removed, upper-cased — compact enough for a QR payload, unique
/// enough for local discovery.
import 'dart:convert';

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

  /// Builds a group invite URI with the full group payload embedded as
  /// base64-URL-safe JSON in the `?d=` query parameter. The receiver can
  /// materialize the group from this payload even if the group doesn't
  /// yet exist on their device (V3 fix for the "group not found on device"
  /// bug).
  String groupUriWithPayload({
    required String inviteCode,
    required Map<String, dynamic> payload,
  }) {
    final json = jsonEncode(payload);
    final b64 = base64Url.encode(utf8.encode(json));
    return '$_scheme://$_groupHost/$inviteCode?d=$b64';
  }

  /// Parses a pokatuha:// URI. Returns null for anything else.
  /// For group links, [PokatuhaLink.data] carries the decoded payload map
  /// when `?d=` was present, otherwise null.
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
      // Extract optional ?d= payload.
      Map<String, dynamic>? data;
      final dParam = u.queryParameters['d'];
      if (dParam != null && dParam.isNotEmpty) {
        try {
          final json = utf8.decode(base64Url.decode(dParam));
          final decoded = jsonDecode(json);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          // Malformed payload — treat as plain invite code link.
        }
      }
      return PokatuhaLink(
        kind: LinkKind.group,
        payload: payload.toUpperCase(),
        data: data,
      );
    }
    return null;
  }
}

/// What a pokatuha:// link points to.
enum LinkKind { user, group }

/// A parsed pokatuha:// link: [kind] + [payload] (short id or invite code).
/// For group links, [data] carries the embedded group payload when present
/// (V3 fix — enables offline group invitation across devices).
class PokatuhaLink {
  PokatuhaLink({required this.kind, required this.payload, this.data});

  final LinkKind kind;
  final String payload;

  /// Decoded group payload map for `pokatuha://g/<code>?d=<base64json>` links.
  /// Null for plain invite-code links and for user links.
  final Map<String, dynamic>? data;

  @override
  bool operator ==(Object other) =>
      other is PokatuhaLink && other.kind == kind && other.payload == payload;

  @override
  int get hashCode => Object.hash(kind, payload);

  @override
  String toString() => 'PokatuhaLink(${kind.name}, $payload)';
}
