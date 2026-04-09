import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kterm/kterm.dart';
import 'terminal_input_service.dart';
import '../../data/models/terminal_config.dart';
import 'ssh_service.dart';

/// 文件传输事件
class FileTransferEvent {
  final String type; // 'start', 'chunk', 'end', 'error'
  final String? fileId;
  final String? fileName;
  final int? fileSize;
  final int? offset;
  final Uint8List? data;
  final String? error;

  FileTransferEvent({
    required this.type,
    this.fileId,
    this.fileName,
    this.fileSize,
    this.offset,
    this.data,
    this.error,
  });
}

/// 终端会话
class TerminalSession {
  final String id;
  String _name;
  final TerminalInputService inputService;
  final Terminal terminal;
  final TerminalController controller;
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<bool>? _stateSubscription;

  // 通知流控制器
  final _notificationController =
      StreamController<({String title, String body})>.broadcast();

  /// 通知流，用于监听终端发出的桌面通知
  Stream<({String title, String body})> get notificationStream =>
      _notificationController.stream;

  // 文件传输流控制器
  final _fileTransferController =
      StreamController<FileTransferEvent>.broadcast();

  /// 文件传输流，用于监听远程发送的文件
  Stream<FileTransferEvent> get fileTransferStream =>
      _fileTransferController.stream;

  // OS 类型: 'Linux', 'Darwin' (macOS), 'Windows' 等
  String osType = 'Linux';

  // 当前工作目录
  String workingDirectory = '/';

  // === 新增：连接状态相关字段 ===
  /// 连接状态
  SshConnectionState connectionState = SshConnectionState.disconnected;

  /// 连接开始时间（用于计算连接时长）
  DateTime? connectionStartTime;

  /// 是否为本地终端
  final bool isLocal;

  /// 服务器信息（SSH时为 user@host，本地为 null）
  final String? serverInfo;

