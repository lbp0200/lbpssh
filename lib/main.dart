import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/connection_repository.dart';
import 'domain/services/terminal_service.dart';
import 'domain/services/sync_service.dart';
import 'domain/services/app_config_service.dart';
import 'domain/services/import_export_service.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers_riverpod/service_providers.dart';
import 'presentation/screens/main_screen.dart';
import 'utils/sentry_service.dart';

void main() async {
  // 初始化 Sentry
  await SentryService().init(
    dsn: const String.fromEnvironment('SENTRY_DSN'),
  );

  // 全局错误处理器
  FlutterError.onError = (details) {
    SentryService().captureException(
      details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    SentryService().captureException(error, stackTrace: stack);
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器并设置最大化
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });

  final connectionRepository = ConnectionRepository();
  await connectionRepository.init();

  final terminalService = TerminalService();
  final syncService = SyncService(connectionRepository);
  final appConfigService = AppConfigService.getInstance();
  await AppConfigService.ensureInitialized();
  final importExportService = ImportExportService(connectionRepository);

  runApp(
    ProviderScope(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connectionRepository),
        terminalServiceProvider.overrideWithValue(terminalService),
        syncServiceProvider.overrideWith((ref) => syncService),
        appConfigServiceProvider.overrideWithValue(appConfigService),
        importExportServiceProvider.overrideWith((ref) => importExportService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSH Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh')],
    );
  }
}
