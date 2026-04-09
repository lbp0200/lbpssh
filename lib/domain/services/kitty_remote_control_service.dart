import 'dart:async';

import 'terminal_service.dart';

/// 终端信息
class TerminalInfo {
  final String? title;
  final int? columns;
  final int? rows;
  final int? cursorX;
  final int? cursorY;
  final String? foregroundProcess;

  const TerminalInfo({
    this.title,
    this.columns,
    this.rows,
    this.cursorX,
    this.cursorY,
    this.foregroundProcess,
  });
}

/// 缓冲区内容
class BufferContent {
  final int startLine;
  final int lines;
  final String content;

  const BufferContent({
    required this.startLine,
    required this.lines,
    required this.content,
  });
}

/// 远程控制服务
///
/// 通过 OSC 5xx 控制序列实现远程控制终端
class KittyRemoteControlService {
  final TerminalSession? _session;

  // 回调
  void Function(TerminalInfo)? onTerminalInfo;
  void Function(BufferContent)? onBufferContent;
  void Function(String)? onResponse;

  KittyRemoteControlService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取终端标题
  Future<String?> getTitle() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 21 ; t - 请求窗口标题
    final cmd = '\x1b]21;t\x1b\\\\';
    _session.writeRaw(cmd);

    // 等待响应 (异步)
    return null; // 实际响应通过回调处理
  }

  /// 获取终端尺寸
  Future<TerminalInfo> getSize() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 发送 DA (Device Attributes) 请求
    _session.writeRaw('\x1b[c');
    _session.writeRaw('\x1b[6n');

    // 等待响应
    // 响应格式: ESC [ rows ; cols R
    // 实际响应通过回调处理

    return const TerminalInfo(); // 返回空对象，实际数据通过回调
  }

  /// 获取光标位置
  Future<void> getCursorPosition() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI 6n - 查询光标位置
    _session.writeRaw('\x1b[6n');
  }

  /// 获取前台进程
  Future<String?> getForegroundProcess() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 9 ; c - 查询前台进程
    final cmd = '\x1b]9;c\x1b\\\\';
    _session.writeRaw(cmd);

    return null;
  }

  /// 获取剪贴板内容
  Future<String?> getClipboard() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 52 ; c - 获取剪贴板
    final cmd = '\x1b]52;c;?\x1b\\\\';
    _session.writeRaw(cmd);

    return null;
  }

  /// 设置剪贴板内容
  ///
  /// [text] - 剪贴板内容
  Future<void> setClipboard(String text) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 52 ; c ; base64_text - 设置剪贴板
    final encoded = _encodeBase64(text);
    final cmd = '\x1b]52;c;$encoded\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送文本到终端
  ///
  /// [text] - 要发送的文本
  Future<void> sendText(String text) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw(text);
  }

  /// 发送按键到终端
  ///
  /// [key] - 键名
  Future<void> sendKey(String key) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 特殊键映射
    final specialKeys = {
      'enter': '\r',
      'escape': '\x1b',
      'tab': '\t',
      'backspace': '\x7f',
      'up': '\x1b[A',
      'down': '\x1b[B',
      'right': '\x1b[C',
      'left': '\x1b[D',
      'home': '\x1b[H',
      'end': '\x1b[F',
      'pageup': '\x1b[5~',
      'pagedown': '\x1b[6~',
      'insert': '\x1b[2~',
      'delete': '\x1b[3~',
    };

    final sequence = specialKeys[key.toLowerCase()] ?? key;
    _session.writeRaw(sequence);
  }

  /// 发送 Ctrl+C
  Future<void> sendInterrupt() async {
    await sendKeyWithModifier('c', modifier: ModifierKey.ctrl);
  }

  /// 发送 Ctrl+D
  Future<void> sendEOF() async {
    await sendKeyWithModifier('d', modifier: ModifierKey.ctrl);
  }

  /// 发送 Ctrl+Z
  Future<void> sendSuspend() async {
    await sendKeyWithModifier('z', modifier: ModifierKey.ctrl);
  }

  /// 发送带修饰键的字符
  Future<void> sendKeyWithModifier(String key, {ModifierKey modifier = ModifierKey.none}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String prefix = '';
    switch (modifier) {
      case ModifierKey.ctrl:
        prefix = '\x1b^';
        break;
      case ModifierKey.alt:
        prefix = '\x1b';
        break;
      case ModifierKey.shift:
        prefix = '\x1b';
        break;
      default:
        break;
    }

    _session.writeRaw('$prefix$key');
  }

  /// 读取屏幕内容
  ///
  /// [lines] - 行数 (-1 表示全部)
  Future<void> readScreen({int lines = -1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5114 ; R - 读取屏幕
    final cmd = '\x1b]5114;R${lines > 0 ? ";n=$lines" : ""}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 读取缓冲区内容
  ///
  /// [startLine] - 起始行
  /// [lines] - 行数
  Future<void> readBuffer({int startLine = 0, int lines = 100}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5114 ; B - 读取缓冲区
    final cmd = '\x1b]5114;B;s=$startLine;n=$lines\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 清除屏幕
  Future<void> clearScreen() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // ESC [ 2 J - 清除整个屏幕
    _session.writeRaw('\x1b[2J');
  }

  /// 清除行
  Future<void> clearLine() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // ESC [ 2 K - 清除整行
    _session.writeRaw('\x1b[2K');
  }

  /// 发送终端 Bell
  Future<void> sendBell() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x07');
  }

  /// 处理远程控制响应
  ///
  /// 由外部调用，解析终端返回的响应
  void handleResponse(String response) {
    try {
      // OSC 21 响应 - 窗口标题
      if (response.startsWith('21;')) {
        final title = response.substring(3);
        onTerminalInfo?.call(TerminalInfo(title: title));
        return;
      }

      // CSI 6n 响应 - 光标位置
      // 格式: ESC [ rows ; cols R
      final cursorMatch = RegExp(r'\[(\d+);(\d+)R').firstMatch(response);
      if (cursorMatch != null) {
        final rows = int.tryParse(cursorMatch.group(1) ?? '0') ?? 0;
        final cols = int.tryParse(cursorMatch.group(2) ?? '0') ?? 0;
        onTerminalInfo?.call(TerminalInfo(cursorX: cols, cursorY: rows));
        return;
      }

      // OSC 5114 响应 - 屏幕/缓冲区内容
      if (response.startsWith('5114;')) {
        final parts = response.substring(5).split(';');
        if (parts.isNotEmpty && parts[0] == 'R') {
          // 屏幕内容
          final content = parts.sublist(1).join(';');
          onBufferContent?.call(BufferContent(
            startLine: 0,
            lines: 0,
            content: content,
          ));
        }
        return;
      }

      // 其他响应
      onResponse?.call(response);
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// Base64 编码
  String _encodeBase64(String text) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = text.codeUnits;
    final buffer = StringBuffer();

    for (var i = 0; i < bytes.length; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;

      buffer.write(chars[(b1 >> 2) & 0x3F]);
      buffer.write(chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      buffer.write(i + 1 < bytes.length ? chars[((b2 << 2) | (b3 >> 6)) & 0x3F] : '=');
      buffer.write(i + 2 < bytes.length ? chars[b3 & 0x3F] : '=');
    }

    return buffer.toString();
  }
}

/// 修饰键
enum ModifierKey {
  none,
  ctrl,
  alt,
  shift,
  super_,
}
