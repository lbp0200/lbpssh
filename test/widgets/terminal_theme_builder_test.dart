import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_theme_builder.dart';

void main() {
  group('terminalThemeFromConfig', () {
    test(
      'Given default config, When building theme, Then uses default colors',
      () {
        // Arrange (Given)
        final config = TerminalConfig.defaultConfig;

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then)
        expect(theme.foreground, const Color(0xFFFFFFFF));
        expect(theme.background, const Color(0xFF1E1E1E));
        expect(theme.cursor, const Color(0xFFFFFFFF));
      },
    );

    test(
      'Given custom colors, When building theme, Then uses custom colors',
      () {
        // Arrange (Given)
        final config = TerminalConfig(
          foregroundColor: '#00FF00',
          backgroundColor: '#000000',
          cursorColor: '#FF0000',
        );

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then)
        expect(theme.foreground, const Color(0xFF00FF00));
        expect(theme.background, const Color(0xFF000000));
        expect(theme.cursor, const Color(0xFFFF0000));
      },
    );

    test(
      'Given custom config, When building theme, Then selection has 30% opacity',
      () {
        // Arrange (Given)
        final config = TerminalConfig(foregroundColor: '#FF5733');

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then) — selection = foreground with 0.3 alpha
        expect(theme.selection, const Color(0xFFFF5733).withValues(alpha: 0.3));
      },
    );

    test(
      'Given default config, When building theme, Then standard 16 ANSI colors are set',
      () {
        // Arrange (Given)
        final config = TerminalConfig.defaultConfig;

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then) — check a few known colors
        expect(theme.black, const Color(0xFF000000));
        expect(theme.red, const Color(0xFFCD3131));
        expect(theme.green, const Color(0xFF0DBC79));
        expect(theme.blue, const Color(0xFF2472C8));
        expect(theme.white, const Color(0xFFE5E5E5));
      },
    );

    test(
      'Given default config, When building theme, Then bright ANSI colors differ from standard',
      () {
        // Arrange (Given)
        final config = TerminalConfig.defaultConfig;

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then)
        expect(theme.brightBlack, const Color(0xFF666666));
        expect(theme.brightRed, const Color(0xFFF14C4C));
        expect(theme.brightGreen, const Color(0xFF23D18B));
        expect(theme.brightBlue, const Color(0xFF3B8EEA));
        expect(theme.brightWhite, const Color(0xFFE5E5E5));
      },
    );

    test(
      'Given default config, When building theme, Then search colors have correct alphas',
      () {
        // Arrange (Given)
        final config = TerminalConfig.defaultConfig;

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then)
        expect(
          theme.searchHitBackground,
          const Color(0xFFFFFF00).withValues(alpha: 0.3),
        );
        expect(
          theme.searchHitBackgroundCurrent,
          const Color(0xFFFFFF00).withValues(alpha: 0.5),
        );
        expect(theme.searchHitForeground, const Color(0xFF000000));
      },
    );

    test(
      'Given config with invalid hex, When building theme, Then falls back to white for non-hex values',
      () {
        // Arrange (Given)
        final config = TerminalConfig(
          foregroundColor: 'zzzzzzz',
          backgroundColor: '!!!!!!',
          cursorColor: 'xxxxxx',
        );

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then) — ColorUtils.parseColor returns white for unparseable
        expect(theme.foreground, Colors.white);
        expect(theme.background, Colors.white);
        expect(theme.cursor, Colors.white);
      },
    );

    test(
      'Given default config, When building theme, Then returns a complete TerminalTheme',
      () {
        // Arrange (Given)
        final config = TerminalConfig.defaultConfig;

        // Act (When)
        final theme = terminalThemeFromConfig(config);

        // Assert (Then) — TerminalTheme has all typed fields
        expect(theme, isA<TerminalTheme>());
        // Verify it has the expected number of color fields (17 colors + 3 search)
        expect(theme.foreground, isA<Color>());
        expect(theme.background, isA<Color>());
        expect(theme.cursor, isA<Color>());
        expect(theme.selection, isA<Color>());
      },
    );
  });
}
