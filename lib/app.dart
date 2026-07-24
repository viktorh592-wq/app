/// Root application widget. Configures localization, theme and the auth gate
/// (onboarding vs. main scaffold). Observes [AppViewModel] for theme / locale
/// changes driven by local settings (FR-010).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/constants/app_constants.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/theme_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/onboarding/onboarding_page.dart';
import 'package:pokatuha/presentation/theme/app_theme.dart';
import 'package:pokatuha/presentation/widgets/main_scaffold.dart';

class PokatuhaApp extends StatelessWidget {
  const PokatuhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppViewModel()..initialize(),
      child: Consumer<AppViewModel>(
        builder: (context, vm, _) {
          final theme = serviceLocator<ThemeService>();
          final locale = vm.settings?.locale ?? 'en';
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(theme.accent),
            darkTheme: theme.mode == AppThemeMode.amoled
                ? AppTheme.amoled(theme.accent)
                : AppTheme.dark(theme.accent),
            themeMode: theme.flutterThemeMode,
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: vm.isInitialized
                ? (vm.isAuthenticated
                    ? const MainScaffold()
                    : const OnboardingPage())
                : const _BootScreen(),
          );
        },
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
