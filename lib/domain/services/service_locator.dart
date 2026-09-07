/// Dependency injection container (get_it). Wires the Local-First stack:
/// database → repositories → services. Modules depend only on interfaces,
/// never on concrete storage (Architecture.md — module independence).
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:pokatuha/core/platform/deep_link_service.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/media_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/notification_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/poll_repository.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/repositories/settings_repository.dart';
import 'package:pokatuha/domain/repositories/statistics_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/battery_optimization_service.dart';
import 'package:pokatuha/domain/services/chat_keep_alive_service.dart';
import 'package:pokatuha/domain/services/chat_sync_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/fcm_push_service.dart';
import 'package:pokatuha/domain/services/foreground_location_service.dart';
import 'package:pokatuha/domain/services/geocoding_service.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/hybrid_communication_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/relay_connection.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/notification_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/domain/services/statistics_service.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';
import 'package:pokatuha/domain/services/theme_service.dart';
import 'package:pokatuha/domain/services/weather_service.dart';
import 'package:pokatuha/presentation/deep_links/deep_link_dispatcher.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // --- Database ---
  final database = await DatabaseService.open();
  serviceLocator.registerSingleton<DatabaseService>(database);

  // --- Repositories ---
  serviceLocator
      .registerLazySingleton<UserRepository>(() => UserRepository(database));
  serviceLocator
      .registerLazySingleton<EventRepository>(() => EventRepository(database));
  serviceLocator.registerLazySingleton<GroupRepository>(
      () => GroupRepository(database));
  serviceLocator.registerLazySingleton<GroupMemberRepository>(
      () => GroupMemberRepository(database));
  serviceLocator.registerLazySingleton<ParticipantRepository>(
      () => ParticipantRepository(database));
  serviceLocator.registerLazySingleton<MessageRepository>(
      () => MessageRepository(
            database,
            // P2P transport — chat messages are broadcast to peers on the
            // same network (V3.0.4, bug 1).
            transport: serviceLocator<CommunicationService>(),
          ));
  serviceLocator
      .registerLazySingleton<PollRepository>(() => PollRepository(database));
  serviceLocator
      .registerLazySingleton<RouteRepository>(() => RouteRepository(database));
  serviceLocator.registerLazySingleton<ArchiveRepository>(
      () => ArchiveRepository(database));
  serviceLocator.registerLazySingleton<NotificationRepository>(
      () => NotificationRepository(database));
  serviceLocator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(database));
  serviceLocator.registerLazySingleton<ActivityTypeRepository>(
      () => ActivityTypeRepository(database));
  serviceLocator
      .registerLazySingleton<MediaRepository>(() => MediaRepository(database));
  serviceLocator.registerLazySingleton<StatisticsRepository>(
      () => StatisticsRepository(database));

  // --- Services ---
  serviceLocator.registerLazySingleton<AuthService>(
      () => AuthService(serviceLocator<UserRepository>()));
  serviceLocator.registerLazySingleton<EventService>(() => EventService(
        serviceLocator<EventRepository>(),
        serviceLocator<ParticipantRepository>(),
        serviceLocator<ArchiveRepository>(),
        // V3.0.7 bug 2 — broadcast activity create / edit to all group
        // members over the realtime transport (UDP + MQTT relay).
        transport: serviceLocator<CommunicationService>(),
        // V3.0.7 bug 2 — enforce edit permission: only organizer OR owner /
        // admin of the parent group may edit.
        memberRepository: serviceLocator<GroupMemberRepository>(),
      ));
  serviceLocator.registerLazySingleton<GpsService>(() => GpsService());
  // V3.0.5 — the foreground service is shared between GPS sharing and the
  // chat keep-alive. When GPS sharing ends, the notification text is
  // handed back to the keep-alive instead of stopping the service.
  serviceLocator.registerLazySingleton<ForegroundLocationService>(
      () => ForegroundLocationService(
            onStoppedFallback: () async =>
                await serviceLocator<ChatKeepAliveService>()
                    .revertNotification(),
          ));
  serviceLocator.registerLazySingleton<WeatherService>(
      () => WeatherService(client: http.Client()));
  serviceLocator.registerLazySingleton<GeocodingService>(
      () => GeocodingService(client: http.Client()));
  serviceLocator.registerLazySingleton<MapService>(() => MapService());
  serviceLocator.registerLazySingleton<GpxService>(() => GpxService());
  serviceLocator.registerLazySingleton<IdentityService>(
      () => IdentityService());
  serviceLocator.registerLazySingleton<GroupService>(() => GroupService(
        serviceLocator<GroupRepository>(),
        serviceLocator<GroupMemberRepository>(),
        serviceLocator<EventRepository>(),
        serviceLocator<UserRepository>(),
        serviceLocator<ParticipantRepository>(),
        // V3.0.7 bug 1 — broadcast new-member additions to all existing
        // members so their Members tab updates immediately.
        transport: serviceLocator<CommunicationService>(),
      ));
  serviceLocator.registerLazySingleton<StatisticsService>(
      () => StatisticsService(serviceLocator<StatisticsRepository>()));
  serviceLocator.registerLazySingleton<ThemeService>(() => ThemeService());
  serviceLocator.registerLazySingleton<NotificationService>(
      () => NotificationService(serviceLocator<NotificationRepository>()));
  // V3.0.5 (bug 1) — status-bar notifications for background chat messages.
  serviceLocator.registerLazySingleton<SystemNotificationService>(
      () => SystemNotificationService());
  // V3.0.7 (bug 4) — request battery-optimization exemption so the chat
  // keep-alive foreground service survives aggressive OEM Doze.
  serviceLocator.registerLazySingleton<BatteryOptimizationService>(
      () => BatteryOptimizationService());
  // V3.0.7 (bug 3 & 4) — FCM push notifications wake the device when the
  // app is fully killed or the foreground service was destroyed by the OS.
  // ADR-003 is preserved: FCM carries only metadata (groupId, eventId,
  // authorName) — never the chat payload. The actual message is fetched
  // peer-to-peer via ChatSyncService after the app wakes.
  serviceLocator.registerLazySingleton<FcmPushService>(() => FcmPushService());
  serviceLocator.registerLazySingleton<ChatKeepAliveService>(
      () => ChatKeepAliveService(
            groupRepository: serviceLocator<GroupRepository>(),
            eventRepository: serviceLocator<EventRepository>(),
            userRepository: serviceLocator<UserRepository>(),
          ));
  serviceLocator.registerLazySingleton<SettingsService>(
      () => SettingsService(serviceLocator<SettingsRepository>()));
  // --- Communication (V3.0.4/V3.0.5 — real local-network + internet) ---
  // HybridCommunicationService keeps the in-process loopback, the UDP
  // broadcast on the local Wi-Fi (ADR-008) AND adds an encrypted MQTT
  // relay so chat works over mobile networks too (ADR-009, bug 2).
  serviceLocator.registerLazySingleton<CommunicationService>(
      () => HybridCommunicationService(
            resolveRoute: (envelope) async {
              // Route resolution: most payloads carry the groupId directly;
              // chat payloads carry eventId (→ event → group), acks carry
              // the acknowledged message id (→ message → event → group).
              final events = serviceLocator<EventRepository>();
              final groups = serviceLocator<GroupRepository>();
              String? gid = envelope.payload['groupId'] as String?;
              if (gid == null || gid.isEmpty) {
                String? eventId;
                if (envelope.type == RealtimeType.chatAck) {
                  final message = await serviceLocator<MessageRepository>()
                      .getById(envelope.payload['ackFor'] as String? ?? '');
                  eventId = message?.eventId;
                } else {
                  eventId = envelope.payload['eventId'] as String?;
                }
                if (eventId != null && eventId.isNotEmpty) {
                  final event = await events.getById(eventId);
                  gid = event?.groupId;
                }
              }
              if (gid == null || gid.isEmpty) return null;
              final group = await groups.getById(gid);
              final code = group?.inviteCode;
              if (code == null || code.trim().isEmpty) return null;
              return (groupId: gid, inviteCode: code);
            },
            currentRoutes: () async {
              final groups = await serviceLocator<GroupRepository>().all();
              return <RelayRoute>[
                for (final g in groups)
                  if (g.inviteCode != null && g.inviteCode!.trim().isNotEmpty)
                    (groupId: g.id, inviteCode: g.inviteCode!),
              ];
            },
          ));
  serviceLocator.registerLazySingleton<ChatSyncService>(() => ChatSyncService(
        transport: serviceLocator<CommunicationService>(),
        messageRepository: serviceLocator<MessageRepository>(),
        eventRepository: serviceLocator<EventRepository>(),
        memberRepository: serviceLocator<GroupMemberRepository>(),
        authService: serviceLocator<AuthService>(),
        // V3.0.5 (bug 1) — status-bar notifications while backgrounded.
        notifications: serviceLocator<SystemNotificationService>(),
        groupRepository: serviceLocator<GroupRepository>(),
        userRepository: serviceLocator<UserRepository>(),
        participantRepository: serviceLocator<ParticipantRepository>(),
        isAppInBackground: () {
          final state =
              WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
          return state != AppLifecycleState.resumed;
        },
      ));
  // Start listening to incoming envelopes right away — the chat, history
  // sync and acks rely on this subscription being alive for the whole app
  // session.
  serviceLocator<ChatSyncService>().start();
  serviceLocator.registerLazySingleton<DeepLinkService>(
      () => DeepLinkService());
  serviceLocator.registerLazySingleton<DeepLinkDispatcher>(
      () => DeepLinkDispatcher());
}

Future<void> disposeServiceLocator() async {
  serviceLocator<WeatherService>().dispose();
  if (serviceLocator.isRegistered<ChatSyncService>()) {
    await serviceLocator<ChatSyncService>().stop();
  }
  if (serviceLocator.isRegistered<CommunicationService>()) {
    final communication = serviceLocator<CommunicationService>();
    if (communication is LocalNetworkCommunicationService) {
      communication.dispose();
    } else if (communication is LocalCommunicationService) {
      communication.dispose();
    }
  }
  await serviceLocator<DatabaseService>().close();
  await serviceLocator.reset();
}
