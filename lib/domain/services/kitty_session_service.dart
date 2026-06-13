import 'dart:async';

import 'terminal_service.dart';

/// 会话状态
class SessionState {
  final String? workingDirectory;
  final String? title;
  final String? foregroundProcess;
  final int? exitCode;
  final bool isRunning;

  const SessionState({
    this.workingDirectory,
    this.title,
    this.foregroundProcess,
    this.exitCode,
    this.isRunning = true,
  });
}

/// 会话管理器
///
/// 管理终端会话的状态查询和控制
class KittySessionService {
  final TerminalSession? _session;

  // 回调
  void Function(SessionState)? onStateChange;
  void Function(int exitCode)? onExit;

  KittySessionService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前工作目录
  ///
  /// 通过查询 $PWD 或 OSC 133;D
  Future<String?> getWorkingDirectory() async {
    final session = _session;
    if (session == null) {
      throw Exception('未连接到终端');
    }

    // 方法 1: 使用 echo $PWD
    final completer = Completer<String?>();

    // 监听输出
    final subscription = session.inputService.outputStream.listen((output) {
      if (!completer.isCompleted && output.contains('/')) {
        // 解析输出获取路径
        final match = RegExp(r'(/[^\r\n]+)').firstMatch(output);
        if (match != null) {
          completer.complete(match.group(1));
        }
      }
    });

    // 发送命令
    session.writeRaw('echo \$PWD\r');

    // 等待响应
    final result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );

    await subscription.cancel();
    return result;
  }

  /// 获取窗口标题
  Future<String?> getTitle() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 21 ; t - 请求窗口标题
    const cmd = '\x1b]21;t\x1b\\\\';
    _session.writeRaw(cmd);

    return null; // 响应通过回调处理
  }

  /// 设置窗口标题
  Future<void> setTitle(String title) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 0 ; title
    final cmd = '\x1b]0;$title\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 获取前台进程
  Future<String?> getForegroundProcess() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 9 ; c - 查询前台进程
    const cmd = '\x1b]9;c\x1b\\\\';
    _session.writeRaw(cmd);

    return null;
  }

  /// 获取终端尺寸
  Future<({int columns, int rows})?> getTerminalSize() async {
    final session = _session;
    if (session == null) {
      throw Exception('未连接到终端');
    }

    final completer = Completer<({int columns, int rows})?>();

    // 监听输出
    final subscription = session.inputService.outputStream.listen((output) {
      if (!completer.isCompleted) {
        // 解析 CSI 6n 响应: ESC [ rows ; cols R
        final match = RegExp(r'\[(\d+);(\d+)R').firstMatch(output);
        if (match != null) {
          final rows = int.tryParse(match.group(1) ?? '0') ?? 0;
          final cols = int.tryParse(match.group(2) ?? '0') ?? 0;
          completer.complete((columns: cols, rows: rows));
        }
      }
    });

    // 发送查询
    session.writeRaw('\x1b[6n');

    // 等待响应
    final result = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );

    await subscription.cancel();
    return result;
  }

  /// 发送内容到终端
  Future<void> sendText(String text) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw(text);
  }

  /// 发送命令
  Future<void> sendCommand(String command) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('$command\r');
  }

  /// 发送 Ctrl+C (中断当前命令)
  Future<void> sendInterrupt() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x03');
  }

  /// 发送 Ctrl+Z (暂停当前进程)
  Future<void> sendSuspend() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1a');
  }

  /// 发送 Ctrl+D (EOF)
  Future<void> sendEOF() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x04');
  }

  /// 清屏
  Future<void> clearScreen() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[2J\x1b[H');
  }

  /// 光标归位
  Future<void> cursorHome() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[H');
  }

  /// 终端 Bell
  Future<void> bell() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x07');
  }

  /// 保存光标位置
  Future<void> saveCursor() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b7');
    _session.writeRaw('\x1b[s');
  }

  /// 恢复光标位置
  Future<void> restoreCursor() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b8');
    _session.writeRaw('\x1b[u');
  }

  /// 滚动屏幕向上
  Future<void> scrollUp({int lines = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${lines}S');
  }

  /// 滚动屏幕向下
  Future<void> scrollDown({int lines = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${lines}T');
  }

  /// 插入空行
  Future<void> insertLine({int count = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${count}L');
  }

  /// 删除行
  Future<void> deleteLine({int count = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${count}M');
  }

  /// 删除字符
  Future<void> deleteChar({int count = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${count}P');
  }

  /// 擦除字符
  Future<void> eraseChar({int count = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[${count}X');
  }

  /// 报告会话状态
  Future<SessionState> reportState() async {
    final cwd = await getWorkingDirectory();

    return SessionState(workingDirectory: cwd);
  }
}
