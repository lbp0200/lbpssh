import 'dart:async';
import 'dart:typed_data';

import 'terminal_service.dart';

/// 截图格式
enum ScreenshotFormat { png, jpeg, svg }

/// 截图区域
enum ScreenshotArea {
  screen, // 整个屏幕
  window, // 当前窗口
  selection, // 选区
}

/// 截图回调
typedef ScreenshotCallback = void Function(Uint8List data);

/// 截图服务
///
/// 实现终端截图功能
class KittyScreenshotService {
  final TerminalSession? _session;

  // 回调
  ScreenshotCallback? onScreenshot;

  KittyScreenshotService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 截取整个屏幕
  ///
  /// [format] - 图片格式
  Future<void> captureScreen({
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; screenshot:area=screen:format=format
    String formatStr;
    switch (format) {
      case ScreenshotFormat.png:
        formatStr = 'png';
        break;
      case ScreenshotFormat.jpeg:
        formatStr = 'jpg';
        break;
      case ScreenshotFormat.svg:
        formatStr = 'svg';
        break;
    }

    final cmd = '\x1b]20;screenshot:area=screen:format=$formatStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 截取当前窗口
  ///
  /// [format] - 图片格式
  Future<void> captureWindow({
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String formatStr;
    switch (format) {
      case ScreenshotFormat.png:
        formatStr = 'png';
        break;
      case ScreenshotFormat.jpeg:
        formatStr = 'jpg';
        break;
      case ScreenshotFormat.svg:
        formatStr = 'svg';
        break;
    }

    final cmd = '\x1b]20;screenshot:area=window:format=$formatStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 截取选区
  ///
  /// [format] - 图片格式
  Future<void> captureSelection({
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String formatStr;
    switch (format) {
      case ScreenshotFormat.png:
        formatStr = 'png';
        break;
      case ScreenshotFormat.jpeg:
        formatStr = 'jpg';
        break;
      case ScreenshotFormat.svg:
        formatStr = 'svg';
        break;
    }

    final cmd = '\x1b]20;screenshot:area=selection:format=$formatStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 截取指定区域
  ///
  /// [x] - X 坐标
  /// [y] - Y 坐标
  /// [width] - 宽度
  /// [height] - 高度
  /// [format] - 图片格式
  Future<void> captureArea(
    int x,
    int y,
    int width,
    int height, {
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String formatStr;
    switch (format) {
      case ScreenshotFormat.png:
        formatStr = 'png';
        break;
      case ScreenshotFormat.jpeg:
        formatStr = 'jpg';
        break;
      case ScreenshotFormat.svg:
        formatStr = 'svg';
        break;
    }

    // OSC 20 ; screenshot:area=rect:x:y:width:height:format
    final cmd =
        '\x1b]20;screenshot:area=rect:x=$x:y=$y:w=$width:h=$height:format=$formatStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 保存截图到文件
  ///
  /// [path] - 保存路径
  /// [area] - 截图区域
  /// [format] - 图片格式
  Future<void> saveScreenshot(
    String path, {
    ScreenshotArea area = ScreenshotArea.screen,
    ScreenshotFormat format = ScreenshotFormat.png,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String areaStr;
    switch (area) {
      case ScreenshotArea.screen:
        areaStr = 'screen';
        break;
      case ScreenshotArea.window:
        areaStr = 'window';
        break;
      case ScreenshotArea.selection:
        areaStr = 'selection';
        break;
    }

    String formatStr;
    switch (format) {
      case ScreenshotFormat.png:
        formatStr = 'png';
        break;
      case ScreenshotFormat.jpeg:
        formatStr = 'jpg';
        break;
      case ScreenshotFormat.svg:
        formatStr = 'svg';
        break;
    }

    // OSC 20 ; screenshot:save:path:area:format
    final cmd =
        '\x1b]20;screenshot:save:$path:area=$areaStr:format=$formatStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 复制截图到剪贴板
  ///
  /// [area] - 截图区域
  Future<void> copyToClipboard({
    ScreenshotArea area = ScreenshotArea.screen,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String areaStr;
    switch (area) {
      case ScreenshotArea.screen:
        areaStr = 'screen';
        break;
      case ScreenshotArea.window:
        areaStr = 'window';
        break;
      case ScreenshotArea.selection:
        areaStr = 'selection';
        break;
    }

    // OSC 20 ; screenshot:clipboard:area
    final cmd = '\x1b]20;screenshot:clipboard:area=$areaStr\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 开始交互式截图
  ///
  /// 终端会进入截图模式，用户可以选择区域
  Future<void> startInteractiveCapture() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; screenshot:interactive
    final cmd = '\x1b]20;screenshot:interactive\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 取消截图
  Future<void> cancelCapture() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 发送 Escape 取消
    _session.writeRaw('\x1b');
  }

  /// 设置截图质量
  ///
  /// [quality] - 质量 (1-100)，仅对 JPEG 有效
  Future<void> setQuality(int quality) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    if (quality < 1 || quality > 100) {
      throw Exception('质量必须在 1-100 之间');
    }

    // OSC 20 ; screenshot:quality=value
    final cmd = '\x1b]20;screenshot:quality=$quality\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置透明背景
  ///
  /// [transparent] - 是否透明
  Future<void> setTransparentBackground(bool transparent) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; screenshot:transparent=1/0
    final cmd =
        '\x1b]20;screenshot:transparent=${transparent ? "1" : "0"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理截图响应
  ///
  /// [data] - 截图数据 (Base64 编码)
  void handleScreenshotResponse(String data) {
    // 解析截图数据
    try {
      // 响应格式可能是 base64 编码的图片数据
      onScreenshot?.call(_decodeBase64(data));
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// Base64 解码
  Uint8List _decodeBase64(String data) {
    // 简化的 Base64 解码
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];

    // 移除可能的 data: 前缀
    if (data.contains(',')) {
      data = data.split(',').last;
    }

    // 补齐 =
    while (data.length % 4 != 0) {
      data += '=';
    }

    for (var i = 0; i < data.length; i += 4) {
      final b1 = chars.indexOf(data[i]);
      final b2 = chars.indexOf(data[i + 1]);
      final b3 = chars.indexOf(data[i + 2]);
      final b4 = chars.indexOf(data[i + 3]);

      bytes.add((b1 << 2) | (b2 >> 4));
      if (data[i + 2] != '=') {
        bytes.add(((b2 & 0x0F) << 4) | (b3 >> 2));
      }
      if (data[i + 3] != '=') {
        bytes.add(((b3 & 0x03) << 6) | b4);
      }
    }

    return Uint8List.fromList(bytes);
  }
}
