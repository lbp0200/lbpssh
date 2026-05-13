import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lbp_ssh/main.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app should launch and show main screen', (tester) async {
      // 创建测试依赖
      final connectionRepository = ConnectionRepository();
      final terminalService = TerminalService();
      final syncService = SyncService(connectionRepository);
      final appConfigService = AppConfigService.getInstance();
      final importExportService = ImportExportService(connectionRepository);

      // 启动应用
      await tester.pumpWidget(
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
      await tester.pumpAndSettle();

      // 验证应用启动成功
      expect(find.byType(MaterialApp), findsOneWidget);

      // 验证主界面存在 (Scaffold)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('app should have theme support', (tester) async {
      // 创建测试依赖
      final connectionRepository = ConnectionRepository();
      final terminalService = TerminalService();
      final syncService = SyncService(connectionRepository);
      final appConfigService = AppConfigService.getInstance();
      final importExportService = ImportExportService(connectionRepository);

      await tester.pumpWidget(
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
      await tester.pumpAndSettle();

      // 验证 MaterialApp 有主题配置
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
    });
  });
}
