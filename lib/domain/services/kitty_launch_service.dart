import 'dart:async';

import 'terminal_service.dart';

/// 启动类型
enum LaunchType {
  tab, // 在新标签页中启动
  window, // 在新窗口中启动
  overlay, // 在覆盖层中启动
  background, // 在后台启动
  os, // 使用系统默认应用
}

/// 启动参数
class LaunchParams {
  final String program;
  final List<String>? arguments;
  final String? cwd;
  final String? title;
  final bool? stealFocus;
  final String? env;
  final bool? hold;

  const LaunchParams({
    required this.program,
    this.arguments,
    this.cwd,
    this.title,
    this.stealFocus,
    this.env,
    this.hold,
  });
}

/// 启动服务
///
/// 通过 OSC 6 和 launch 功能实现在终端内启动程序
class KittyLaunchService {
  final TerminalSession? _session;

  KittyLaunchService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 启动程序
  ///
  /// [program] - 程序路径
  /// [arguments] - 程序参数
  /// [cwd] - 工作目录
  /// [title] - 窗口标题
  /// [type] - 启动类型
  Future<void> launch(
    String program, {
    List<String>? arguments,
    String? cwd,
    String? title,
    LaunchType type = LaunchType.tab,
    bool? stealFocus,
    String? env,
    bool? hold,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 ; launch 参数
    String cmd = '\x1b]6;';

    // 添加程序
    cmd += 'p=$program';

    // 添加参数
    if (arguments != null && arguments.isNotEmpty) {
      cmd += ';a=${arguments.join(",")}';
    }

    // 添加工作目录
    if (cwd != null) {
      cmd += ';c=$cwd';
    }

    // 添加标题
    if (title != null) {
      cmd += ';t=$title';
    }

    // 添加启动类型
    switch (type) {
      case LaunchType.tab:
        cmd += ';type=tab';
        break;
      case LaunchType.window:
        cmd += ';type=window';
        break;
      case LaunchType.overlay:
        cmd += ';type=overlay';
        break;
      case LaunchType.background:
        cmd += ';type=background';
        break;
      case LaunchType.os:
        cmd += ';type=os';
        break;
    }

    // 添加是否获取焦点
    if (stealFocus != null) {
      cmd += ';s=${stealFocus ? "1" : "0"}';
    }

    // 添加环境变量
    if (env != null) {
      cmd += ';e=$env';
    }

    // 添加是否保持
    if (hold != null) {
      cmd += ';h=${hold ? "1" : "0"}';
    }

    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 在新标签页中启动程序
  Future<void> launchInTab(
    String program, {
    List<String>? arguments,
    String? cwd,
    String? title,
  }) async {
    await launch(
      program,
      arguments: arguments,
      cwd: cwd,
      title: title,
    );
  }

  /// 在新窗口中启动程序
  Future<void> launchInWindow(
    String program, {
    List<String>? arguments,
    String? cwd,
    String? title,
    bool? stealFocus,
  }) async {
    await launch(
      program,
      arguments: arguments,
      cwd: cwd,
      title: title,
      type: LaunchType.window,
      stealFocus: stealFocus,
    );
  }

  /// 使用系统默认应用打开
  Future<void> openWithSystemDefault(String path) async {
    await launch(
      '', // 空程序表示使用系统默认
      type: LaunchType.os,
      cwd: path,
    );
  }

  /// 打开 URL
  Future<void> openUrl(String url) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 使用 launch 打开 URL
    final cmd = '\x1b]6;type=os;u=$url\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 打开文件
  Future<void> openFile(String path) async {
    await openWithSystemDefault(path);
  }

  /// 发送通知
  Future<void> sendNotification({
    required String title,
    String? body,
    String? sound,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 ; notification
    String cmd = '\x1b]6;type=notification';
    cmd += ';title=$title';
    if (body != null) cmd += ';b=$body';
    if (sound != null) cmd += ';s=$sound';
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求激活终端窗口
  Future<void> activateWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    const cmd = '\x1b]6;activate=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求最小化窗口
  Future<void> minimizeWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    const cmd = '\x1b]6;minimize=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求最大化窗口
  Future<void> maximizeWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    const cmd = '\x1b]6;maximize=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求全屏
  Future<void> setFullscreen(bool enable) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]6;fullscreen=${enable ? "1" : "0"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 请求设置窗口标题
  Future<void> setWindowTitle(String title) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]6;title=$title\x1b\\\\';
    _session.writeRaw(cmd);
  }
}
