/// App-wide view model (ChangeNotifier). Owns the local profile, settings,
/// theme and communication mode. Bridges the Local-First services to the UI
/// (Architecture.md — UI → Business → Repositories → Storage).
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/domain/services/theme_service.dart';

class AppViewModel extends ChangeNotifier {
  AppViewModel();

  UserCollection? _user;
  SettingsCollection? _settings;
  bool _initialized = false;
  bool _syncing = false;

  /// Subscription that ingests incoming chat envelopes from the local
  /// network transport so messages sent by other Pokatuha devices appear
  /// in the chat in real-time (bug 1 — V3.0.3).
  StreamSubscription<RealtimeEnvelope>? _incomingChatSub;

  UserCollection? get user => _user;
  SettingsCollection? get settings => _settings;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _user != null;
  bool get isSyncing => _syncing;
  CommunicationMode get communicationMode =>
      serviceLocator<CommunicationService>().mode;

  Future<void> initialize() async {
    final auth = serviceLocator<AuthService>();
    _user = await auth.loadCurrent();

    if (_user != null) {
      await _loadSettings();
      _applyThemeAndMap();
      _watchCommunication();
      _startIncomingChatListener();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String displayName,
    String? username,
    String? bio,
  }) async {
    final auth = serviceLocator<AuthService>();
    _user = await auth.onboarding(
      displayName: displayName,
      username: username,
      bio: bio,
    );
    await _loadSettings();
    _applyThemeAndMap();
    _watchCommunication();
    _startIncomingChatListener();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    if (_user == null) return;
    _settings = await serviceLocator<SettingsService>().forUser(_user!.id);
  }

  void _applyThemeAndMap() {
    if (_settings == null) return;
    serviceLocator<ThemeService>().applyFromSettings(_settings!);
    final provider = MapProvider.values.firstWhere(
      (e) => e.name == _settings!.mapProvider,
      orElse: () => MapProvider.openStreetMap,
    );
    serviceLocator<MapService>()
        .setProvider(provider, styleUrl: _settings!.mapStyleId);
  }

  void _watchCommunication() {
    serviceLocator<CommunicationService>().modeStream.listen((mode) {
      _syncing = mode == CommunicationMode.offline;
      notifyListeners();
    });
  }

  /// Subscribe to incoming chat envelopes from the local-network transport
  /// and persist them via [MessageRepository.ingestIncoming]. Also set the
  /// sender id filter so the transport can drop its own broadcasts.
  void _startIncomingChatListener() {
    final user = _user;
    if (user == null) return;
    final transport = serviceLocator<CommunicationService>();
    if (transport is LocalNetworkCommunicationService) {
      transport.selfSenderId = user.id;
    }
    _incomingChatSub?.cancel();
    _incomingChatSub = transport.incoming
        .where((e) => e.type == RealtimeType.chat)
        .listen((envelope) async {
      final payload = envelope.payload;
      try {
        final saved = await serviceLocator<MessageRepository>()
            .ingestIncoming(payload);
        if (saved != null) {
          // Lazily create a stub user for the author when it's unknown
          // locally — otherwise the chat bubble shows just the short id.
          await _ensureAuthorUser(saved);
        }
      } catch (_) {
        // Ingest failures are non-fatal — the next sync window will retry.
      }
    });
  }

  /// Best-effort author hydration: when an incoming chat envelope references
  /// a user we haven't seen yet, create a minimal stub [UserCollection]
  /// locally so the chat bubble can render a display name (the short
  /// public id) instead of a raw UUID.
  Future<void> _ensureAuthorUser(MessageCollection message) async {
    final userRepo = serviceLocator<UserRepository>();
    final existing = await userRepo.getById(message.authorId);
    if (existing != null) return;
    try {
      final stub = UserCollection()
        ..id = message.authorId
        ..displayName =
            serviceLocator<IdentityService>().publicId(message.authorId);
      await userRepo.upsertStub(stub);
    } catch (_) {
      // Non-fatal — the chat will fall back to the short id.
    }
  }

  @override
  void dispose() {
    _incomingChatSub?.cancel();
    super.dispose();
  }

  Future<void> updateSettings(SettingsCollection settings) async {
    _settings = await serviceLocator<SettingsService>().save(settings);
    _applyThemeAndMap();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _user = await serviceLocator<AuthService>().loadCurrent();
    notifyListeners();
  }

  void setSyncing(bool value) {
    _syncing = value;
    notifyListeners();
  }
}
