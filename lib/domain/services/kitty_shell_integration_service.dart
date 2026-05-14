import 'dart:async';

import 'terminal_service.dart';

/// Shell 提示符类型
enum PromptType {
  command, // 命令行提示符 (A)
  continuation, // 续行提示符 (B)
  selection, // 选择提示符 (C)
  vimPrompt, // Vim 命令提示符 (D)
}

/// Shell 集成服务
///
/// 通过 OSC 133 控制序列实现 Shell 集成功能
class KittyShellIntegrationService {
  final TerminalSession? _session;

  // 回调
  void Function(String prompt, PromptType type)? onPrompt;
  void Function(String commandLine)? onCommandLine;
  void Function(int exitStatus)? onExitStatus;
  void Function(String workingDirectory)? onWorkingDirectory;

  KittyShellIntegrationService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 发送命令提示符查询
  ///
  /// 查询当前 Shell 的提示符格式
  Future<void> queryPrompt() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; A
    final cmd = '\x1b]133;A\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送命令完成信号
  ///
  /// [commandLine] - 执行的命令
  /// [exitStatus] - 退出状态 (0 成功，非 0 失败)
  Future<void> sendCommandExecuted({
    required String commandLine,
    required int exitStatus,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; C ; command=command_line ; status=exit_status
    final cmd =
        '\x1b]133;C;command=${_encode(commandLine)};status=$exitStatus\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送命令失败信号
  ///
  /// [commandLine] - 失败的命令
  Future<void> sendCommandFailed(String commandLine) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; C ; command=command_line ; status=1
    final cmd = '\x1b]133;C;command=${_encode(commandLine)};status=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送命令开始信号
  ///
  /// [commandLine] - 要执行的命令
  Future<void> sendCommandStarted(String commandLine) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; S ; command=command_line
    final cmd = '\x1b]133;S;command=${_encode(commandLine)}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送工作目录变化
  ///
  /// [path] - 新工作目录路径
  Future<void> sendWorkingDirectory(String path) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; D ; path
    final cmd = '\x1b]133;D;$path\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询当前工作目录
  Future<void> queryWorkingDirectory() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; D ; ?
    final cmd = '\x1b]133;D;?\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送命令行内容
  ///
  /// 用于外部程序获取当前命令行
  Future<void> sendCommandLine(String commandLine) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; F ; command=command_line
    final cmd = '\x1b]133;F;command=${_encode(commandLine)}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询命令行
  Future<void> queryCommandLine() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; F ; ?
    final cmd = '\x1b]133;F;?\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送提示符样式
  ///
  /// [promptType] - 提示符类型
  /// [styles] - 样式参数 (key=value 格式)
  Future<void> sendPromptStyle(
    PromptType promptType, {
    Map<String, String>? styles,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String typeChar;
    switch (promptType) {
      case PromptType.command:
        typeChar = 'A';
        break;
      case PromptType.continuation:
        typeChar = 'B';
        break;
      case PromptType.selection:
        typeChar = 'C';
        break;
      case PromptType.vimPrompt:
        typeChar = 'D';
        break;
    }

    String cmd = '\x1b]133;$typeChar';
    if (styles != null) {
      for (final entry in styles.entries) {
        cmd += ';${entry.key}=${entry.value}';
      }
    }
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理 Shell 响应
  ///
  /// 由外部调用，解析终端返回的 OSC 133 响应
  void handleShellResponse(String response) {
    try {
      // 解析 OSC 133 响应
      // 格式: 133 ; key=value ; key=value ...

      if (response.startsWith('133;')) {
        final parts = response.substring(4).split(';');

        for (final part in parts) {
          final idx = part.indexOf('=');
          if (idx == -1) continue;

          final key = part.substring(0, idx).trim();
          final value = part.substring(idx + 1).trim();

          switch (key) {
            case 'A':
              // 命令行提示符
              onPrompt?.call(value, PromptType.command);
              break;
            case 'B':
              // 续行提示符
              onPrompt?.call(value, PromptType.continuation);
              break;
            case 'C':
              // 选择提示符
              onPrompt?.call(value, PromptType.selection);
              break;
            case 'D':
              // Vim 命令提示符
              if (value == '?') {
                // 查询响应，包含实际路径
                // 需要进一步解析
              } else if (value.startsWith('cwd=')) {
                final cwd = value.substring(4);
                onWorkingDirectory?.call(cwd);
              }
              break;
            case 'command':
              onCommandLine?.call(_decode(value));
              break;
            case 'status':
              final status = int.tryParse(value) ?? 0;
              onExitStatus?.call(status);
              break;
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// 编码字符串用于 OSC 序列
  String _encode(String text) {
    // 需要对特殊字符进行转义
    return text
        .replaceAll(';', '\\;')
        .replaceAll(':', '\\:')
        .replaceAll('\\', '\\\\');
  }

  /// 解码字符串
  String _decode(String text) {
    return text
        .replaceAll('\\;', ';')
        .replaceAll('\\:', ':')
        .replaceAll('\\\\', '\\');
  }
}
