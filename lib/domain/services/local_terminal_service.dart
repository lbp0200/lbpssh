import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../../utils/sentry_service.dart';
import 'terminal_input_service.dart';

/// PTY 启动函数签名（默认使用 [Pty.start]，测试时可注入替身）
typedef PtyStarter =
    Pty Function(
      String executable, {
      List<String> arguments,
      String? workingDirectory,
      Map<String, String>? environment,
      int rows,
    });

/// 本地终端服务 - 使用 PTY 实现
class LocalTerminalService implements TerminalInputService {
  LocalTerminalService({PtyStarter? ptyStarter})
    : _ptyStarter = ptyStarter ?? Pty.start;

  final PtyStarter _ptyStarter;

  Pty? _pty;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();
  bool _isShuttingDown = false;
  // 进程退出状态是否已上报：onDone（输出流关闭）与 _watchExitCode（exitCode 完成）都会触发，
  // 自然退出时二者先后到达，需去重避免重复打印退出信息。
  bool _processExited = false;
  String _shellPath = '';

  /// 目录变化回调（当检测到 cd 命令时触发）
  void Function(String directory)? onDirectoryChange;

  /// 实际目录变化回调（用于校正 Tab 补全后的目录名）
  void Function(String directory)? onActualDirectoryChange;

  /// 当前工作目录（用于解析相对路径）
  String _currentDirectory = '';

  /// 初始化工作目录
  void initWorkingDirectory(String dir) {
    _currentDirectory = dir;
  }

  /// 解析目标路径（处理相对路径）
  String resolvePath(String targetDir) {
    if (targetDir.startsWith('/')) {
      // 绝对路径
      return _getCanonicalPath(targetDir);
    } else if (targetDir == '..') {
      // 返回上级目录
      if (_currentDirectory == '/') return '/';
      final parts = _currentDirectory.split('/');
      if (parts.length > 1) {
        parts.removeLast();
        // 向上遍历到根时 split 会得到单个空串，join 后为 ''，需归一化为 '/'
        return parts.join('/').isEmpty ? '/' : parts.join('/');
      }
      return '/';
    } else if (targetDir == '.') {
      // 当前目录
      return _currentDirectory;
    } else {
      // 相对路径
      String basePath;
      if (_currentDirectory == '/') {
        basePath = '';
      } else {
        basePath = _currentDirectory;
      }
      return _getCanonicalPath('$basePath/$targetDir');
    }
  }

  /// 获取规范的路径（处理大小写问题）
  String _getCanonicalPath(String path) {
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        // 返回实际存在的路径（大小写正确）
        return dir.path;
      }
      // 如果目录不存在，尝试找父目录并匹配大小写
      final parts = path.split('/');
      if (parts.length <= 1) return path;

      // 找到最后一个存在的目录
      String basePath = '/';
      for (int i = 1; i < parts.length - 1; i++) {
        if (parts[i].isEmpty) continue;
        basePath = basePath == '/' ? '/${parts[i]}' : '$basePath/${parts[i]}';
        final baseDir = Directory(basePath);
        if (!baseDir.existsSync()) {
          return path; // 返回原始路径
        }
      }

