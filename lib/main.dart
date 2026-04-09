import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/connection_repository.dart';
import 'domain/services/terminal_service.dart';
import 'domain/services/sync_service.dart';
import 'domain/services/app_config_service.dart';
import 'domain/services/import_export_service.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/connection_provider.dart';
import 'presentation/providers/terminal_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/app_config_provider.dart';
import 'presentation/providers/import_export_provider.dart';
import 'presentation/providers/sftp_provider.dart';
import 'presentation/screens/main_screen.dart';
import 'utils/sentry_service.dart';

void main() async {
  // 初始化 Sentry
  await SentryService().init(
    dsn: const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
  );

  // 全局错误处理器
  FlutterError.onError = (details) {
    SentryService().captureException(details.exception,
        stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    SentryService().captureException(error, stackTrace: stack);
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器并设置最大化
  await windowManager.ensureInitialized();
  await windowManager.maximize();

  final connectionRepository = ConnectionRepository();
  await connectionRepository.init();

  final terminalService = TerminalService();
  final syncService = SyncService(connectionRepository);
  final appConfigService = AppConfigService.getInstance();
  final importExportService = ImportExportService(connectionRepository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ConnectionProvider(connectionRepository)..loadConnections(),
        ),
        ChangeNotifierProvider(
          create: (_) => TerminalProvider(terminalService, appConfigService),
        ),
        ChangeNotifierProvider(create: (_) => SyncProvider(syncService)),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(appConfigService),
        ),
        ChangeNotifierProvider(
          create: (_) => ImportExportProvider(importExportService),
        ),
        ChangeNotifierProvider(
          create: (context) => SftpProvider(
            context.read<TerminalProvider>(),
          ),
        ),
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
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
    );
  }
}
