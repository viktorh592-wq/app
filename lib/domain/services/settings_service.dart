/// Settings service — thin facade over [SettingsRepository] used by the UI.
import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/settings_repository.dart';

class SettingsService {
  SettingsService(this._repository);
  final SettingsRepository _repository;

  Future<SettingsCollection> forUser(String userId) =>
      _repository.forUser(userId);

  Future<SettingsCollection> save(SettingsCollection settings) =>
      _repository.save(settings);

  Future<SettingsCollection> setThemeMode(
    SettingsCollection settings,
    AppThemeMode mode,
  ) {
    settings.themeMode = mode.name;
    return _repository.save(settings);
  }

  Future<SettingsCollection> setAccent(
    SettingsCollection settings,
    int color,
  ) {
    settings.accentColor = color;
    return _repository.save(settings);
  }

  Future<SettingsCollection> setMapProvider(
    SettingsCollection settings,
    MapProvider provider,
  ) {
    settings.mapProvider = provider.name;
    return _repository.save(settings);
  }

  Future<SettingsCollection> setLocale(
    SettingsCollection settings,
    String locale,
  ) {
    settings.locale = locale;
    return _repository.save(settings);
  }
}
