/// Themes page — appearance customization (FR-010, Decision_Log — Themes).
/// Light / Dark / AMOLED modes + accent color presets.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/domain/services/theme_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class ThemesPage extends StatefulWidget {
  const ThemesPage({super.key});

  @override
  State<ThemesPage> createState() => _ThemesPageState();
}

class _ThemesPageState extends State<ThemesPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = serviceLocator<ThemeService>();
    final vm = context.read<AppViewModel>();
    final settings = vm.settings!;
    return Scaffold(
      appBar: AppBar(title: Text(l.themes)),
      body: ListView(
        children: [
          _section(l.appearance, [
            for (final mode in AppThemeMode.values)
              RadioListTile<AppThemeMode>(
                value: mode,
                groupValue: theme.mode,
                title: Text(_modeLabel(l, mode)),
                onChanged: (m) => _setMode(m!, settings),
              ),
          ]),
          _section(l.accentColor, [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: ThemeService.accentPresets.map((c) {
                  final selected = c.toARGB32() == settings.accentColor;
                  return GestureDetector(
                    onTap: () => _setAccent(c, settings),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _setMode(AppThemeMode mode, SettingsCollection settings) async {
    final vm = context.read<AppViewModel>();
    final svc = serviceLocator<SettingsService>();
    final updated = await svc.setThemeMode(settings, mode);
    await vm.updateSettings(updated);
    setState(() {});
  }

  Future<void> _setAccent(Color c, SettingsCollection settings) async {
    final vm = context.read<AppViewModel>();
    final svc = serviceLocator<SettingsService>();
    final updated = await svc.setAccent(settings, c.toARGB32());
    await vm.updateSettings(updated);
    setState(() {});
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

  String _modeLabel(AppLocalizations l, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => l.lightTheme,
      AppThemeMode.dark => l.darkTheme,
      AppThemeMode.amoled => l.amoledTheme,
    };
  }
}
