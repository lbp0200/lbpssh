import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    AppConfigService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    await AppConfigService.ensureInitialized();
  });

  group('AppConfigService Singleton', () {
    test('Given service, When getInstance called twice, Then returns same instance',
        () {
      final instance1 = AppConfigService.getInstance();
      final instance2 = AppConfigService.getInstance();

      expect(instance1, same(instance2));
    });
  });

  group('AppConfigService Defaults', () {
    test('Given service initialized, When getting terminal config, Then has defaults',
        () {
      final service = AppConfigService.getInstance();

      expect(service.terminal.fontFamily, 'JetBrainsMonoNerdFontMono');
      expect(service.terminal.fontSize, 17.0);
    });

    test('Given service initialized, When getting defaultTerminal config, Then has defaults',
        () {
      final service = AppConfigService.getInstance();

      expect(service.defaultTerminal.execMac, TerminalType.iterm2);
    });

    test('Given service initialized, When getting ssh config, Then has defaults',
        () {
      final service = AppConfigService.getInstance();

      expect(service.ssh.keepaliveInterval, 30000);
    });
  });

  group('AppConfigService Save', () {
    test('Given service, When saving terminal config, Then updates value and notifies',
        () async {
      final service = AppConfigService.getInstance();
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      final newConfig = TerminalConfig(
        fontFamily: 'Fira Code',
        fontSize: 16,
      );
      await service.saveTerminalConfig(newConfig);

      expect(service.terminal.fontFamily, 'Fira Code');
      expect(service.terminal.fontSize, 16);
      expect(notifyCount, 1);

      // Verify persistence by re-initializing
      // Data was saved to SharedPreferences by saveTerminalConfig
      AppConfigService.resetForTesting();
      await AppConfigService.ensureInitialized();
      final freshService = AppConfigService.getInstance();
      expect(freshService.terminal.fontFamily, 'Fira Code');
    });

    test('Given service, When saving defaultTerminal config, Then updates value and notifies',
        () async {
      final service = AppConfigService.getInstance();
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      final newConfig = DefaultTerminalConfig(execMac: TerminalType.alacritty);
      await service.saveDefaultTerminalConfig(newConfig);

      expect(service.defaultTerminal.execMac, TerminalType.alacritty);
      expect(notifyCount, 1);
    });

    test('Given service, When saving ssh config, Then updates value and notifies', () async {
      final service = AppConfigService.getInstance();
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      final newConfig = SshConfig(keepaliveInterval: 60000);
      await service.saveSshConfig(newConfig);

      expect(service.ssh.keepaliveInterval, 60000);
      expect(notifyCount, 1);
    });
  });

  group('AppConfigService Reset', () {
    test('Given modified config, When resetting to defaults, Then restores defaults',
        () async {
      final service = AppConfigService.getInstance();
      final terminalConfig = TerminalConfig(fontSize: 24);
      await service.saveTerminalConfig(terminalConfig);
      expect(service.terminal.fontSize, 24);

      await service.resetToDefaults();

      expect(service.terminal.fontSize, 17.0);
      expect(service.defaultTerminal.execMac, TerminalType.iterm2);
      expect(service.ssh.keepaliveInterval, 30000);
    });
  });

  group('AppConfigService Export/Import', () {
    test('Given config, When exporting, Then returns valid JSON string',
        () {
      final service = AppConfigService.getInstance();

      final exported = service.exportConfig();

      expect(exported, isA<String>());
      expect(exported.contains('terminal'), true);
      expect(exported.contains('defaultTerminal'), true);
      expect(exported.contains('ssh'), true);
    });

    test('Given exported JSON, When importing, Then restores config values',
        () async {
      final service = AppConfigService.getInstance();

      // Modify and export
      await service.saveTerminalConfig(TerminalConfig(fontFamily: 'Monaco'));
      final exported = service.exportConfig();

      // Reset and import
      AppConfigService.resetForTesting();
      SharedPreferences.setMockInitialValues({});
      await AppConfigService.ensureInitialized();
      final freshService = AppConfigService.getInstance();
      await freshService.importConfig(exported);

      expect(freshService.terminal.fontFamily, 'Monaco');
    });
  });

  group('AppConfigService Initialization from Prefs', () {
    test('Given saved config in SharedPreferences, When initializing, Then loads saved values',
        () async {
      // Set up SharedPreferences with saved config using jsonEncode
      final prefs = await SharedPreferences.getInstance();
      final savedConfig = AppConfig(
        terminal: TerminalConfig(fontFamily: 'SavedFont'),
      );
      await prefs.setString(
        'app_config',
        jsonEncode(savedConfig.toJson()),
      );

      // Re-initialize
      AppConfigService.resetForTesting();
      await AppConfigService.ensureInitialized();
      final service = AppConfigService.getInstance();

      expect(service.terminal.fontFamily, 'SavedFont');
    });

    test('Given corrupted config in SharedPreferences, When initializing, Then uses defaults',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ssh_app_config', 'not valid json');

      AppConfigService.resetForTesting();
      await AppConfigService.ensureInitialized();
      final service = AppConfigService.getInstance();

      expect(service.terminal.fontFamily, 'JetBrainsMonoNerdFontMono');
    });
  });
}
