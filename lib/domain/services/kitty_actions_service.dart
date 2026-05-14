import 'dart:async';

import 'terminal_service.dart';

/// 操作类型
enum ActionType {
  openUrl, // 打开 URL
  openFile, // 打开文件
  runProgram, // 运行程序
  click, // 点击
  scroll, // 滚动
  input, // 输入
  navigate, // 导航
}

/// URL 动作
class UrlAction {
  final String url;
  final String? id;

  const UrlAction({required this.url, this.id});
}

/// 文件动作
class FileAction {
  final String path;
  final String? line;
  final String? column;

  const FileAction({required this.path, this.line, this.column});
}

/// 程序动作
class ProgramAction {
  final String program;
  final List<String> arguments;
  final String? cwd;

  const ProgramAction({
    required this.program,
    this.arguments = const [],
    this.cwd,
  });
}

/// 动作参数
class ActionArgs {
  final ActionType type;
  final String? url;
  final String? filePath;
  final int? line;
  final int? column;
  final String? program;
  final List<String>? arguments;
  final int? x;
  final int? y;
  final int? deltaX;
  final int? deltaY;
  final String? text;

  const ActionArgs({
    required this.type,
    this.url,
    this.filePath,
    this.line,
    this.column,
    this.program,
    this.arguments,
    this.x,
    this.y,
    this.deltaX,
    this.deltaY,
    this.text,
  });
}

/// 动作回调
typedef ActionCallback = void Function(ActionArgs action);

/// 动作服务
///
/// 通过 OSC 5xx 和 actions 功能实现终端内操作
class KittyActionsService {
  final TerminalSession? _session;

  // 回调
  ActionCallback? onAction;

  KittyActionsService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 打开 URL
  ///
  /// [url] - 要打开的 URL
  /// [id] - 可选的 URL ID
  Future<void> openUrl(String url, {String? id}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5 ; open-url ; id=xxx ; u=url
    String cmd = '\x1b]5;open-url';
    if (id != null) {
      cmd += ';id=$id';
    }
    cmd += ';u=$url\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 打开文件
  ///
  /// [path] - 文件路径
  /// [line] - 可选的行号
  /// [column] - 可选的列号
  Future<void> openFile(String path, {int? line, int? column}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5 ; open-file ; f=path ; l=line ; c=column
    String cmd = '\x1b]5;open-file;f=$path';
    if (line != null) cmd += ';l=$line';
    if (column != null) cmd += ';c=$column';
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 运行程序
  ///
  /// [program] - 程序路径
  /// [arguments] - 程序参数
  /// [cwd] - 工作目录
  Future<void> runProgram(
    String program, {
    List<String>? arguments,
    String? cwd,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5 ; run-program ; p=program ; a=args ; d=cwd
    String cmd = '\x1b]5;run-program;p=$program';
    if (arguments != null && arguments.isNotEmpty) {
      cmd += ';a=${arguments.join(",")}';
    }
    if (cwd != null) cmd += ';d=$cwd';
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送点击动作
  ///
  /// [x] - X 坐标
  /// [y] - Y 坐标
  Future<void> click(int x, int y) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5 ; click ; x=x ; y=y
    final cmd = '\x1b]5;click;x=$x;y=$y\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送滚动动作
  ///
  /// [deltaX] - 水平滚动
  /// [deltaY] - 垂直滚动
  Future<void> scroll({int? deltaX, int? deltaY}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String cmd = '\x1b]5;scroll';
    if (deltaX != null) cmd += ';x=$deltaX';
    if (deltaY != null) cmd += ';y=$deltaY';
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送输入动作
  ///
  /// [text] - 要输入的文本
  Future<void> input(String text) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 对文本进行转义
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,');

    // OSC 5 ; input ; t=text
    final cmd = '\x1b]5;input;t=$escaped\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 发送导航动作
  ///
  /// [direction] - 方向 (up, down, left, right, home, end)
  Future<void> navigate(String direction) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 5 ; navigate ; d=direction
    final cmd = '\x1b]5;navigate;d=$direction\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求动作
  ///
  /// 请求终端执行某个动作
  Future<void> requestAction(
    ActionType type, {
    Map<String, String>? params,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    String typeStr;
    switch (type) {
      case ActionType.openUrl:
        typeStr = 'request-open-url';
        break;
      case ActionType.openFile:
        typeStr = 'request-open-file';
        break;
      case ActionType.runProgram:
        typeStr = 'request-run-program';
        break;
      case ActionType.click:
        typeStr = 'request-click';
        break;
      case ActionType.scroll:
        typeStr = 'request-scroll';
        break;
      case ActionType.input:
        typeStr = 'request-input';
        break;
      case ActionType.navigate:
        typeStr = 'request-navigate';
        break;
    }

    String cmd = '\x1b]5;$typeStr';
    if (params != null) {
      for (final entry in params.entries) {
        cmd += ';${entry.key}=${entry.value}';
      }
    }
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理动作响应
  ///
  /// 由外部调用，解析终端返回的动作响应
  void handleActionResponse(String response) {
    try {
      // 解析 OSC 5 响应
      // 格式: 5 ; action_type ; key=value ; ...

      if (response.startsWith('5;')) {
        final parts = response.substring(2).split(';');
        if (parts.isEmpty) return;

        final actionType = parts[0];
        final args = <String, String>{};

        for (var i = 1; i < parts.length; i++) {
          final idx = parts[i].indexOf('=');
          if (idx > 0) {
            final key = parts[i].substring(0, idx);
            final value = parts[i].substring(idx + 1);
            args[key] = value;
          }
        }

        // 解析动作类型并触发回调
        switch (actionType) {
          case 'open-url':
            onAction?.call(
              ActionArgs(type: ActionType.openUrl, url: args['u']),
            );
            break;
          case 'open-file':
            onAction?.call(
              ActionArgs(
                type: ActionType.openFile,
                filePath: args['f'],
                line: int.tryParse(args['l'] ?? ''),
                column: int.tryParse(args['c'] ?? ''),
              ),
            );
            break;
          case 'run-program':
            onAction?.call(
              ActionArgs(
                type: ActionType.runProgram,
                program: args['p'],
                arguments: args['a']?.split(','),
              ),
            );
            break;
          case 'click':
            onAction?.call(
              ActionArgs(
                type: ActionType.click,
                x: int.tryParse(args['x'] ?? ''),
                y: int.tryParse(args['y'] ?? ''),
              ),
            );
            break;
          case 'scroll':
            onAction?.call(
              ActionArgs(
                type: ActionType.scroll,
                deltaX: int.tryParse(args['x'] ?? ''),
                deltaY: int.tryParse(args['y'] ?? ''),
              ),
            );
            break;
          case 'input':
            onAction?.call(ActionArgs(type: ActionType.input, text: args['t']));
            break;
          case 'navigate':
            onAction?.call(
              ActionArgs(type: ActionType.navigate, text: args['d']),
            );
            break;
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }
}
