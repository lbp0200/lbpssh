import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/app_config_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';

class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late MockAppConfigService mockService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(TerminalConfig.defaultConfig);
    registerFallbackValue(DefaultTerminalConfig.defaultConfig);
    registerFallbackValue(SshConfig.defaultConfig);
  });

  setUp(() {
    mockService = MockAppConfigService();
    when(() => mockService.terminal).thenReturn(TerminalConfig.defaultConfig);
    when(() => mockService.defaultTerminal).thenReturn(DefaultTerminalConfig.defaultConfig);
    when(() => mockService.ssh).thenReturn(SshConfig.defaultConfig);
  });

  tearDown(() {
    container.dispose();
  });

  group('terminalConfigProvider', () {
    test('should load initial config', () {
      container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(mockService),
        ],
      );

      final config = container.read(terminalConfigProvider);
      expect(config.fontSize, 17);
    });

    test('should update config', () async {
      container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.saveTerminalConfig(any())).thenAnswer((_) async {});

      final notifier = container.read(terminalConfigProvider.notifier);
      await notifier.updateFontSize(20);

      final config = container.read(terminalConfigProvider);
      expect(config.fontSize, 20);
      verify(() => mockService.saveTerminalConfig(any())).called(1);
    });
  });

  group('defaultTerminalConfigProvider', () {
    test('should load initial default terminal config', () {
      container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(mockService),
        ],
      );

      final config = container.read(defaultTerminalConfigProvider);
      expect(config.execMac, TerminalType.iterm2);
    });
  });

  group('sshConfigProvider', () {
    test('should load initial ssh config', () {
      container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(mockService),
        ],
      );

      final config = container.read(sshConfigProvider);
      expect(config.keepaliveInterval, 30000);
    });

    test('should update ssh config', () async {
      container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.saveSshConfig(any())).thenAnswer((_) async {});

      final notifier = container.read(sshConfigProvider.notifier);
      final newConfig = SshConfig(keepaliveInterval: 60000);
      await notifier.updateConfig(newConfig);

      final config = container.read(sshConfigProvider);
      expect(config.keepaliveInterval, 60000);
      verify(() => mockService.saveSshConfig(any())).called(1);
    });
  });
}
