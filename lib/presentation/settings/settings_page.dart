/// Settings page — general, maps, notifications, GPS thresholds and privacy
/// (Database_Overview.md — Settings). All changes are local (Local-First).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsCollection _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppViewModel>().settings!.copy();
  }

  Future<void> _save() async {
    await context.read<AppViewModel>().updateSettings(
          await serviceLocator<SettingsService>().save(_settings),
        );
  }

  Future<void> _setMapProvider(MapProvider p) async {
    setState(() => _settings.mapProvider = p.name);
    await _save();
  }

  Future<void> _setLocale(String locale) async {
    setState(() => _settings.locale = locale);
    await _save();
  }

  Future<void> _toggle(bool Function() get, void Function(bool) set) async {
    set(!get());
    setState(() {});
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          _section(l.selectMapProvider, [
            for (final p in MapProvider.values)
              RadioListTile<String>(
                value: p.name,
                groupValue: _settings.mapProvider,
                title: Text(_mapLabel(l, p)),
                onChanged: (_) => _setMapProvider(p),
              ),
          ]),
          _section(l.language, [
            RadioListTile<String>(
              value: 'en',
              groupValue: _settings.locale,
              title: Text(l.english),
              onChanged: (_) => _setLocale('en'),
            ),
            RadioListTile<String>(
              value: 'ru',
              groupValue: _settings.locale,
              title: Text(l.russian),
              onChanged: (_) => _setLocale('ru'),
            ),
          ]),
          _section(l.notifications, [
            SwitchListTile(
              title: Text(l.newMessage),
              value: _settings.notifyNewMessage,
              onChanged: (_) => _toggle(() => _settings.notifyNewMessage,
                  (v) => _settings.notifyNewMessage = v),
            ),
            SwitchListTile(
              title: Text(l.participantArrived),
              value: _settings.notifyParticipantArrived,
              onChanged: (_) => _toggle(
                  () => _settings.notifyParticipantArrived,
                  (v) => _settings.notifyParticipantArrived = v),
            ),
            SwitchListTile(
              title: Text(l.silentMode),
              value: _settings.silentMode,
              onChanged: (_) => _toggle(
                  () => _settings.silentMode, (v) => _settings.silentMode = v),
            ),
          ]),
          _section('Privacy', [
            SwitchListTile(
              title: Text(l.profile),
              subtitle: const Text('Profile visible to peers'),
              value: _settings.profileVisible,
              onChanged: (_) => _toggle(() => _settings.profileVisible,
                  (v) => _settings.profileVisible = v),
            ),
            SwitchListTile(
              title: const Text('Share GPS by default'),
              value: _settings.shareGpsByDefault,
              onChanged: (_) => _toggle(() => _settings.shareGpsByDefault,
                  (v) => _settings.shareGpsByDefault = v),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
        ...children,
      ],
    );
  }

  String _mapLabel(AppLocalizations l, MapProvider p) {
    return switch (p) {
      MapProvider.openStreetMap => l.openStreetMap,
      MapProvider.mapLibre => l.mapLibre,
      MapProvider.googleMaps => l.googleMaps,
      MapProvider.here => l.hereMaps,
      MapProvider.twoGis => l.twoGis,
      MapProvider.yandexMaps => l.yandexMaps,
    };
  }
}
