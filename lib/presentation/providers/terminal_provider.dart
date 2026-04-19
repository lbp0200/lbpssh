import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';
import '../../domain/services/local_terminal_service.dart';
import '../../domain/services/terminal_input_service.dart';
import '../../domain/services/app_config_service.dart';
import '../../data/models/ssh_connection.dart';
import 'package:uuid/uuid.dart';

/// 终端会话状态管理
class TerminalProvider extends ChangeNotifier {
  final TerminalService _terminalService;
  final AppConfigService _appConfigService;
  final Map<String, TerminalInputService> _services = {};
  String? _activeSessionId;
  final _uuid = const Uuid();

  TerminalProvider(this._terminalService, this._appConfigService);

  List<TerminalSession> get sessions => _terminalService.getAllSessions();
  String? get activeSessionId => _activeSessionId;
  TerminalSession? get activeSession => _activeSessionId != null
      ? _terminalService.getSession(_activeSessionId!)
      : null;

  /// 初始化（创建默认本地终端）
  Future<void> initialize() async {
    // 启动时创建一个本地终端
    try {
      await createLocalTerminal();
    } catch (e) {
      // 如果创建本地终端失败（例如 Process API 问题），则静默失败
    }
  }

  /// 创建本地终端会话
  Future<TerminalSession> createLocalTerminal() async {
    // 生成唯一的会话 id
    final sessionId = _uuid.v4();

    final localService = LocalTerminalService();

    // 获取终端配置（用于设置字体和 shell）
    final terminalConfig = _appConfigService.terminal;

    // 设置 shell 路径
    if (terminalConfig.shellPath.isNotEmpty) {
      localService.setShellPath(terminalConfig.shellPath);
    }

    _services[sessionId] = localService;

    // 获取初始工作目录
    final initialDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;

    // 根据工作目录生成初始名称
    final initialFolderName = initialDir.split('/').last;
    final initialName = 'local $initialFolderName';

    // 先创建会话（这会调用 initialize，设置终端引用）
    final session = _terminalService.createSession(
      id: sessionId,
      name: initialName,
      inputService: localService,
      terminalConfig: terminalConfig,
      isLocal: true,
    );

    // 设置工作目录并更新名称
    session.setWorkingDirectoryAndUpdateName(initialDir);

    // 初始化 LocalTerminalService 的工作目录
    localService.initWorkingDirectory(initialDir);

    // 然后启动 PTY（此时终端引用已设置）
    try {
      await localService.start();
    } catch (e) {
      rethrow;
    }

    // PTY 启动后，等待 Flutter 完成布局然后同步尺寸
    // 使用 post-frame callback 确保 kterm 的 performLayout 已执行
    // 这样 session.terminal.viewWidth/viewHeight 就是正确的视口尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 在回调中再次使用 addPostFrameCallback 确保在下一帧之前
      // kterm 的 onResize 已触发（如果需要 resize 的话）
      // 直接使用当前视口尺寸进行 resize
      final cols = session.terminal.viewWidth;
      final rows = session.terminal.viewHeight;
      if (cols > 0 && rows > 0) {
        localService.resize(rows, cols);
      }
    });

    // 设置目录变化回调（当检测到 cd 命令时）
    localService.onDirectoryChange = (String newDir) {
      // 直接使用解析后的目录更新标签名称
      session.setWorkingDirectoryAndUpdateName(newDir);
      notifyListeners();
    };

    // 设置实际目录变化回调（用于校正 Tab 补全后的目录名）
    localService.onActualDirectoryChange = (String actualDir) {
      // 用实际目录校正标签名称
      session.setWorkingDirectoryAndUpdateName(actualDir);
      notifyListeners();
    };

    _activeSessionId = sessionId;
    notifyListeners();

    return session;
  }

  /// 创建新的 SSH 终端会话
  Future<TerminalSession> createSession(SshConnection connection) async {
    // 每次创建新的唯一会话 ID
    final sessionId = _uuid.v4();

    final sshService = SshService();
    _services[sessionId] = sshService;

    // 获取终端配置（用于设置字体）
    final terminalConfig = _appConfigService.terminal;

    final session = _terminalService.createSession(
      id: sessionId,
      name: connection.name,
      inputService: sshService,
      terminalConfig: terminalConfig,
      serverInfo: '${connection.username}@${connection.host}',
    );

    _activeSessionId = sessionId;
    notifyListeners();

    // 自动连接 SSH
    try {
      await sshService.connect(connection);

      // 获取工作目录（静默执行，不显示在终端）
      final session = _terminalService.getSession(sessionId);
      if (session != null) {
        try {
          final pwdResult = await sshService.executeCommand(
            'pwd',
            silent: true,
          );
          session.setWorkingDirectory(pwdResult.trim());
        } catch (e) {
          // 使用默认目录
        }
      }
    } catch (e) {
      // 连接失败时关闭会话并抛出异常
      closeSession(sessionId);
      rethrow;
    }

    return session;
  }

  /// 切换到指定会话
  void switchToSession(String sessionId) {
    if (_terminalService.getSession(sessionId) != null) {
      _activeSessionId = sessionId;
      notifyListeners();
    }
  }

  /// 关闭会话
  void closeSession(String sessionId) {
    _terminalService.closeSession(sessionId);
    _services[sessionId]?.dispose();
    _services.remove(sessionId);

    if (_activeSessionId == sessionId) {
      final remainingSessions = sessions;
      _activeSessionId = remainingSessions.isNotEmpty
          ? remainingSessions.first.id
          : null;
    }

    notifyListeners();
  }

  /// 获取 SSH 服务
  SshService? getSshService(String connectionId) {
    final service = _services[connectionId];
    return service is SshService ? service : null;
  }

  /// 获取终端会话
  TerminalSession? getSession(String sessionId) {
    return _terminalService.getSession(sessionId);
  }

  @override
  void dispose() {
    for (final service in _services.values) {
      service.dispose();
    }
    _terminalService.dispose();
    super.dispose();
  }
}
