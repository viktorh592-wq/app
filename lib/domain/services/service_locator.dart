/// Dependency injection container (get_it). Wires the Local-First stack:
/// database → repositories → services. Modules depend only on interfaces,
/// never on concrete storage (Architecture.md — module independence).
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:pokatuha/core/platform/deep_link_service.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
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
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/foreground_location_service.dart';
import 'package:pokatuha/domain/services/geocoding_service.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/notification_service.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/domain/services/statistics_service.dart';
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
  serviceLocator.registerLazySingleton<MessageRepository>(() =>
      MessageRepository(
        database,
        // Transport injected lazily via the service-locator getter so the
        // repository picks up the real [LocalNetworkCommunicationService]
        // registered below.
        transport: _CommunicationServiceProxy(),
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
      ));
  serviceLocator.registerLazySingleton<GpsService>(() => GpsService());
  serviceLocator.registerLazySingleton<ForegroundLocationService>(
      () => ForegroundLocationService());
  serviceLocator.registerLazySingleton<WeatherService>(
      () => WeatherService(client: http.Client()));
  serviceLocator.registerLazySingleton<MapService>(() => MapService());
  serviceLocator.registerLazySingleton<GpxService>(() => GpxService());
  serviceLocator.registerLazySingleton<GeocodingService>(
      () => GeocodingService());
  serviceLocator.registerLazySingleton<IdentityService>(
      () => IdentityService());
  serviceLocator.registerLazySingleton<GroupService>(() => GroupService(
        serviceLocator<GroupRepository>(),
        serviceLocator<GroupMemberRepository>(),
      ));
  serviceLocator.registerLazySingleton<StatisticsService>(
      () => StatisticsService(serviceLocator<StatisticsRepository>()));
  serviceLocator.registerLazySingleton<ThemeService>(() => ThemeService());
  serviceLocator.registerLazySingleton<NotificationService>(
      () => NotificationService(serviceLocator<NotificationRepository>()));
  serviceLocator.registerLazySingleton<SettingsService>(
      () => SettingsService(serviceLocator<SettingsRepository>()));
  serviceLocator.registerLazySingleton<CommunicationService>(
      () => LocalNetworkCommunicationService());
  serviceLocator.registerLazySingleton<DeepLinkService>(
      () => DeepLinkService());
  serviceLocator.registerLazySingleton<DeepLinkDispatcher>(
      () => DeepLinkDispatcher());
}

Future<void> disposeServiceLocator() async {
  serviceLocator<WeatherService>().dispose();
  if (serviceLocator.isRegistered<GeocodingService>()) {
    serviceLocator<GeocodingService>().dispose();
  }
  if (serviceLocator.isRegistered<CommunicationService>()) {
    final cs = serviceLocator<CommunicationService>();
    if (cs is LocalNetworkCommunicationService) {
      cs.dispose();
    } else if (cs is LocalCommunicationService) {
      cs.dispose();
    }
  }
  await serviceLocator<DatabaseService>().close();
  await serviceLocator.reset();
}

/// Lazy proxy that resolves [CommunicationService] through the service
/// locator at first use. We can't pass the concrete instance at
/// [MessageRepository] construction time because [CommunicationService] is
/// registered AFTER [MessageRepository] in [setupServiceLocator] (the
/// repository depends on the transport, not vice-versa).
///
/// The proxy is a thin [CommunicationService] that delegates every call to
/// the real instance (looked up lazily on each call so tests can override
/// the registration).
class _CommunicationServiceProxy implements CommunicationService {
  CommunicationService? _resolved;

  CommunicationService get _inner {
    // Resolve once and cache; if the locator is reset (tests), the next
    // call after reset throws StateError which the repository already
    // handles via try/catch.
    return _resolved ??= serviceLocator<CommunicationService>();
  }

  @override
  CommunicationMode get mode => _inner.mode;

  @override
  Stream<CommunicationMode> get modeStream => _inner.modeStream;

  @override
  Stream<RealtimeEnvelope> get incoming => _inner.incoming;

  @override
  Future<void> connect({
    required String sessionId,
    required String peerToken,
  }) =>
      _inner.connect(sessionId: sessionId, peerToken: peerToken);

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) =>
      _inner.broadcast(envelope);

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> onFcmWakeUp({required String sessionId}) =>
      _inner.onFcmWakeUp(sessionId: sessionId);

  @override
  void enqueue(PendingChange change) => _inner.enqueue(change);

  @override
  List<PendingChange> get pendingQueue => _inner.pendingQueue;

  @override
  Future<void> syncPending() => _inner.syncPending();
}
