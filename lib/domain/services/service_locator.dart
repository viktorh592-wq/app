/// Dependency injection container (get_it). Wires the Local-First stack:
/// database → repositories → services. Modules depend only on interfaces,
/// never on concrete storage (Architecture.md — module independence).
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
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/foreground_location_service.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
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
  serviceLocator.registerLazySingleton<MessageRepository>(
      () => MessageRepository(database));
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
  serviceLocator.registerLazySingleton<IdentityService>(
      () => IdentityService());
  serviceLocator.registerLazySingleton<GroupService>(() => GroupService(
        serviceLocator<GroupRepository>(),
        serviceLocator<GroupMemberRepository>(),
        serviceLocator<UserRepository>(), // V3.0.1 — needed for inviteByPublicId
      ));
  serviceLocator.registerLazySingleton<StatisticsService>(
      () => StatisticsService(serviceLocator<StatisticsRepository>()));
  serviceLocator.registerLazySingleton<ThemeService>(() => ThemeService());
  serviceLocator.registerLazySingleton<NotificationService>(
      () => NotificationService(serviceLocator<NotificationRepository>()));
  serviceLocator.registerLazySingleton<SettingsService>(
      () => SettingsService(serviceLocator<SettingsRepository>()));
  serviceLocator.registerLazySingleton<CommunicationService>(
      () => LocalCommunicationService());
  serviceLocator.registerLazySingleton<DeepLinkService>(
      () => DeepLinkService());
  serviceLocator.registerLazySingleton<DeepLinkDispatcher>(
      () => DeepLinkDispatcher());
}

Future<void> disposeServiceLocator() async {
  serviceLocator<WeatherService>().dispose();
  if (serviceLocator.isRegistered<CommunicationService>()) {
    (serviceLocator<CommunicationService>() as LocalCommunicationService)
        .dispose();
  }
  await serviceLocator<DatabaseService>().close();
  await serviceLocator.reset();
}