  TerminalSession({
    required this.id,
    required String name,
    required this.inputService,
    TerminalConfig? terminalConfig,
    this.isLocal = false,
    this.serverInfo,
  }) : _name = name,
       terminal = Terminal(maxLines: 10000),
       controller = TerminalController() {
    // 禁用 Kitty 键盘模式，使用传统终端序列
    // 这样可以确保与所有 SSH 服务器兼容
    terminal.setKittyMode(false);

    // 监听终端通知（Kitty 协议）
    terminal.onNotification = (title, body) {
      _notificationController.add((title: title, body: body));
    };

    // 监听剪贴板读取（OSC 52）
    // 回调需要读取剪贴板内容并通过 terminal.write 写回 OSC 52 响应序列
    terminal.onClipboardRead = (target) async {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null) {
          final encoded = base64Encode(utf8.encode(data!.text!));
          // 写回 OSC 52 响应序列
          terminal.write('\x1b]52;$target;$encoded\x1b\\');
        }
      } catch (e) {
        // Ignore clipboard errors
      }
    };

    // 监听剪贴板写入（OSC 52）
    terminal.onClipboardWrite = (data, target) async {
      try {
        final text = utf8.decode(base64Decode(data));
        await Clipboard.setData(ClipboardData(text: text));
      } catch (e) {
        // Ignore clipboard errors
      }
    };

    // 监听私有 OSC 序列（用于文件传输等）
    terminal.onPrivateOSC = (code, args) {
      if (code == '5113') {
        _handleFileTransfer(args);
      }
    };
  }

  void _handleFileTransfer(List<String> args) {
    // 解析 OSC 5113 参数
    // 格式: ac=xxx;id=xxx;fid=xxx;n=xxx;size=xxx;d=xxx
    final params = <String, String>{};
    for (final arg in args) {
      final parts = arg.split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }

    final action = params['ac'];

    switch (action) {
      case 'send':
        // 远程请求发送文件给我们
        _fileTransferController.add(
          FileTransferEvent(
            type: 'start',
            fileId: params['fid'],
            fileName: _decodeBase64(params['n']),
            fileSize: int.tryParse(params['size'] ?? ''),
          ),
        );
        break;
      case 'data':
        _fileTransferController.add(
          FileTransferEvent(
            type: 'chunk',
            fileId: params['fid'],
            offset: int.tryParse(params['offset'] ?? ''),
            data: _decodeBase64Bytes(params['d']),
          ),
        );
        break;
      case 'finish':
        _fileTransferController.add(
          FileTransferEvent(type: 'end', fileId: params['fid']),
        );
        break;
    }
  }

  /// 解码 Base64 字符串为 UTF-8 文本
  String? _decodeBase64(String? encoded) {
    if (encoded == null) return null;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      return null;
    }
  }

  /// 解码 Base64 字符串为字节数组
  Uint8List? _decodeBase64Bytes(String? encoded) {
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } catch (e) {
      return null;
    }
  }

  /// 获取 GraphicsManager 实例（由 kterm 自动创建）
  /// 注意: graphicsManager 是由 kterm 内部管理的
  dynamic get graphicsManager => terminal.graphicsManager;

  /// 发送原始字符到终端（用于发送 OSC 序列）
  void writeRaw(String data) {
    terminal.write(data);
  }

  /// 获取会话名称
  String get name => _name;

  /// 设置会话名称
  void setName(String newName) {
    _name = newName;
  }

  /// 根据工作目录更新本地终端名称
  /// 格式: local {文件夹名称}
  void updateLocalTerminalName() {
    if (workingDirectory.isEmpty || workingDirectory == '/') {
      _name = 'local /';
      return;
    }
    // 获取路径的最后一个部分作为文件夹名称
    final folderName = workingDirectory.split('/').last;
    _name = 'local $folderName';
  }

  /// 设置当前工作目录并自动更新名称（仅用于本地终端）
  void setWorkingDirectoryAndUpdateName(String path) {
    workingDirectory = path;
    updateLocalTerminalName();
  }

  /// 设置当前工作目录
  void setWorkingDirectory(String path) {
    workingDirectory = path;
  }

  /// 设置 OS 类型
  void setOsType(String type) {
    osType = type;
  }

  /// 初始化终端会话
  Future<void> initialize() async {
    // 监听输出
    _outputSubscription = inputService.outputStream.listen(
      (output) {
        terminal.write(output);
      },
      onError: (error) {
        // 输出流错误
      },
      onDone: () {
        // 输出流关闭
      },
    );

    // 监听连接状态
    _stateSubscription = inputService.stateStream.listen(
      (isConnected) {
        // 更新连接状态
        connectionState = isConnected
            ? SshConnectionState.connected
            : SshConnectionState.disconnected;
        if (isConnected) {
          connectionStartTime = DateTime.now();
        }
      },
      onError: (error) {
        // 状态流错误
      },
      onDone: () {
        // 状态流关闭
      },
    );

    // 监听终端输入
    terminal.onOutput = (data) {
      // 跳过空数据
      if (data.isEmpty) return;
      // 发送输入到 SSH/本地终端
      try {
        inputService.sendInput(data);
      } catch (e) {
        terminal.write('\r\n[输入发送失败: $e]\r\n');
      }
    };

    // 监听终端尺寸变化
    // 使用一个变量保存当前尺寸，确保可以同步到远程
    int currentCols = 80;
    int currentRows = 24;

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      currentCols = width;
      currentRows = height;
      // 对所有终端输入服务（包括 SSH 和本地）调整尺寸
      inputService.resize(height, width);
    };

    // 首次布局后确保同步终端尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 使用保存的尺寸变量，确保一致性
      if (currentRows > 0 && currentCols > 0) {
        inputService.resize(currentRows, currentCols);
      }
    });
  }

  /// 执行命令
  Future<void> executeCommand(String command) async {
    terminal.write('$command\r\n');
    try {
      await inputService.executeCommand(command);
    } catch (e) {
      terminal.write('错误: $e\r\n');
    }
  }

  /// 清理资源
  void dispose() {
    _outputSubscription?.cancel();
    _stateSubscription?.cancel();
    _notificationController.close();
    _fileTransferController.close();
    inputService.dispose();
    controller.dispose();
  }
}

/// 终端服务管理器
class TerminalService {
  final Map<String, TerminalSession> _sessions = {};

  /// 创建新的终端会话
  TerminalSession createSession({
    required String id,
    required String name,
    required TerminalInputService inputService,
    TerminalConfig? terminalConfig,
    bool isLocal = false,
    String? serverInfo,
  }) {
    final session = TerminalSession(
      id: id,
      name: name,
      inputService: inputService,
      terminalConfig: terminalConfig,
      isLocal: isLocal,
      serverInfo: serverInfo,
    );
    _sessions[id] = session;
    session.initialize();
    return session;
  }

  /// 获取会话
  TerminalSession? getSession(String id) {
    return _sessions[id];
  }

  /// 关闭会话
  void closeSession(String id) {
    final session = _sessions[id];
    session?.dispose();
    _sessions.remove(id);
  }

  /// 获取所有会话
  List<TerminalSession> getAllSessions() {
    return _sessions.values.toList();
  }

  /// 清理所有会话
  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }
}
