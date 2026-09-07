/// Settings repository — general, map, notification, GPS and privacy
/// preferences (Database_Overview.md). Belongs to a User.
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final DatabaseService _db;

  TypedStore<SettingsCollection> get _store => _db.settingsStore;

  Future<SettingsCollection> forUser(String userId) async {
    final list = await _store.find(
      filter: Filter.equals('userId', userId),
      limit: 1,
    );
    if (list.isNotEmpty) return list.first;
    return _createDefault(userId);
  }

  Future<SettingsCollection> _createDefault(String userId) async {
    final now = Timestamps.nowUtc();
    final settings = SettingsCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..userId = userId
      ..locale = 'ru'
      ..themeMode = AppThemeMode.dark.name
      ..accentColor = 0xFF3B82F6
      ..mapProvider = MapProvider.openStreetMap.name;
    return _store.put(settings);
  }

  Future<SettingsCollection> save(SettingsCollection settings) async {
    settings.touch(Timestamps.nowUtc());
    return _store.put(settings);
  }
}
