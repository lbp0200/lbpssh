import 'dart:async';

import 'terminal_service.dart';

/// 下划线样式
enum UnderlineStyle {
  none, // 无下划线
  single, // 单线下划线
  double, // 双线下划线
  curly, // 波浪线下划线
  dotted, // 点线下划线
  dashed, // 虚线下划线
  underline, // 粗单线下划线
}

/// 下划线颜色类型
enum UnderlineColor {
  default_, // 默认颜色
  curl, // 使用 curl 颜色
  strike, // 使用删除线颜色
  hyperlink, // 使用超链接颜色
  foreground, // 使用前景色
  background, // 使用背景色
}

/// 下划线配置
class UnderlineConfig {
  final UnderlineStyle style;
  final UnderlineColor color;
  final String? customColor; // 自定义颜色 (如 "#ff0000" 或 "rgb:ff/00/00")

  const UnderlineConfig({
    this.style = UnderlineStyle.none,
    this.color = UnderlineColor.default_,
    this.customColor,
  });
}

/// 下划线服务
///
/// 通过 OSC 4:58 和 OSC 58 控制序列实现下划线样式
class KittyUnderlineService {
  final TerminalSession? _session;

  // 当前下划线配置
  UnderlineConfig _currentConfig = const UnderlineConfig();

  KittyUnderlineService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前下划线配置
  UnderlineConfig get currentConfig => _currentConfig;

  /// 设置下划线样式
  ///
  /// [style] - 下划线样式
  Future<void> setStyle(UnderlineStyle style) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI 4 :58: style
    String styleValue;
    switch (style) {
      case UnderlineStyle.none:
        styleValue = '0';
        break;
      case UnderlineStyle.single:
        styleValue = '1';
        break;
      case UnderlineStyle.double:
        styleValue = '2';
        break;
      case UnderlineStyle.curly:
        styleValue = '3';
        break;
      case UnderlineStyle.dotted:
        styleValue = '4';
        break;
      case UnderlineStyle.dashed:
        styleValue = '5';
        break;
      case UnderlineStyle.underline:
        styleValue = '6';
        break;
    }

    final cmd = '\x1b[4:58:${styleValue}m';
    _session.writeRaw(cmd);

    _currentConfig = UnderlineConfig(
      style: style,
      color: _currentConfig.color,
      customColor: _currentConfig.customColor,
    );
  }

  /// 设置下划线颜色
  ///
  /// [color] - 下划线颜色类型
  /// [customColor] - 自定义颜色 (当 color 为 default_ 时使用)
  Future<void> setColor(UnderlineColor color, {String? customColor}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String colorCode;
    switch (color) {
      case UnderlineColor.default_:
        colorCode = customColor ?? '';
        break;
      case UnderlineColor.curl:
        colorCode = '1';
        break;
      case UnderlineColor.strike:
        colorCode = '2';
        break;
      case UnderlineColor.hyperlink:
        colorCode = '3';
        break;
      case UnderlineColor.foreground:
        colorCode = '4';
        break;
      case UnderlineColor.background:
        colorCode = '5';
        break;
    }

    if (colorCode.isNotEmpty) {
      final cmd = '\x1b[4:58:color=${colorCode}m';
      _session.writeRaw(cmd);
    }

    _currentConfig = UnderlineConfig(
      style: _currentConfig.style,
      color: color,
      customColor: customColor,
    );
  }

  /// 设置下划线颜色为自定义颜色
  ///
  /// [colorSpec] - 颜色规格 (#rrggbb 或 rgb:r/g/b)
  Future<void> setCustomColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换颜色格式
    String converted;
    if (colorSpec.startsWith('#')) {
      // #rrggbb -> rgb:rr/gg/bb
      final hex = colorSpec.substring(1);
      if (hex.length == 6) {
        converted =
            'rgb:${hex.substring(0, 2)}/${hex.substring(2, 4)}/${hex.substring(4, 6)}';
      } else {
        converted = colorSpec;
      }
    } else {
      converted = colorSpec;
    }

    final cmd = '\x1b[4:58:color=${converted}m';
    _session.writeRaw(cmd);

    _currentConfig = UnderlineConfig(
      style: _currentConfig.style,
      color: UnderlineColor.default_,
      customColor: converted,
    );
  }

  /// 设置完整下划线配置
  ///
  /// [config] - 下划线配置
  Future<void> setConfig(UnderlineConfig config) async {
    await setStyle(config.style);
    if (config.customColor != null) {
      await setCustomColor(config.customColor!);
    } else {
      await setColor(config.color);
    }
  }

  /// 禁用下划线
  Future<void> disable() async {
    await setStyle(UnderlineStyle.none);
  }

  /// 使用单线下划线
  Future<void> single() async {
    await setStyle(UnderlineStyle.single);
  }

  /// 使用双线下划线
  Future<void> double_() async {
    await setStyle(UnderlineStyle.double);
  }

  /// 使用波浪线下划线
  Future<void> curly() async {
    await setStyle(UnderlineStyle.curly);
  }

  /// 使用点线下划线
  Future<void> dotted() async {
    await setStyle(UnderlineStyle.dotted);
  }

  /// 使用虚线下划线
  Future<void> dashed() async {
    await setStyle(UnderlineStyle.dashed);
  }

  /// 使用粗下划线
  Future<void> thick() async {
    await setStyle(UnderlineStyle.underline);
  }

  /// 清除下划线颜色 (使用默认)
  Future<void> resetColor() async {
    await setColor(UnderlineColor.default_);
  }

  /// 使用 curl 颜色
  Future<void> useCurlColor() async {
    await setColor(UnderlineColor.curl);
  }

  /// 使用删除线颜色
  Future<void> useStrikeColor() async {
    await setColor(UnderlineColor.strike);
  }

  /// 使用超链接颜色
  Future<void> useHyperlinkColor() async {
    await setColor(UnderlineColor.hyperlink);
  }

  /// 使用前景色
  Future<void> useForegroundColor() async {
    await setColor(UnderlineColor.foreground);
  }

  /// 使用背景色
  Future<void> useBackgroundColor() async {
    await setColor(UnderlineColor.background);
  }

  /// 重置所有属性
  Future<void> reset() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI 4:58:0m - 重置下划线
    _session.writeRaw('\x1b[4:58:0m');
    _currentConfig = const UnderlineConfig();
  }

  /// 使用 SGR 58 设置下划线颜色
  ///
  /// [colorIndex] - 颜色索引 (0-255)
  Future<void> setColorIndex(int colorIndex) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    if (colorIndex < 0 || colorIndex > 255) {
      throw Exception('颜色索引必须在 0-255 之间');
    }

    // SGR 58 - 设置下划线颜色
    final cmd = '\x1b[58:5:${colorIndex}m';
    _session.writeRaw(cmd);
  }

  /// 使用 True Color 设置下划线颜色
  ///
  /// [r] - 红色 (0-255)
  /// [g] - 绿色 (0-255)
  /// [b] - 蓝色 (0-255)
  Future<void> setTrueColor(int r, int g, int b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255) {
      throw Exception('RGB 值必须在 0-255 之间');
    }

    // SGR 58:2 - 设置下划线颜色为 True Color
    final cmd = '\x1b[58:2:$r;$g;${b}m';
    _session.writeRaw(cmd);
  }
}
