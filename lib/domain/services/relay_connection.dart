/// Relay connection abstraction + MQTT implementation (V3.0.5, ADR-009).
///
/// [RelayConnection] is transport-agnostic so the hybrid communication
/// service (and its tests) never depends on the MQTT client directly. The
/// MQTT implementation targets a public broker over TLS; pointing the app
/// to a self-hosted broker later is a constant change (ADR-009).
///
/// Delivery guarantees: QoS 1 (at-least-once). Duplicates are absorbed by
/// the envelope de-duplication and the idempotent ingest layer (local-first
/// correctness never relies on the transport).
library;

import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Re-exports for convenience of callers that only need the codec pieces.
export 'package:pokatuha/domain/services/relay_codec.dart'
    show kRelayTopicPrefix, openSeal, sealEnvelope, topicForInviteCode;

/// Public bootstrap brokers (TLS), tried in order (V3.0.7 — user-reported
/// bug 3: «chat not working over mobile network»). Multiple brokers give
/// the connection resilience when one broker is down or rate-limiting.
/// See ADR-009 — replace with a self-hosted instance for production.
const List<({String host, int port})> kRelayBrokers = <({String host, int port})>[
  (host: 'broker.emqx.io', port: 8883),
  (host: '8f5f4d56b3c04d8a8b3f9c4f7c2e1d6f.s1.eu.hivemq.cloud', port: 8883),
  (host: 'test.mosquitto.org', port: 8886),
];

/// Legacy single-host constant kept for backwards compatibility with tests.
const String kRelayBrokerHost = 'broker.emqx.io';
const int kRelayBrokerPort = 8883;

/// A group route for the relay: the id and the invite code of one group.
typedef RelayRoute = ({String groupId, String inviteCode});

/// Called for every relay message that arrives on a subscribed topic.
typedef RelayMessageHandler = void Function(
  String topic,
  String body,
);

abstract class RelayConnection {
  /// Called for every relay message that arrives on a subscribed topic.
  /// Set by the owner (the hybrid service / keep-alive task).
  RelayMessageHandler? onMessage;

  /// True while a broker session is established.
  bool get isConnected;

  /// Connects (idempotent). Returns true when connected. Failures are
  /// reported via the return value, never thrown.
  Future<bool> connect();

  Future<void> disconnect();

  /// Subscribes [topic]. Safe to call while disconnected — the connection
  /// implementation re-subscribes on the next connect / auto-reconnect.
  Future<void> subscribe(String topic);

  /// Publishes a UTF-8 text body (best-effort — failures are swallowed).
  Future<void> publish(String topic, String body);
}

class MqttRelayConnection extends RelayConnection {
  MqttRelayConnection({
    required String clientId,
    this.host = kRelayBrokerHost,
    this.port = kRelayBrokerPort,
    this.brokers = kRelayBrokers,
    RelayMessageHandler? onMessage,
  })  : _clientId = clientId {
    this.onMessage = onMessage;
  }

  final String _clientId;
  final String host;
  final int port;

  /// Broker list tried in order on connect / reconnect. V3.0.7 — multiple
  /// fallback brokers give chat resilience when one broker is down.
  final List<({String host, int port})> brokers;

  MqttServerClient? _client;
  bool _connecting = false;

  /// Topics we must be subscribed to (re-applied after reconnects).
  final Set<String> _topics = <String>{};

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<bool> connect() async {
    if (isConnected) return true;
    if (_connecting) return false;
    _connecting = true;
    try {
      // V3.0.7 — try every known broker until one connects. This makes
      // chat-over-mobile robust to a single public broker being down or
      // rate-limiting (the original bug 3 root cause).
      for (final broker in brokers) {
        final ok = await _connectToBroker(broker.host, broker.port);
        if (ok) return true;
      }
      // Fallback to the legacy single-host constant if the list above
      // failed entirely (kept for tests that inject a custom host).
      if (host != kRelayBrokerHost || port != kRelayBrokerPort) {
        return await _connectToBroker(host, port);
      }
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _connectToBroker(String brokerHost, int brokerPort) async {
    try {
      final client = MqttServerClient.withPort(
        brokerHost,
        '$_clientId-${brokerHost.hashCode.toRadixString(36)}',
        brokerPort,
      )
        ..secure = true
        ..autoReconnect = true
        ..resubscribeOnAutoReconnect = true
        ..keepAlivePeriod = 30
        ..connectTimeoutPeriod = 5000
        ..logging(on: false);
      final status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        try {
          client.disconnect();
        } catch (_) {}
        return false;
      }
      _client = client;
      client.updates
          ?.listen((List<MqttReceivedMessage<MqttMessage>> batch) {
        final handler = onMessage;
        if (handler == null) return;
        for (final received in batch) {
          final payload = received.payload;
          if (payload is! MqttPublishMessage) continue;
          try {
            final body =
                utf8.decode(payload.payload.message, allowMalformed: true);
            handler(received.topic, body);
          } catch (_) {
            // Malformed foreign traffic — ignore.
          }
        }
      });
      // First connect: apply the topics requested while offline.
      for (final topic in _topics) {
        try {
          client.subscribe(topic, MqttQos.atLeastOnce);
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    try {
      client?.disconnect();
    } catch (_) {}
  }

  @override
  Future<void> subscribe(String topic) async {
    _topics.add(topic);
    final client = _client;
    if (client == null || !isConnected) return;
    try {
      client.subscribe(topic, MqttQos.atLeastOnce);
    } catch (_) {}
  }

  @override
  Future<void> publish(String topic, String body) async {
    final client = _client;
    if (client == null || !isConnected) return;
    try {
      final builder = MqttClientPayloadBuilder()..addString(body);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (_) {
      // Best-effort — the history sync heals gaps.
    }
  }
}
