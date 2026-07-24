/// App-wide view model (ChangeNotifier). Owns the local profile, settings,
/// theme and communication mode. Bridges the Local-First services to the UI
/// (Architecture.md — UI → Business → Repositories → Storage).
import 'package:flutter/foundation.dart';

import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
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
