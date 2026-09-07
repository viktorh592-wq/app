/// Root application widget. Configures localization, theme and the auth gate
/// (onboarding vs. main scaffold). Observes [AppViewModel] for theme / locale
/// changes driven by local settings (FR-010). Wires pokatuha:// deep links
/// (USER_DISCOVERY.md §1–§2) through the DeepLinkDispatcher.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:pokatuha/core/constants/app_constants.dart';
import 'package:pokatuha/core/platform/deep_link_service.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/chat_keep_alive_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';
import 'package:pokatuha/domain/services/theme_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/deep_links/deep_link_dispatcher.dart';
import 'package:pokatuha/presentation/onboarding/onboarding_page.dart';
import 'package:pokatuha/presentation/theme/app_theme.dart';
import 'package:pokatuha/presentation/widgets/main_scaffold.dart';

class PokatuhaApp extends StatefulWidget {
  const PokatuhaApp({super.key});

  @override
  State<PokatuhaApp> createState() => _PokatuhaAppState();
}

class _PokatuhaAppState extends State<PokatuhaApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _linkSub;
  Timer? _initialLinkRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // V3.0.5 (bug 1) — task-isolate communication port for the chat
    // keep-alive heartbeat.
    FlutterForegroundTask.initCommunicationPort();
    _initDeepLinks();
    _startChatKeepAlive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _initialLinkRetry?.cancel();
    super.dispose();
  }

  /// V3.0.5 (bug 1) — chat notifications are only relevant while the app
  /// is out of the foreground; when the user comes back the messages are
  /// on screen, so clear them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      serviceLocator<SystemNotificationService>().cancelAllChat();
    }
  }

  /// Starts the chat keep-alive foreground service once the navigator
  /// context exists (localized strings are resolved from it).
  void _startChatKeepAlive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context =
          serviceLocator<DeepLinkDispatcher>().navigatorKey.currentContext;
      var title = 'Pokatuha';
      var body = 'Receiving messages';
      if (context != null) {
        final l = AppLocalizations.of(context);
        if (l != null) {
          title = l.chatKeepAliveTitle;
          body = l.chatKeepAliveBody;
        }
      }
      // Configure the localized chat channel label before the first
      // status-bar notification is shown.
      serviceLocator<SystemNotificationService>()
          .configure(chatChannelName: title);
      serviceLocator<ChatKeepAliveService>()
          .ensureStarted(title: title, body: body);
    });
  }

  /// Cold-start link + live links while the app runs (FIX_PLAN S1-T7).
  /// The initial link is retried briefly because the navigator context is
  /// not available on the very first frames.
  void _initDeepLinks() {
    final deepLinks = serviceLocator<DeepLinkService>();
    final dispatcher = serviceLocator<DeepLinkDispatcher>();
    deepLinks.start();
    _linkSub = deepLinks.links.listen(dispatcher.handle);
    deepLinks.initialLink().then((link) {
      if (link == null) return;
      _initialLinkRetry =
          Timer.periodic(const Duration(milliseconds: 300), (timer) {
        if (timer.tick > 20) {
          timer.cancel();
          return;
        }
        if (dispatcher.navigatorKey.currentContext != null) {
          timer.cancel();
          dispatcher.handle(link);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppViewModel()..initialize(),
      child: Consumer<AppViewModel>(
        builder: (context, vm, _) {
          final theme = serviceLocator<ThemeService>();
          final locale = vm.settings?.locale ?? 'ru';
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: serviceLocator<DeepLinkDispatcher>().navigatorKey,
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
