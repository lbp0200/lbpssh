import 'package:flutter/material.dart';
import 'package:kterm/kterm.dart';
import '../../data/models/terminal_config.dart';
import '../../utils/color_utils.dart';

Color _c(String hex) => ColorUtils.parseColorCached(hex);

TerminalTheme terminalThemeFromConfig(TerminalConfig config) {
  return TerminalTheme(
    foreground: _c(config.foregroundColor),
    background: _c(config.backgroundColor),
    cursor: _c(config.cursorColor),
    selection: _c(config.foregroundColor).withValues(alpha: 0.3),
    black: _c('#000000'),
    red: _c('#CD3131'),
    green: _c('#0DBC79'),
    yellow: _c('#E5E510'),
    blue: _c('#2472C8'),
    magenta: _c('#BC3FBC'),
    cyan: _c('#11A8CD'),
    white: _c('#E5E5E5'),
    brightBlack: _c('#666666'),
    brightRed: _c('#F14C4C'),
    brightGreen: _c('#23D18B'),
    brightYellow: _c('#F5F543'),
    brightBlue: _c('#3B8EEA'),
    brightMagenta: _c('#D670D6'),
    brightCyan: _c('#29B8DB'),
    brightWhite: _c('#E5E5E5'),
    searchHitBackground: _c('#FFFF00').withValues(alpha: 0.3),
    searchHitBackgroundCurrent: _c('#FFFF00').withValues(alpha: 0.5),
    searchHitForeground: _c('#000000'),
  );
}
