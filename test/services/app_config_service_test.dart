import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';

void main() {
  group('AppConfig', () {
    test(
        'Given no arguments, When creating AppConfig, Then uses default values',
        () {
      final config = AppConfig();

      expect(config.terminal.fontFamily, 'JetBrainsMonoNerdFontMono');
      expect(config.defaultTerminal.execMac, TerminalType.iterm2);
    });

    test(
        'Given custom terminal config, When creating AppConfig, Then uses custom values',
        () {
      final terminalConfig = TerminalConfig(
        fontFamily: 'Fira Code',
        fontSize: 14,
      );

      final config = AppConfig(terminal: terminalConfig);

      expect(config.terminal.fontFamily, 'Fira Code');
      expect(config.terminal.fontSize, 14);
    });

    test('Given AppConfig, When serializing to JSON, Then produces correct JSON',
        () {
      final config = AppConfig();

      final json = config.toJson();

      expect(json.containsKey('terminal'), true);
      expect(json.containsKey('defaultTerminal'), true);
      expect(json['terminal']['fontFamily'], 'JetBrainsMonoNerdFontMono');
    });

    test(
        'Given valid JSON, When deserializing, Then creates AppConfig correctly',
        () {
      final json = {
        'terminal': {
          'fontFamily': 'Consolas',
          'fontSize': 16,
          'fontWeight': 400,
          'letterSpacing': 0.0,
          'lineHeight': 1.0,
          'backgroundColor': '#000000',
          'foregroundColor': '#FFFFFF',
          'cursorColor': '#FFFFFF',
          'cursorBlinkInterval': 500,
          'padding': 8,
          'devicePixelRatio': 1.0,
          'shellPath': '/bin/bash',
        },
        'defaultTerminal': {
          'execWindows': 'powershell',
          'execMac': 'alacritty',
          'execLinux': 'kitty',
        },
      };

      final config = AppConfig.fromJson(json);

      expect(config.terminal.fontFamily, 'Consolas');
      expect(config.terminal.fontSize, 16);
      expect(config.terminal.shellPath, '/bin/bash');
      expect(config.defaultTerminal.execMac, TerminalType.alacritty);
    });

    test(
        'Given null values in JSON, When deserializing, Then uses default values',
        () {
      final json = {
        'terminal': null,
        'defaultTerminal': null,
      };

      final config = AppConfig.fromJson(json);

      expect(config.terminal, isNotNull);
      expect(config.defaultTerminal, isNotNull);
    });
  });

  group('TerminalConfig Serialization', () {
    test(
        'Given TerminalConfig, When serializing and deserializing, Then preserves all fields',
        () {
      final original = TerminalConfig(
        fontFamily: 'Source Code Pro',
        fontSize: 15,
        fontWeight: 500,
        letterSpacing: 0.5,
        lineHeight: 1.2,
        backgroundColor: '#1E1E2E',
        foregroundColor: '#CDD6F4',
        cursorColor: '#F5E0DC',
        cursorBlinkInterval: 750,
        padding: 12,
        devicePixelRatio: 1.5,
        shellPath: '/usr/bin/zsh',
      );

      final json = original.toJson();
      final deserialized = TerminalConfig.fromJson(json);

      expect(deserialized.fontFamily, original.fontFamily);
      expect(deserialized.fontSize, original.fontSize);
      expect(deserialized.fontWeight, original.fontWeight);
      expect(deserialized.letterSpacing, original.letterSpacing);
      expect(deserialized.lineHeight, original.lineHeight);
      expect(deserialized.backgroundColor, original.backgroundColor);
      expect(deserialized.foregroundColor, original.foregroundColor);
      expect(deserialized.cursorColor, original.cursorColor);
      expect(deserialized.cursorBlinkInterval, original.cursorBlinkInterval);
      expect(deserialized.padding, original.padding);
      expect(deserialized.devicePixelRatio, original.devicePixelRatio);
      expect(deserialized.shellPath, original.shellPath);
    });
  });

  group('DefaultTerminalConfig Serialization', () {
    test(
        'Given DefaultTerminalConfig, When serializing and deserializing, Then preserves all fields',
        () {
      final original = DefaultTerminalConfig(
        execWindows: TerminalType.powershell,
        execWindowsCustom: 'pwsh.exe',
        execMac: TerminalType.wezterm,
        execMacCustom: '/Applications/WezTerm.app',
        execLinux: TerminalType.alacritty,
        execLinuxCustom: '/usr/bin/alacritty',
      );

      final json = original.toJson();
      final deserialized = DefaultTerminalConfig.fromJson(json);

      expect(deserialized.execWindows, original.execWindows);
      expect(deserialized.execWindowsCustom, original.execWindowsCustom);
      expect(deserialized.execMac, original.execMac);
      expect(deserialized.execMacCustom, original.execMacCustom);
      expect(deserialized.execLinux, original.execLinux);
      expect(deserialized.execLinuxCustom, original.execLinuxCustom);
    });
  });
}
