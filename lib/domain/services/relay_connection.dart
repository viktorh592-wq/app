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

/// Public bootstrap broker (TLS). See ADR-009 — replace with a
/// self-hosted instance for production deployments.
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
    RelayMessageHandler? onMessage,
  })  : _clientId = clientId {
    this.onMessage = onMessage;
  }

  final String _clientId;
  final String host;
  final int port;

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
      final client = MqttServerClient.withPort(host, _clientId, port)
        ..secure = true
        ..autoReconnect = true
        ..resubscribeOnAutoReconnect = true
        ..keepAlivePeriod = 30
        ..connectTimeoutPeriod = 5000
        ..logging(on: false);
      final status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        return false;
      }
      _client = client;
      client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> batch) {
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
    } finally {
      _connecting = false;
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
