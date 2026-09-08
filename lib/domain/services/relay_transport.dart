/// Fan-out relay transport (V3.0.9 — ADR-010).
///
/// Runs several [RelayConnection] legs concurrently and merges them into
/// one logical connection:
///   * publish  — every connected leg (a leg that is down just skips it);
///   * subscribe — every leg (re-applied by each leg after its own
///     reconnects);
///   * incoming — merged from all legs; cross-leg duplicates are absorbed
///     by the idempotent ingest layer (HybridCommunicationService).
///
/// The default set (see [buildDefaultRelayTransport]) is the MQTT relay
/// (ADR-009, existing installs) + the NOSTR relay (ADR-010). Running both
/// costs a second long-lived socket and negligible traffic (the allowlist
/// limits what crosses the internet) and buys delivery resilience: public
/// MQTT brokers rate-limit or die, public relays are independent — the
/// chance of BOTH legs being unavailable at once is small. Either leg can
/// later be removed by editing this factory only.
library;

import 'package:pokatuha/domain/services/nostr_relay_connection.dart';
import 'package:pokatuha/domain/services/relay_connection.dart';

/// The default internet relay transport: MQTT (ADR-009) + NOSTR (ADR-010)
/// fanned out. No account or credentials are involved anywhere.
RelayConnection buildDefaultRelayTransport({
  required String clientId,
  RelayMessageHandler? onMessage,
}) {
  return FanoutRelayConnection(
    <RelayConnection>[
      MqttRelayConnection(clientId: clientId),
      NostrRelayConnection(),
    ],
    onMessage: onMessage,
  );
}

class FanoutRelayConnection implements RelayConnection {
  FanoutRelayConnection(this._connections, {this.onMessage}) {
    for (final connection in _connections) {
      connection.onMessage = (topic, body) => onMessage?.call(topic, body);
    }
  }

  final List<RelayConnection> _connections;

  @override
  RelayMessageHandler? onMessage;

  @override
  bool get isConnected => _connections.any((c) => c.isConnected);

  @override
  Future<bool> connect() async {
    final results =
        await Future.wait(_connections.map(_safeConnect));
    return results.any((ok) => ok);
  }

  @override
  Future<void> disconnect() async {
    await Future.wait(_connections.map(_safeDisconnect));
  }

  @override
  Future<void> subscribe(String topic) async {
    await Future.wait(_connections.map((c) => _safeSubscribe(c, topic)));
  }

  @override
  Future<void> publish(String topic, String body) async {
    // Best-effort by contract — individual legs swallow their own errors;
    // the guard keeps a throwing leg from masking the others.
    await Future.wait(
        _connections.map((c) => _safePublish(c, topic, body)));
  }

  Future<bool> _safeConnect(RelayConnection c) async {
    try {
      return await c.connect();
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeDisconnect(RelayConnection c) async {
    try {
      await c.disconnect();
    } catch (_) {}
  }

  Future<void> _safeSubscribe(RelayConnection c, String topic) async {
    try {
      await c.subscribe(topic);
    } catch (_) {}
  }

  Future<void> _safePublish(RelayConnection c, String topic, String body) async {
    try {
      await c.publish(topic, body);
    } catch (_) {}
  }
}
