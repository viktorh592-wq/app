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
                  final selected = c.value == settings.accentColor;
                  return GestureDetector(
                    onTap: () => _setAccent(c, settings),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: c.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white)
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

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...children,
      ],
    );
  }

  String _modeLabel(AppLocalizations l, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return l.lightTheme;
      case AppThemeMode.dark:
        return l.darkTheme;
      case AppThemeMode.amoled:
        return l.amoledTheme;
    }
  }

  void _setMode(AppThemeMode mode, SettingsCollection settings) {
    serviceLocator<ThemeService>().setMode(mode);
    settings.setThemeMode(mode.name);
    setState(() {});
  }

  void _setAccent(Color color, SettingsCollection settings) {
    settings.accentColor = color.value;
    serviceLocator<ThemeService>().setAccent(color);
    setState(() {});
  }
}
