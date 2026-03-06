import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';

void main() {
  group('TerminalConfig', () {
    test(
        'Given no arguments, When creating TerminalConfig, Then uses default values',
        () {
      final config = TerminalConfig();

      expect(config.fontFamily, 'JetBrainsMonoNerdFontMono');
      expect(config.fontSize, 17.0);
      expect(config.fontWeight, 400);
      expect(config.letterSpacing, 0.0);
      expect(config.lineHeight, 1.2);
      expect(config.backgroundColor, '#1E1E1E');
      expect(config.foregroundColor, '#FFFFFF');
      expect(config.cursorColor, '#FFFFFF');
      expect(config.cursorBlinkInterval, 500);
      expect(config.padding, 8);
      expect(config.devicePixelRatio, 1.0);
      expect(config.shellPath, '');
    });

    test(
        'Given custom values, When creating TerminalConfig, Then uses custom values',
        () {
      final config = TerminalConfig(
        fontFamily: 'Courier New',
        fontSize: 16.0,
        fontWeight: 600,
        letterSpacing: 1.0,
        lineHeight: 1.5,
        backgroundColor: '#000000',
        foregroundColor: '#00FF00',
        cursorColor: '#00FF00',
        cursorBlinkInterval: 1000,
        padding: 16,
        devicePixelRatio: 2.0,
        shellPath: '/bin/bash',
      );

      expect(config.fontFamily, 'Courier New');
      expect(config.fontSize, 16.0);
      expect(config.fontWeight, 600);
      expect(config.letterSpacing, 1.0);
      expect(config.lineHeight, 1.5);
      expect(config.backgroundColor, '#000000');
      expect(config.foregroundColor, '#00FF00');
      expect(config.cursorColor, '#00FF00');
      expect(config.cursorBlinkInterval, 1000);
      expect(config.padding, 16);
      expect(config.devicePixelRatio, 2.0);
      expect(config.shellPath, '/bin/bash');
    });

    test('Given TerminalConfig, When serializing to JSON, Then produces correct JSON',
        () {
      final config = TerminalConfig(
        fontFamily: 'JetBrainsMonoNerdFontMono',
        fontSize: 14.0,
        fontWeight: 400,
        letterSpacing: 0.5,
        lineHeight: 1.2,
        backgroundColor: '#1E1E1E',
        foregroundColor: '#FFFFFF',
        cursorColor: '#FFFFFF',
        cursorBlinkInterval: 500,
        padding: 8,
        devicePixelRatio: 1.0,
        shellPath: '',
      );

      final json = config.toJson();

      expect(json['fontFamily'], 'JetBrainsMonoNerdFontMono');
      expect(json['fontSize'], 14.0);
      expect(json['fontWeight'], 400);
      expect(json['letterSpacing'], 0.5);
      expect(json['lineHeight'], 1.2);
      expect(json['backgroundColor'], '#1E1E1E');
      expect(json['foregroundColor'], '#FFFFFF');
      expect(json['cursorColor'], '#FFFFFF');
      expect(json['cursorBlinkInterval'], 500);
      expect(json['padding'], 8);
      expect(json['devicePixelRatio'], 1.0);
      expect(json['shellPath'], '');
    });

    test('Given valid JSON, When deserializing, Then creates TerminalConfig correctly',
        () {
      final json = {
        'fontFamily': 'Consolas',
        'fontSize': 18.0,
        'fontWeight': 700,
        'letterSpacing': 0.0,
        'lineHeight': 1.0,
        'backgroundColor': '#2D2D2D',
        'foregroundColor': '#E0E0E0',
        'cursorColor': '#FF0000',
        'cursorBlinkInterval': 800,
        'padding': 12,
        'devicePixelRatio': 1.5,
        'shellPath': '/usr/bin/zsh',
      };

      final config = TerminalConfig.fromJson(json);

      expect(config.fontFamily, 'Consolas');
      expect(config.fontSize, 18.0);
      expect(config.fontWeight, 700);
      expect(config.letterSpacing, 0.0);
      expect(config.lineHeight, 1.0);
      expect(config.backgroundColor, '#2D2D2D');
      expect(config.foregroundColor, '#E0E0E0');
      expect(config.cursorColor, '#FF0000');
      expect(config.cursorBlinkInterval, 800);
      expect(config.padding, 12);
      expect(config.devicePixelRatio, 1.5);
      expect(config.shellPath, '/usr/bin/zsh');
    });

    test(
        'Given TerminalConfig, When serializing and deserializing, Then preserves all fields',
        () {
      final original = TerminalConfig(
        fontFamily: 'Fira Code',
        fontSize: 12.0,
        fontWeight: 500,
        letterSpacing: 0.8,
        lineHeight: 1.4,
        backgroundColor: '#1A1A2E',
        foregroundColor: '#E6E6FA',
        cursorColor: '#00FFFF',
        cursorBlinkInterval: 300,
        padding: 4,
        devicePixelRatio: 2.0,
        shellPath: '/bin/sh',
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

    test(
        'Given original config, When calling copyWith with new values, Then updates only specified fields',
        () {
      final original = TerminalConfig();

      final modified = original.copyWith(
        fontSize: 20.0,
        backgroundColor: '#000000',
        shellPath: '/bin/bash',
      );

      expect(modified.fontSize, 20.0);
      expect(modified.backgroundColor, '#000000');
      expect(modified.shellPath, '/bin/bash');
      expect(modified.fontFamily, original.fontFamily);
      expect(modified.foregroundColor, original.foregroundColor);
    });

    test(
        'Given config with custom fontSize, When calling copyWith, Then original is not modified',
        () {
      final original = TerminalConfig(fontSize: 13.0);
      final copy = original.copyWith(fontSize: 16.0);

      expect(original.fontSize, 13.0);
      expect(copy.fontSize, 16.0);
    });

    test('Given TerminalConfig, When accessing defaultConfig, Then returns default config',
        () {
      final defaultConfig = TerminalConfig.defaultConfig;

      expect(defaultConfig, isA<TerminalConfig>());
      expect(defaultConfig.fontFamily, 'JetBrainsMonoNerdFontMono');
      expect(defaultConfig.fontSize, 17.0);
      expect(defaultConfig.lineHeight, 1.2);
      expect(defaultConfig.backgroundColor, '#1E1E1E');
    });

    test(
        'Given no arguments, When creating TerminalConfig, Then has default fontSize 17 and lineHeight 1.2',
        () {
      final config = TerminalConfig();

      expect(config.fontSize, 17.0);
      expect(config.lineHeight, 1.2);
    });
  });
}
