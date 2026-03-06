import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/default_terminal_config.dart';

void main() {
  group('DefaultTerminalConfig', () {
    test(
        'Given no arguments, When creating DefaultTerminalConfig, Then uses default values',
        () {
      final config = DefaultTerminalConfig();

      expect(config.execWindows, TerminalType.windowsTerminal);
      expect(config.execWindowsCustom, isNull);
      expect(config.execMac, TerminalType.iterm2);
      expect(config.execMacCustom, isNull);
      expect(config.execLinux, TerminalType.terminal);
      expect(config.execLinuxCustom, isNull);
    });

    test(
        'Given custom terminal types, When creating DefaultTerminalConfig, Then uses custom values',
        () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.powershell,
        execWindowsCustom: 'custom.exe',
        execMac: TerminalType.alacritty,
        execMacCustom: '/usr/bin/alacritty',
        execLinux: TerminalType.kitty,
        execLinuxCustom: '/usr/bin/kitty',
      );

      expect(config.execWindows, TerminalType.powershell);
      expect(config.execWindowsCustom, 'custom.exe');
      expect(config.execMac, TerminalType.alacritty);
      expect(config.execMacCustom, '/usr/bin/alacritty');
      expect(config.execLinux, TerminalType.kitty);
      expect(config.execLinuxCustom, '/usr/bin/kitty');
    });

    test(
        'Given DefaultTerminalConfig, When serializing to JSON, Then produces correct JSON',
        () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.cmd,
        execMac: TerminalType.wezterm,
        execLinux: TerminalType.alacritty,
      );

      final json = config.toJson();

      expect(json['execWindows'], 'cmd');
      expect(json['execMac'], 'wezterm');
      expect(json['execLinux'], 'alacritty');
    });

    test(
        'Given valid JSON, When deserializing, Then creates DefaultTerminalConfig correctly',
        () {
      final json = {
        'execWindows': 'powershell',
        'execWindowsCustom': 'pwsh.exe',
        'execMac': 'terminal',
        'execMacCustom': 'open -b com.apple.terminal',
        'execLinux': 'wezterm',
        'execLinuxCustom': 'wezterm',
      };

      final config = DefaultTerminalConfig.fromJson(json);

      expect(config.execWindows, TerminalType.powershell);
      expect(config.execWindowsCustom, 'pwsh.exe');
      expect(config.execMac, TerminalType.terminal);
      expect(config.execMacCustom, 'open -b com.apple.terminal');
      expect(config.execLinux, TerminalType.wezterm);
      expect(config.execLinuxCustom, 'wezterm');
    });

    test(
        'Given DefaultTerminalConfig, When serializing and deserializing, Then preserves all fields',
        () {
      final original = DefaultTerminalConfig(
        execWindows: TerminalType.custom,
        execWindowsCustom: 'custom_windows.exe',
        execMac: TerminalType.custom,
        execMacCustom: 'custom_mac.app',
        execLinux: TerminalType.custom,
        execLinuxCustom: 'custom_linux',
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

    test(
        'Given original config, When calling copyWith, Then creates modified copy',
        () {
      final original = DefaultTerminalConfig();

      final modified = original.copyWith(
        execMac: TerminalType.kitty,
        execLinux: TerminalType.wezterm,
      );

      expect(modified.execMac, TerminalType.kitty);
      expect(modified.execLinux, TerminalType.wezterm);
      expect(modified.execWindows, original.execWindows);
    });

    test(
        'Given powershell terminal type, When calling getWindowsCommand, Then returns powershell.exe',
        () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.powershell);
      expect(config.getWindowsCommand(), 'powershell.exe');
    });

    test(
        'Given cmd terminal type, When calling getWindowsCommand, Then returns cmd.exe',
        () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.cmd);
      expect(config.getWindowsCommand(), 'cmd.exe');
    });

    test(
        'Given windowsTerminal terminal type, When calling getWindowsCommand, Then returns wt.exe',
        () {
      final config = DefaultTerminalConfig(execWindows: TerminalType.windowsTerminal);
      expect(config.getWindowsCommand(), 'wt.exe');
    });

    test(
        'Given custom terminal type, When calling getWindowsCommand, Then returns custom command',
        () {
      final config = DefaultTerminalConfig(
        execWindows: TerminalType.custom,
        execWindowsCustom: 'custom_terminal.exe',
      );
      expect(config.getWindowsCommand(), 'custom_terminal.exe');
    });

    test(
        'Given terminal terminal type, When calling getMacCommand, Then returns open command',
        () {
      final config = DefaultTerminalConfig(execMac: TerminalType.terminal);
      expect(config.getMacCommand(), 'open -b com.apple.terminal');
    });

    test(
        'Given iterm2 terminal type, When calling getMacCommand, Then returns iTerm command',
        () {
      final config = DefaultTerminalConfig(execMac: TerminalType.iterm2);
      expect(config.getMacCommand(), 'open -a iTerm');
    });

    test(
        'Given alacritty terminal type, When calling getMacCommand, Then returns Alacritty command',
        () {
      final config = DefaultTerminalConfig(execMac: TerminalType.alacritty);
      expect(config.getMacCommand(), 'open -a Alacritty');
    });

    test(
        'Given kitty terminal type, When calling getMacCommand, Then returns kitty command',
        () {
      final config = DefaultTerminalConfig(execMac: TerminalType.kitty);
      expect(config.getMacCommand(), 'open -a kitty');
    });

    test(
        'Given wezterm terminal type, When calling getMacCommand, Then returns WezTerm command',
        () {
      final config = DefaultTerminalConfig(execMac: TerminalType.wezterm);
      expect(config.getMacCommand(), 'open -a WezTerm');
    });

    test(
        'Given custom terminal type, When calling getMacCommand, Then returns custom command',
        () {
      final config = DefaultTerminalConfig(
        execMac: TerminalType.custom,
        execMacCustom: '/Applications/Custom.app',
      );
      expect(config.getMacCommand(), '/Applications/Custom.app');
    });

    test(
        'Given terminal terminal type, When calling getLinuxCommand, Then returns x-terminal-emulator',
        () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.terminal);
      expect(config.getLinuxCommand(), 'x-terminal-emulator');
    });

    test(
        'Given alacritty terminal type, When calling getLinuxCommand, Then returns alacritty',
        () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.alacritty);
      expect(config.getLinuxCommand(), 'alacritty');
    });

    test(
        'Given kitty terminal type, When calling getLinuxCommand, Then returns kitty',
        () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.kitty);
      expect(config.getLinuxCommand(), 'kitty');
    });

    test(
        'Given wezterm terminal type, When calling getLinuxCommand, Then returns wezterm',
        () {
      final config = DefaultTerminalConfig(execLinux: TerminalType.wezterm);
      expect(config.getLinuxCommand(), 'wezterm');
    });

    test(
        'Given custom terminal type, When calling getLinuxCommand, Then returns custom command',
        () {
      final config = DefaultTerminalConfig(
        execLinux: TerminalType.custom,
        execLinuxCustom: '/usr/bin/custom',
      );
      expect(config.getLinuxCommand(), '/usr/bin/custom');
    });

    test(
        'Given DefaultTerminalConfig, When accessing defaultConfig, Then returns default config',
        () {
      final defaultConfig = DefaultTerminalConfig.defaultConfig;

      expect(defaultConfig, isA<DefaultTerminalConfig>());
      expect(defaultConfig.execMac, TerminalType.iterm2);
      expect(defaultConfig.execWindows, TerminalType.windowsTerminal);
      expect(defaultConfig.execLinux, TerminalType.terminal);
    });
  });
}