      // 尝试匹配最后一部分的大小写
      final parentDir = Directory(basePath);
      final targetName = parts.last;
      try {
        final entities = parentDir.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            final dirName = entity.path.split('/').last;
            if (dirName.toLowerCase() == targetName.toLowerCase()) {
              // 找到大小写匹配的目录
              return '$basePath/$dirName';
            }
          }
        }
      } catch (e) {
        // 忽略错误
      }
    } catch (e) {
      // 忽略错误
    }
    return path;
  }

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（true = 已连接，false = 已断开）
  @override
  Stream<bool> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _pty != null && !_isShuttingDown;

  /// 设置 shell 路径
  void setShellPath(String path) {
    _shellPath = path.trim();
  }

  /// 获取默认 shell 路径
  static String getDefaultShellPath() {
    if (Platform.isWindows) {
      return 'cmd.exe';
    }
    // Unix-like 系统
    return Platform.environment['SHELL'] ??
        (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
  }

  /// 获取当前工作目录（使用独立进程，不影响主终端）
  Future<String> getWorkingDirectory() async {
    try {
      final result = await Process.run('pwd', []);
      return result.stdout.toString().trim();
    } catch (e) {
      // 如果获取失败，返回默认目录
      return Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/';
    }
  }

  /// 启动本地终端
  Future<void> start() async {
    if (_pty != null || _isShuttingDown) {
      return;
    }

    // 新会话开始：复位上一会话的退出去重标记，使本次会话能正常输出其自身退出状态行。
    _processExited = false;

    try {
      // 根据配置选择 shell
      String shell;
      List<String> arguments;

      if (Platform.isWindows) {
        shell = _shellPath.isNotEmpty ? _shellPath : 'cmd.exe';
        arguments = [];
      } else {
        // Unix-like 系统（macOS, Linux）
        if (_shellPath.isNotEmpty) {
          shell = _shellPath;
        } else {
          // 使用系统配置的默认 shell（从环境变量 SHELL 获取）
          shell =
              Platform.environment['SHELL'] ??
              (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
        }
        arguments = ['-l']; // 登录shell
      }

      // 使用默认终端尺寸
      const finalRows = 24;

      final workingDirectory =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;

      // 使用 PTY 启动进程
      final pty = _ptyStarter(
        shell,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: Platform.environment,
        rows: finalRows,
      );
      _pty = pty;

      // 监听 PTY 输出
      _pty!.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) {
              if (!_isShuttingDown && !_outputController.isClosed) {
                // 直接输出，不做缓冲处理
                _outputController.add(data);
                // 背压控制：告知 PTY 应用已处理完本帧数据，可以发送下一帧
                Future.microtask(() => _pty?.ackRead());
              }
            },
            onError: (Object error) {
              if (!_isShuttingDown && !_outputController.isClosed) {
                _outputController.add('\r\n[输出流错误: $error]\r\n');
              }
            },
            onDone: () {
              if (!_isShuttingDown) {
                _pty = null;
                if (!_stateController.isClosed) _stateController.add(false);
                if (!_processExited && !_outputController.isClosed) {
                  _processExited = true;
                  _outputController.add('\r\n[进程已正常退出]\r\n');
                }
              }
            },
          );

      // 监听进程退出
      unawaited(_watchExitCode());

      if (!_stateController.isClosed) _stateController.add(true);
      // 不输出启动信息，保持简洁
    } catch (e) {
      if (!_stateController.isClosed) _stateController.add(false);
      if (!_outputController.isClosed) {
        _outputController.add('启动本地终端失败: $e\r\n');
      }
      rethrow;
    }
  }

  Future<void> _watchExitCode() async {
    try {
      final code = await _pty!.exitCode;
      if (!_isShuttingDown) {
        _pty = null;
        if (!_stateController.isClosed) _stateController.add(false);
        if (!_processExited && !_outputController.isClosed) {
          _processExited = true;
          _outputController.add('\r\n[进程已退出，退出码: $code]\r\n');
        }
      }
    } catch (error) {
      if (!_isShuttingDown) {
        _pty = null;
        if (!_stateController.isClosed) _stateController.add(false);
        if (!_processExited && !_outputController.isClosed) {
          _processExited = true;
          _outputController.add('\r\n[进程异常退出: $error]\r\n');
        }
      }
    }
  }

  /// 发送输入到 PTY
  @override
  void sendInput(String input) {
    // 缓存输入以检测 cd 命令
    _cacheInput(input);

    // 检测 cd 命令（当输入换行时触发）
    final isNewLine =
        input.isNotEmpty &&
        (input.codeUnitAt(0) == 10 || input.codeUnitAt(0) == 13);
    if (isNewLine && onDirectoryChange != null) {
      _checkCdCommand();
    }

    if (_pty != null && !_isShuttingDown) {
      try {
        // 将字符串转换为 UTF-8 字节并发送到 PTY
        final bytes = const Utf8Encoder().convert(input);
        _pty!.write(bytes);
      } catch (e) {
        if (!_outputController.isClosed) {
          _outputController.add('\r\n[发送输入失败: $e]\r\n');
        }
      }
    }
  }

  /// 缓存用户输入的命令
  final StringBuffer _commandBuffer = StringBuffer();

  /// 缓存输入字符（用于检测命令）
  void _cacheInput(String input) {
    // 过滤掉控制字符，只保留可打印字符
    for (final char in input.split('')) {
      final code = char.codeUnitAt(0);
      if (code >= 32) {
        _commandBuffer.write(char);
      } else if (char == '\n' || char == '\r') {
        // 换行符表示命令结束
      }
      // 其他控制字符忽略
    }

    // 清理 buffer 中的转义序列（如方向键的 [A, [B 等）
    String bufferStr = _commandBuffer.toString();
    // 移除转义序列
    bufferStr = bufferStr.replaceAll(RegExp(r'\[[A-Z]'), '');
    if (bufferStr != _commandBuffer.toString()) {
      _commandBuffer.clear();
      _commandBuffer.write(bufferStr);
    }
  }

  /// 检测 cd 命令
  void _checkCdCommand() {
    final command = _commandBuffer.toString().trim();

    // 检查是否是 cd 命令
    if (command.startsWith('cd ')) {
      // 提取目标目录
      String targetDir = command.substring(3).trim();

      // 解析实际路径（基于当前目录的相对路径）
      final resolvedDir = resolvePath(targetDir);

      // 更新当前目录
      _currentDirectory = resolvedDir;

      // 立即通知（用于显示用户输入的目录）
      onDirectoryChange?.call(resolvedDir);

      // 延迟获取实际目录（用于校正 Tab 补全后的目录名）
      // 使用 lsof 获取 PTY 进程的实际工作目录，不会显示任何输出
      Future.delayed(const Duration(milliseconds: 500), () {
        _getActualDirectoryFromLsof();
      });
    }

    // 清空命令缓冲区
    _commandBuffer.clear();
  }

  /// 解析 `lsof -F n -a -p <pid> -d cwd` 的输出，返回进程当前工作目录（绝对路径）。
  ///
  /// `-F n` 让 lsof 把文件名单独输出一行（形如 `n/private/tmp/foo bar`），避免默认列式输出
  /// 把含空格的目录按空白拆散、只取到最后一列的问题。无有效行时返回 null。
  static String? parseLsofCwd(String stdout) {
    for (final rawLine in stdout.split('\n')) {
      final line = rawLine.trim();
      // lsof -F n 的每行以字段前缀开头（cwd 的名称字段为 'n'），去掉前缀即路径。
      if (line.startsWith('n') && line.length > 1) {
        final path = line.substring(1);
        if (path.startsWith('/')) return path;
      }
    }
    return null;
  }

  /// 使用 lsof 获取 PTY shell 的实际工作目录（不会在终端显示输出）
  Future<void> _getActualDirectoryFromLsof() async {
    if (_pty == null || _isShuttingDown) return;

    try {
      // lsof -F n -a -p <pid> -d cwd：用 -F n 把目录名单独输出一行，保留含空格的路径
      final pid = _pty!.pid;

      final result = await Process.run('lsof', [
        '-F',
        'n',
        '-a',
        '-p',
        '$pid',
        '-d',
        'cwd',
      ]);

      if (result.exitCode == 0) {
        final actualDir = parseLsofCwd(result.stdout.toString());
        if (actualDir != null && actualDir != _currentDirectory) {
          _currentDirectory = actualDir;
          onActualDirectoryChange?.call(actualDir);
        }
      }
    } catch (e) {
      // 静默处理错误（lsof 不可用或查询失败时忽略，属预期场景，不上报）
      debugPrint('[LocalTerminalService] lsof cwd query failed: $e');
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command, {bool silent = false}) async {
    if (_pty == null || _isShuttingDown) {
      throw Exception('本地终端未启动');
    }

    final buffer = StringBuffer();
    final subscription = _outputController.stream.listen((data) {
      buffer.write(data);
    });

    try {
      sendInput(command);
      sendInput('\n');

      await Future<void>.delayed(const Duration(seconds: 2));

      await subscription.cancel();
      return buffer.toString();
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// 调整终端尺寸
  @override
  void resize(int rows, int columns) {
    if (_pty != null && !_isShuttingDown) {
      try {
        _pty!.resize(rows, columns);
      } catch (e) {
        // 调整终端尺寸失败，静默处理
      }
    }
  }

  /// 停止终端
  Future<void> stop() async {
    _isShuttingDown = true;

    if (_pty != null) {
      try {
        // 发送 Ctrl+D (EOF) 信号
        // 注意：不能走 sendInput —— _isShuttingDown 已置位，
        // sendInput 内的 !_isShuttingDown 守卫会拦截写入。
        _pty!.write(const Utf8Encoder().convert('\x04'));
        await Future<void>.delayed(const Duration(milliseconds: 500));

        if (_pty != null) {
          _pty!.kill();
          await _pty!.exitCode;
        }
      } catch (e) {
        // 停止进程时出错，忽略
      } finally {
        _pty = null;
        if (!_stateController.isClosed) _stateController.add(false);
        if (!_outputController.isClosed) {
          _outputController.add('\r\n[本地终端已停止]\r\n');
        }
      }
    } else {
      if (!_stateController.isClosed) _stateController.add(false);
    }
  }

  /// 清理资源
  @override
  void dispose() {
    _isShuttingDown = true;
    // 避免 stop() 内的 add 在 close() 之后触发 Bad state
    unawaited(() async {
      try {
        await stop();
      } catch (e, stackTrace) {
        // dispose 阶段 stop 失败属意外路径，记录并上报
        debugPrint('[LocalTerminalService] dispose stop failed: $e');
        unawaited(
          SentryService().captureException(e, stackTrace: stackTrace),
        );
      }
      if (!_outputController.isClosed) await _outputController.close();
      if (!_stateController.isClosed) await _stateController.close();
    }());
  }
}
