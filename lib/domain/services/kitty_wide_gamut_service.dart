import 'dart:async';

import 'terminal_service.dart';

/// 颜色空间
enum ColorSpace {
  sRGB, // 标准 RGB
  displayP3, // Display P3
  rec2020, // REC.2020
  a98RGB, // Adobe RGB 98
  proPhoto, // ProPhoto RGB
}

/// 颜色配置文件
class ColorProfile {
  final ColorSpace space;
  final double? redX;
  final double? redY;
  final double? greenX;
  final double? greenY;
  final double? blueX;
  final double? blueY;
  final double? whiteX;
  final double? whiteY;
  final double? gamma;

  const ColorProfile({
    required this.space,
    this.redX,
    this.redY,
    this.greenX,
    this.greenY,
    this.blueX,
    this.blueY,
    this.whiteX,
    this.whiteY,
    this.gamma,
  });
}

/// 广色域服务
///
/// 实现终端广色域颜色支持
class KittyWideGamutService {
  final TerminalSession? _session;

  // 当前颜色配置
  ColorProfile _currentProfile = const ColorProfile(space: ColorSpace.sRGB);

  KittyWideGamutService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前颜色配置
  ColorProfile get currentProfile => _currentProfile;

  /// 设置颜色空间
  ///
  /// [space] - 颜色空间
  Future<void> setColorSpace(ColorSpace space) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String spaceStr;
    switch (space) {
      case ColorSpace.sRGB:
        spaceStr = 'srgb';
        break;
      case ColorSpace.displayP3:
        spaceStr = 'display-p3';
        break;
      case ColorSpace.rec2020:
        spaceStr = 'rec2020';
        break;
      case ColorSpace.a98RGB:
        spaceStr = 'a98rgb';
        break;
      case ColorSpace.proPhoto:
        spaceStr = 'prophoto';
        break;
    }

    // OSC 10 ; colorspace=space
    final cmd = '\x1b]10;colorspace=$spaceStr\x1b\\\\';
    _session.writeRaw(cmd);

    _currentProfile = ColorProfile(space: space);
  }

  /// 使用 sRGB 颜色空间
  Future<void> useSRGB() async {
    await setColorSpace(ColorSpace.sRGB);
  }

  /// 使用 Display P3 颜色空间
  Future<void> useDisplayP3() async {
    await setColorSpace(ColorSpace.displayP3);
  }

  /// 使用 REC.2020 颜色空间
  Future<void> useRec2020() async {
    await setColorSpace(ColorSpace.rec2020);
  }

  /// 使用 Adobe RGB 98 颜色空间
  Future<void> useA98RGB() async {
    await setColorSpace(ColorSpace.a98RGB);
  }

  /// 使用 ProPhoto RGB 颜色空间
  Future<void> useProPhoto() async {
    await setColorSpace(ColorSpace.proPhoto);
  }

  /// 设置自定义颜色配置文件
  ///
  /// [profile] - 颜色配置文件
  Future<void> setCustomProfile(ColorProfile profile) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 10 ; profile=custom
    String cmd = '\x1b]10;profile=custom';

    if (profile.redX != null && profile.redY != null) {
      cmd += ';r=${profile.redX},${profile.redY}';
    }
    if (profile.greenX != null && profile.greenY != null) {
      cmd += ';g=${profile.greenX},${profile.greenY}';
    }
    if (profile.blueX != null && profile.blueY != null) {
      cmd += ';b=${profile.blueX},${profile.blueY}';
    }
    if (profile.whiteX != null && profile.whiteY != null) {
      cmd += ';w=${profile.whiteX},${profile.whiteY}';
    }
    if (profile.gamma != null) {
      cmd += ';gamma=${profile.gamma}';
    }

    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);

    _currentProfile = profile;
  }

  /// 设置前景色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setForegroundColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // CSI 38:2: r: g: b m - True Color
    final cmd = '\x1b[38:2:$ri:$gi:${bi}m';
    _session.writeRaw(cmd);
  }

  /// 设置背景色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setBackgroundColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // CSI 48:2: r: g: b m - True Color
    final cmd = '\x1b[48:2:$ri:$gi:${bi}m';
    _session.writeRaw(cmd);
  }

  /// 设置下划线颜色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setUnderlineColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // CSI 58:2: r: g: b m - 下划线颜色
    final cmd = '\x1b[58:2:$ri:$gi:${bi}m';
    _session.writeRaw(cmd);
  }

  /// 设置光标颜色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setCursorColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // OSC 12 ; color=rgb: r / g / b
    final cmd =
        '\x1b]12;color=rgb:${ri ~/ 256}/${ri % 256}/${gi ~/ 256}/${gi % 256}/${bi ~/ 256}/${bi % 256}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置选择背景色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setSelectionBackgroundColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // OSC 131 ; color=rgb: r / g / b
    final cmd =
        '\x1b]131;color=rgb:${ri ~/ 256}/${ri % 256}/${gi ~/ 256}/${gi % 256}/${bi ~/ 256}/${bi % 256}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置选择前景色 (使用广色域)
  ///
  /// [r] - 红色 (0-1)
  /// [g] - 绿色 (0-1)
  /// [b] - 蓝色 (0-1)
  Future<void> setSelectionForegroundColor(double r, double g, double b) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 转换到 0-65535 范围
    final ri = (r * 65535).round();
    final gi = (g * 65535).round();
    final bi = (b * 65535).round();

    // OSC 132 ; color=rgb: r / g / b
    final cmd =
        '\x1b]132;color=rgb:${ri ~/ 256}/${ri % 256}/${gi ~/ 256}/${gi % 256}/${bi ~/ 256}/${bi % 256}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 重置所有颜色到默认值
  Future<void> resetColors() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI 0 m - 重置所有属性
    _session.writeRaw('\x1b[0m');

    // OSC 10 ; - 重置颜色空间
    _session.writeRaw('\x1b]10;\x1b\\\\');

    _currentProfile = const ColorProfile(space: ColorSpace.sRGB);
  }

  /// 查询当前颜色空间
  Future<void> queryColorSpace() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 10 ; ?
    final cmd = '\x1b]10;?\x1b\\\\';
    _session.writeRaw(cmd);
  }
}
