import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/terminal_config.dart';

/// 终端预览组件：从 terminal_settings_page.dart 抽离，降低长文件复杂度
/// 展示背景/前景色、字体、间距、光标等配置的实时预览
class TerminalPreview extends StatelessWidget {
  final TerminalConfig config;
  final ValueChanged<double> onFontSizeChanged;

  const TerminalPreview({
    super.key,
    required this.config,
    required this.onFontSizeChanged,
  });

  static Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      // 无效颜色配置属用户数据问题，build 路径只记录日志，不上报
      debugPrint('[TerminalPreview] invalid color hex: $e');
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(config.backgroundColor);
    final fgColor = _parseColor(config.foregroundColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '终端预览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: LinearColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              '提示：使用下方按钮或滑块调整字体大小',
              style: TextStyle(fontSize: 11, color: LinearColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: LinearSpacing.spacing12),
        Container(
          height: 200,
          padding: EdgeInsets.all(config.padding.toDouble()),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: LinearColors.borderStandard),
            borderRadius: BorderRadius.circular(LinearRadius.card),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _previewLine('user@hostname:~\$', fgColor),
                _previewLine('user@hostname:~\$ ls -la', fgColor),
                _previewLine('total 24', fgColor.withValues(alpha: 0.7)),
                _previewLine(
                  'drwxr-xr-x  5 user  group  160 Jan 15 10:30 .',
                  fgColor.withValues(alpha: 0.7),
                ),
                _previewLine(
                  'drwxr-xr-x  3 root  root   100 Jan 15 10:30 ..',
                  fgColor.withValues(alpha: 0.7),
                ),
                _previewLine(
                  '-rw-r--r--  1 user  group  220 Jan 15 10:30 .bashrc',
                  fgColor.withValues(alpha: 0.7),
                ),
                _previewLine(
                  '-rw-r--r--  1 user  group  655 Jan 15 10:30 config.json',
                  fgColor.withValues(alpha: 0.7),
                ),
                _previewLine('user@hostname:~\$ _', fgColor, showCursor: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: LinearSpacing.spacing8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => onFontSizeChanged(config.fontSize - 2),
              icon: const Icon(Icons.text_decrease, size: 18),
              label: const Text('缩小'),
            ),
            const SizedBox(width: LinearSpacing.spacing16),
            FilledButton.tonal(
              onPressed: () => onFontSizeChanged(14),
              child: const Text('默认 (14px)'),
            ),
            const SizedBox(width: LinearSpacing.spacing16),
            FilledButton.tonalIcon(
              onPressed: () => onFontSizeChanged(config.fontSize + 2),
              icon: const Icon(Icons.text_increase, size: 18),
              label: const Text('放大'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewLine(String text, Color color, {bool showCursor = false}) {
    // Text 置于 Expanded 中：作为 Row 的弹性子项，在可用宽度内软换行。
    // 否则会拿到无界宽度，大字号下长样本行超出固定宽度容器触发 RenderFlex 横向溢出（debug 红屏）。
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: config.fontFamily.isNotEmpty
                  ? config.fontFamily
                  : null,
              fontSize: config.fontSize,
              height: config.lineHeight,
              color: color,
              letterSpacing: config.letterSpacing,
            ),
          ),
        ),
        if (showCursor)
          Container(
            width: config.fontSize * 0.6,
            height: config.fontSize,
            color: _parseColor(config.cursorColor),
            margin: const EdgeInsets.only(left: 2),
          ),
      ],
    );
  }
}
