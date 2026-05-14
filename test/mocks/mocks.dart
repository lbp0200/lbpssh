// Mocks for testing
// Use mocktail for mocking - no code generation required
//
// Example usage:
// import 'package:mocktail/mocktail.dart';
// import 'package:lbp_ssh/test/mocks/mocks.dart';
//
// class MockConnectionRepository extends Mock implements ConnectionRepository {}
// class MockSyncService extends Mock implements SyncService {}

import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';

// Export mocktail for convenience
export 'package:mocktail/mocktail.dart' hide Mock;

// Mock classes
class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockSyncService extends Mock implements SyncService {}

class MockImportExportService extends Mock implements ImportExportService {}

class MockAppConfigService extends Mock implements AppConfigService {}

// Register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(
    SyncConfig(
      platform: SyncPlatform.githubRepo,
      accessToken: 'test_token',
      repoOwner: 'test_owner',
      repoName: 'test_repo',
    ),
  );
  registerFallbackValue(
    SshConnection(
      id: 'test_id',
      name: 'Test Server',
      host: '192.168.1.1',
      port: 22,
      username: 'testuser',
      authType: AuthType.password,
    ),
  );
  registerFallbackValue(TerminalConfig.defaultConfig);
  registerFallbackValue(DefaultTerminalConfig.defaultConfig);
}
