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

Widget _buildApp() {
  final connectionRepository = ConnectionRepository();
  return ProviderScope(
    overrides: [
      connectionRepositoryProvider.overrideWithValue(connectionRepository),
      terminalServiceProvider.overrideWithValue(TerminalService()),
      syncServiceProvider.overrideWith(
        (ref) => SyncService(connectionRepository),
      ),
      appConfigServiceProvider.overrideWithValue(
        AppConfigService.getInstance(),
      ),
      importExportServiceProvider.overrideWith(
        (ref) => ImportExportService(connectionRepository),
      ),
    ],
    child: const MyApp(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app should launch and show main screen', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('app should have theme support', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
    });
  });
}
