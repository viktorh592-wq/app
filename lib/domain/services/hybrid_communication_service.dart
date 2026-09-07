/// Hybrid communication service (V3.0.5 — user-reported bug 2: chat must
/// also work over MOBILE networks, ADR-009).
///
/// Extends the local-network transport (loopback + UDP broadcast, ADR-008)
/// with an internet relay:
///
///   * broadcast(): loopback + UDP (unchanged) AND — for relayer types —
///     one AES-GCM-sealed copy to the group's relay topic (best-effort);
///   * relay incoming: sealed bodies are decrypted with the group key and
///     fed into the same merged incoming stream;
///   * cross-transport duplicates (UDP + relay) are absorbed by the
///     idempotent ingest layer; a relay-local eid set guards double
///     decryption of QoS-1 re-deliveries.
///
/// Only a small allowlist of envelope types crosses the internet (chat,
/// acks, history sync) — GPS/presence traffic stays on the LAN (ADR-009).
library;

import 'dart:async';
import 'dart:convert';

import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';
import 'package:pokatuha/domain/services/relay_connection.dart';
import 'package:pokatuha/domain/services/relay_codec.dart';

/// Resolves the relay route of an envelope (null — do not relay).
typedef RelayRouteResolver = Future<RelayRoute?> Function(
  RealtimeEnvelope envelope,
);

/// Returns every group this device currently knows (id + invite code).
typedef RelayRoutesProvider = Future<List<RelayRoute>> Function();

class HybridCommunicationService extends LocalNetworkCommunicationService {
  HybridCommunicationService({
    super.port,
    required RelayRouteResolver resolveRoute,
    required RelayRoutesProvider currentRoutes,
    RelayConnection? relayConnection,
  })  : _resolveRoute = resolveRoute,
        _currentRoutes = currentRoutes {
    _relay = relayConnection ??
        MqttRelayConnection(clientId: 'pokatuha-relay-$originId');
    _relay.onMessage = (topic, body) => unawaited(_onRelayMessage(topic, body));
    if (supportsNetwork) {
      // Fire-and-forget like the UDP boot — a broker outage must never
      // block startup (LAN chat keeps working).
      unawaited(_bootRelay());
    }
  }

  final RelayRouteResolver _resolveRoute;
  final RelayRoutesProvider _currentRoutes;
  late final RelayConnection _relay;

  /// topic → route. Populated on subscribe; incoming bodies are opened
  /// with the matching route's key material.
  final Map<String, RelayRoute> _routesByTopic = <String, RelayRoute>{};

  /// Envelope ids already processed through the relay path.
  final Set<String> _seenRelayEnvelopeIds = <String>{};

  /// Envelope types that may cross the internet (ADR-009).
  static const Set<RealtimeType> relayableTypes = <RealtimeType>{
    RealtimeType.chat,
    RealtimeType.chatAck,
    RealtimeType.chatHistoryRequest,
    RealtimeType.chatHistoryBatch,
  };

  /// Boots the relay connection and subscribes all known groups.
  Future<void> _bootRelay() async {
    try {
      final connected = await _relay.connect();
      if (!connected) return;
      await syncSubscriptions();
    } catch (_) {
      // Best-effort.
    }
  }

  /// (Re)applies subscriptions for the current group list. Called at boot
  /// and after a new group was joined via QR.
  Future<void> syncSubscriptions() async {
    try {
      final routes = await _currentRoutes();
      for (final route in routes) {
        final topic = await topicForInviteCode(route.inviteCode);
        if (_routesByTopic.containsKey(topic)) continue;
        _routesByTopic[topic] = route;
        await _relay.subscribe(topic);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    await super.broadcast(envelope); // loopback + UDP
    await _relayBroadcast(envelope);
  }

  Future<void> _relayBroadcast(RealtimeEnvelope envelope) async {
    if (!relayableTypes.contains(envelope.type)) return;
    try {
      final route = await _resolveRoute(envelope);
      if (route == null) return;
      final topic = await topicForInviteCode(route.inviteCode);
      final sealed = await sealEnvelope(
        envelopeJson: encodeEnvelope(envelope),
        groupId: route.groupId,
        inviteCode: route.inviteCode,
      );
      if (sealed == null) return;
      await _relay.publish(topic, sealed);
    } catch (_) {
      // Relay is best-effort — local-first never depends on it.
    }
  }

  Future<void> _onRelayMessage(String topic, String body) async {
    final route = _routesByTopic[topic];
    if (route == null) return; // topic we did not subscribe to
    Map<String, dynamic> seal;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      seal = decoded;
    } catch (_) {
      return;
    }
    if ((seal['v'] as int? ?? 0) != kRelaySealVersion) return;
    final envelopeJson = await openSeal(
      relayJson: body,
      groupId: route.groupId,
      inviteCode: route.inviteCode,
    );
    if (envelopeJson == null) return; // wrong key / tampered / foreign
    Map<String, dynamic> raw;
    String eid;
    try {
      final decoded = jsonDecode(envelopeJson);
      if (decoded is! Map<String, dynamic>) return;
      raw = decoded;
      eid = raw['eid'] as String? ?? '';
    } catch (_) {
      return;
    }
    if (eid.isEmpty) return;
    // De-duplicate QoS-1 re-deliveries before dispatching.
    if (!_rememberRelayEnvelope(eid)) return;
    final envelope = LocalNetworkCommunicationService.decodeEnvelope(
      envelopeJson,
      envelopeId: eid,
      origin: raw['o'] as String? ?? '',
    );
    if (envelope == null) return;
    addIncoming(envelope);
  }

  bool _rememberRelayEnvelope(String eid) {
    if (_seenRelayEnvelopeIds.contains(eid)) return false;
    while (_seenRelayEnvelopeIds.length >= kMaxSeenEnvelopes) {
      _seenRelayEnvelopeIds.remove(_seenRelayEnvelopeIds.first);
    }
    _seenRelayEnvelopeIds.add(eid);
    return true;
  }

  @override
  void dispose() {
    try {
      _relay.disconnect();
    } catch (_) {}
    super.dispose();
  }
}
