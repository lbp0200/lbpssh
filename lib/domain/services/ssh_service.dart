import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../../data/models/ssh_connection.dart';
import 'ssh_config_service.dart';
import 'terminal_input_service.dart';

/// SOCKS5 代理 Socket 实现（实现 SSHSocket 接口）
class _Socks5ProxySocket implements SSHSocket {
  final Socket _socket;

  _Socks5ProxySocket(this._socket);

  @override
  Stream<Uint8List> get stream => _socket.cast<Uint8List>();

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> close() async {
    await _socket.close();
  }

  @override
  Future<void> get done => _socket.done;

  @override
  void destroy() {
    _socket.destroy();
  }

  @override
  String toString() {
    final address = '${_socket.remoteAddress.host}:${_socket.remotePort}';
    return '_Socks5ProxySocket($address)';
  }
}

/// 连接到 SOCKS5 代理并返回 SSHSocket
Future<SSHSocket> connectViaSocks5Proxy(
  String proxyHost,
  int proxyPort,
  String targetHost,
  int targetPort, {
  String? username,
  String? password,
}) async {
  // 连接到 SOCKS5 代理服务器
  final socket = await Socket.connect(proxyHost, proxyPort);

  // SOCKS5 握手
  // 1. 发送认证方法列表
  final authMethods = <int>[];
  if (username != null && password != null) {
    authMethods.add(0x02); // 用户名密码认证
  }
  authMethods.add(0x00); // 无认证

  final handshake = <int>[
    0x05, // SOCKS 版本
    authMethods.length,
    ...authMethods,
  ];
  socket.add(handshake);

  // 读取服务器选择的认证方法
  final handshakeResponse = await socket.first;
  if (handshakeResponse[0] != 0x05) {
    socket.destroy();
    throw Exception('SOCKS5 握手失败：无效的协议版本');
  }

  // 如果需要用户名密码认证
  if (handshakeResponse[1] == 0x02) {
    if (username == null || password == null) {
      socket.destroy();
      throw Exception('SOCKS5 代理需要用户名密码认证');
    }

    // 发送用户名密码认证
    final authRequest = <int>[
      0x01, // 子协议版本
      username.length,
      ...utf8.encode(username),
      password.length,
      ...utf8.encode(password),
    ];
    socket.add(authRequest);

    // 读取认证结果
    final authResponse = await socket.first;
    if (authResponse[1] != 0x00) {
      socket.destroy();
      throw Exception('SOCKS5 用户名密码认证失败');
    }
  } else if (handshakeResponse[1] != 0x00) {
    socket.destroy();
    throw Exception('SOCKS5 代理不支持所选的认证方式');
  }

  // 发送连接请求
  final connectRequest = <int>[
    0x05, // SOCKS 版本
    0x01, // CONNECT 命令
    0x00, // 保留字段
    0x03, // 地址类型：域名
    targetHost.length,
    ...utf8.encode(targetHost),
    (targetPort >> 8) & 0xFF, // 端口高字节
    targetPort & 0xFF, // 端口低字节
  ];
  socket.add(connectRequest);

  // 读取连接响应
  final connectResponse = await socket.first;
  if (connectResponse[0] != 0x05) {
    socket.destroy();
    throw Exception('SOCKS5 连接失败：无效的协议版本');
  }

  if (connectResponse[1] != 0x00) {
    final errorCodes = {
      0x01: 'SOCKS5 错误：一般性失败',
      0x02: 'SOCKS5 错误：连接被拒绝',
      0x03: 'SOCKS5 错误：网络不可达',
      0x04: 'SOCKS5 错误：主机不可达',
      0x05: 'SOCKS5 错误：连接被拒绝',
      0x06: 'SOCKS5 错误：TTL 过期',
      0x07: 'SOCKS5 错误：不支持的命令',
      0x08: 'SOCKS5 错误：不支持的地址类型',
    };
    socket.destroy();
    throw Exception(
      errorCodes[connectResponse[1]] ??
          'SOCKS5 错误：未知错误 (${connectResponse[1]})',
    );
  }

  return _Socks5ProxySocket(socket);
}

/// SSH 连接状态
enum SshConnectionState { disconnected, connecting, connected, error }

/// SSH 连接服务
class SshService implements TerminalInputService {
  SSHClient? _client;
  final _stateController = StreamController<SshConnectionState>.broadcast();
  final _outputController = StreamController<String>.broadcast();
  SSHSession? _session;

  // 跳板机相关
  SSHClient? _jumpClient;

  // 性能优化：输出缓冲和批处理
  final _outputBuffer = StringBuffer();
  Timer? _outputTimer;

  // 是否已显示过 Last login 信息
  bool _hasShownLastLogin = false;

  /// OS 类型: 'Linux', 'Darwin' (macOS), 'Windows' 等
  String _osType = 'Linux';

  /// 获取 OS 类型
  String get osType => _osType;

  /// 输出流
  @override
  Stream<String> get outputStream => _outputController.stream;

  /// 状态流（转换为 bool: true = connected, false = disconnected）
  @override
  Stream<bool> get stateStream {
    return _stateController.stream.map(
      (state) => state == SshConnectionState.connected,
    );
  }

  /// 获取 SSH 连接状态流（返回详细状态）
  Stream<SshConnectionState> get sshStateStream => _stateController.stream;

  /// 当前连接状态
  SshConnectionState _state = SshConnectionState.disconnected;
  SshConnectionState get state => _state;

  /// 获取 SFTP 客户端（如果已连接）
  Future<SftpClient?> getSftpClient() async {
    if (_client != null && _state == SshConnectionState.connected) {
      return _client!.sftp();
    }
    return null;
  }

  /// 性能优化：批量输出处理
  void _scheduleOutputFlush() {
    _outputTimer?.cancel();
    _outputTimer = Timer(const Duration(milliseconds: 10), () {
      if (_isDisposed || _outputController.isClosed) return;

      var output = _outputBuffer.toString();
      _outputBuffer.clear();

      // 过滤重复的 Last login 行
      if (!_hasShownLastLogin && output.contains('Last login:')) {
        _hasShownLastLogin = true;
        // 保留第一行（Last login），删除后续的
        final lines = output.split('\n');
        final lastLoginLines = <String>[];
        final otherLines = <String>[];
        bool foundLastLogin = false;

        for (final line in lines) {
          if (line.startsWith('Last login:')) {
            if (!foundLastLogin) {
              lastLoginLines.add(line);
              foundLastLogin = true;
            }
            // 跳过重复的 Last login 行
          } else {
            otherLines.add(line);
          }
        }

        output = [...lastLoginLines, ...otherLines].join('\n');
      }

      if (output.isNotEmpty) {
        _outputController.add(output);
      }
    });
  }

  /// 连接到 SSH 服务器
  Future<void> connect(SshConnection connection) async {
    try {
      _updateState(SshConnectionState.connecting);

      // 通过 SOCKS5 代理连接（如果配置了）
      SSHSocket socket;
      if (connection.socks5Proxy != null) {
        final proxy = connection.socks5Proxy!;
        socket = await connectViaSocks5Proxy(
          proxy.host,
          proxy.port,
          connection.host,
          connection.port,
          username: proxy.username,
          password: proxy.password,
        );
      } else {
        socket = await SSHSocket.connect(connection.host, connection.port);
      }

      // 根据认证方式准备认证信息
      String? password;
      List<SSHKeyPair>? identities;
      switch (connection.authType) {
        case AuthType.password:
          password = connection.password;
          if (password == null || password.isEmpty) {
            throw Exception('密码未设置');
          }
          break;

        case AuthType.key:
          if (connection.privateKeyContent == null ||
              connection.privateKeyContent!.isEmpty) {
            throw Exception('私钥内容未设置');
          }
          try {
            identities = SSHKeyPair.fromPem(connection.privateKeyContent!);
          } catch (e) {
            throw Exception('私钥格式错误: $e');
          }
          break;

        case AuthType.keyWithPassword:
          if (connection.privateKeyContent == null ||
              connection.privateKeyContent!.isEmpty) {
            throw Exception('私钥内容未设置');
          }
          if (connection.keyPassphrase == null ||
              connection.keyPassphrase!.isEmpty) {
            throw Exception('密钥密码未设置');
          }
          try {
            identities = SSHKeyPair.fromPem(
              connection.privateKeyContent!,
              connection.keyPassphrase!,
            );
          } catch (e) {
            throw Exception('私钥或密码错误: $e');
          }
          break;

        case AuthType.sshConfig:
          // 从 SSH config 文件获取认证信息
          final configHost = connection.sshConfigHost;
          if (configHost == null || configHost.isEmpty) {
            throw Exception('SSH Config 主机名未设置');
          }

          final configEntry = SshConfigService.findHostEntry(configHost);
          if (configEntry == null) {
            throw Exception('未在 ~/.ssh/config 中找到主机 "$configHost" 的配置');
          }

          // 使用配置中的主机和端口
          final targetHost = configEntry.getConnectHost();
          final targetPort = configEntry.port ?? connection.port;

          // 重新创建 socket（如果使用了不同的 host/port）
          if (connection.socks5Proxy != null) {
            final proxy = connection.socks5Proxy!;
            socket = await connectViaSocks5Proxy(
              proxy.host,
              proxy.port,
              targetHost,
              targetPort,
              username: proxy.username,
              password: proxy.password,
            );
          } else {
            socket = await SSHSocket.connect(targetHost, targetPort);
          }

          // 处理身份文件
          if (configEntry.identityFiles != null &&
              configEntry.identityFiles!.isNotEmpty) {
            for (final identityFile in configEntry.identityFiles!) {
              try {
                final keyFile = File(
                  identityFile.replaceFirst(
                    '~',
                    Platform.environment['HOME'] ?? '',
                  ),
                );
                if (await keyFile.exists()) {
                  final keyContent = await keyFile.readAsString();
                  try {
                    identities = SSHKeyPair.fromPem(keyContent);
                    break;
                  } catch (_) {
                    // 尝试下一个身份文件
                    continue;
                  }
                }
              } catch (_) {
                continue;
              }
            }
          }

          // 如果没有找到有效的身份文件，使用密钥认证
          if (identities == null) {
            if (connection.privateKeyContent != null &&
                connection.privateKeyContent!.isNotEmpty) {
              try {
                identities = SSHKeyPair.fromPem(connection.privateKeyContent!);
              } catch (e) {
                throw Exception('私钥格式错误: $e');
              }
            } else if (connection.authType == AuthType.sshConfig) {
              throw Exception('SSH Config 中未配置有效的身份文件，且未在连接中指定私钥');
            }
          }
          break;
      }

      // 处理跳板机连接（跳板机模式下会自己创建 _client）
      if (connection.jumpHost != null) {
        await _connectViaJumpHost(connection);
      } else {
        // 直接连接到目标服务器，创建 SSH 客户端
        _client = SSHClient(
          socket,
          username: connection.username,
          onPasswordRequest: connection.authType == AuthType.password
              ? () => password!
              : null,
          identities: identities,
        );
      }

      // 创建交互式会话
      SSHSession? session;
      try {
        // 第一次尝试：带环境变量
        session = await _client!.shell(
          environment: await _getShellEnvironment(),
        );
      } catch (e) {
        // 第二次尝试：简化的 pty 配置
        try {
          session = await _client!.shell(
            pty: const SSHPtyConfig(type: 'xterm', width: 80, height: 24),
          );
        } catch (e2) {
          throw Exception('建立会话失败: $e2');
        }
      }
      _session = session;
      // 使用 UTF-8 解码器正确处理多字节字符（如中文）
      _session!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(
            (data) {
              // 性能优化：批量处理输出
              _outputBuffer.write(data);
              _scheduleOutputFlush();
            },
            onError: (error) {
              if (!_isDisposed && !_outputController.isClosed) {
                _outputController.add('\r\n[输出流错误: $error]\r\n');
              }
            },
            onDone: () {
              // 输出流关闭
            },
            cancelOnError: false,
          );

      _session!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(
            (data) {
              _outputController.add(data);
            },
            onError: (error) {
              if (!_isDisposed && !_outputController.isClosed) {
                _outputController.add('\r\n[错误流错误: $error]\r\n');
              }
            },
            onDone: () {
              // 错误流关闭
            },
            cancelOnError: false,
          );

      _updateState(SshConnectionState.connected);
    } catch (e) {
      _updateState(SshConnectionState.error);
      _outputController.add('连接错误: $e\n');
      rethrow;
    }
  }

  /// 执行命令（非交互式）
  @override
  Future<String> executeCommand(String command, {bool silent = false}) async {
    if (_client == null || _state != SshConnectionState.connected) {
      throw Exception('未连接到服务器');
    }

    try {
      final session = await _client!.execute(command);
      final output = <String>[];
      await for (final data in session.stdout.cast<List<int>>().transform(
        const Utf8Decoder(),
      )) {
        output.add(data);
        if (!silent && !_isDisposed && !_outputController.isClosed) {
          _outputController.add(data);
        }
      }
      return output.join();
    } catch (e) {
      if (!silent && !_isDisposed && !_outputController.isClosed) {
        _outputController.add('命令执行错误: $e\n');
      }
      rethrow;
    }
  }

  /// 发送输入到交互式会话
  @override
  void sendInput(String input) {
    if (_session != null && _state == SshConnectionState.connected) {
      // 使用 UTF-8 编码确保多字节字符（如中文）正确传输
      final bytes = const Utf8Encoder().convert(input);
      _session!.stdin.add(bytes);
    }
  }

  /// 调整终端尺寸
  @override
  void resize(int rows, int columns) {
    // 移除连接状态检查，确保连接建立前的尺寸变化也能记录
    // SSH 连接成功后，dartssh2 会自动应用最近一次 resize 参数
    if (_session != null) {
      try {
        _session!.resizeTerminal(columns, rows);
      } catch (e) {
        // 调整终端尺寸失败，静默处理
      }
    }
  }

  bool _isDisposed = false;

  /// 断开连接
  Future<void> disconnect() async {
    if (_isDisposed) return;

    try {
      _session?.close();
      _session = null;

      // 清理目标连接
      _client?.close();
      _client = null;

      // 清理跳板机资源
      if (_jumpClient != null) {
        _jumpClient?.close();
        _jumpClient = null;
      }

      if (!_isDisposed) {
        _updateState(SshConnectionState.disconnected);
      }
    } catch (e) {
      if (!_isDisposed && !_outputController.isClosed) {
        _outputController.add('断开连接错误: $e\n');
      }
    }
  }

  /// 更新状态
  void _updateState(SshConnectionState newState) {
    if (_isDisposed || _stateController.isClosed) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// 自动发现用户的默认shell环境
  Future<Map<String, String>> _getShellEnvironment() async {
    final environment = <String, String>{};

    try {
      // 尝试获取用户的默认shell
      // 首先检查 $SHELL 环境变量
      final session = await _client!.execute('echo \$SHELL');
      String shellPath = '';

      await for (final data in session.stdout.cast<List<int>>()) {
        shellPath += String.fromCharCodes(data);
      }
      shellPath = shellPath.trim();

      // 如果 \$SHELL 为空，尝试从 /etc/passwd 获取
      if (shellPath.isEmpty) {
        final passwdSession = await _client!.execute(
          'grep "^\\\$(whoami):" /etc/passwd | cut -d: -f7',
        );
        await for (final data in passwdSession.stdout.cast<List<int>>()) {
          shellPath += String.fromCharCodes(data);
        }
        shellPath = shellPath.trim();
      }

      // 设置SHELL环境变量
      if (shellPath.isNotEmpty) {
        environment['SHELL'] = shellPath;
      } else {
        // 默认常见的shell，按优先级排序
        final commonShells = [
          '/bin/zsh',
          '/bin/bash',
          '/bin/sh',
          '/usr/bin/zsh',
          '/usr/bin/bash',
        ];

        for (final shell in commonShells) {
          try {
            final testSession = await _client!.execute(
              'test -x "$shell" && echo "$shell"',
            );
            String result = '';
            await for (final data in testSession.stdout.cast<List<int>>()) {
              result += String.fromCharCodes(data);
            }
            if (result.trim().isNotEmpty) {
              environment['SHELL'] = shell;
              break;
            }
          } catch (e) {
            // 忽略错误，继续尝试下一个shell
            continue;
          }
        }
      }

      // 设置其他常用的环境变量
      environment['TERM'] = 'xterm-256color';
      environment['LANG'] = 'en_US.UTF-8';
      environment['LC_ALL'] = 'en_US.UTF-8';

      // 尝试获取用户的HOME目录
      try {
        final homeSession = await _client!.execute('echo \$HOME');
        String homePath = '';
        await for (final data in homeSession.stdout.cast<List<int>>()) {
          homePath += String.fromCharCodes(data);
        }
        homePath = homePath.trim();
        if (homePath.isNotEmpty) {
          environment['HOME'] = homePath;
        }
      } catch (e) {
        // 忽略错误
      }

      // 尝试获取PATH
      try {
        final pathSession = await _client!.execute('echo \$PATH');
        String pathValue = '';
        await for (final data in pathSession.stdout.cast<List<int>>()) {
          pathValue += String.fromCharCodes(data);
        }
        pathValue = pathValue.trim();
        if (pathValue.isNotEmpty) {
          environment['PATH'] = pathValue;
        }
      } catch (e) {
        // 忽略错误
      }
    } catch (e) {
      // 如果检测失败，使用最小环境变量
      environment['SHELL'] = '/bin/bash';
      environment['TERM'] = 'xterm-256color';
      environment['LANG'] = 'en_US.UTF-8';
    }

    return environment;
  }

  /// 通过跳板机连接到目标服务器
  Future<void> _connectViaJumpHost(SshConnection connection) async {
    final jumpHost = connection.jumpHost!;

    // 1. 连接到跳板机
    _outputController.add('正在连接到跳板机 ${jumpHost.host}:${jumpHost.port}...\r\n');

    final jumpSocket = await SSHSocket.connect(jumpHost.host, jumpHost.port);

    // 根据跳板机的认证方式准备认证信息
    String? jumpPassword;
    List<SSHKeyPair>? jumpIdentities;

    switch (jumpHost.authType) {
      case AuthType.password:
        jumpPassword = jumpHost.password;
        if (jumpPassword == null || jumpPassword.isEmpty) {
          throw Exception('跳板机密码未设置');
        }
        break;
      case AuthType.key:
        if (jumpHost.privateKeyPath == null ||
            jumpHost.privateKeyPath!.isEmpty) {
          throw Exception('跳板机私钥路径未设置');
        }
        // 读取私钥文件
        try {
          final keyFile = File(jumpHost.privateKeyPath!);
          final keyContent = await keyFile.readAsString();
          jumpIdentities = SSHKeyPair.fromPem(keyContent);
        } catch (e) {
          throw Exception('跳板机私钥读取失败: $e');
        }
        break;
      case AuthType.keyWithPassword:
        if (jumpHost.privateKeyPath == null ||
            jumpHost.privateKeyPath!.isEmpty) {
          throw Exception('跳板机私钥路径未设置');
        }
        if (jumpHost.password == null || jumpHost.password!.isEmpty) {
          throw Exception('跳板机密钥密码未设置');
        }
        try {
          final keyFile = File(jumpHost.privateKeyPath!);
          final keyContent = await keyFile.readAsString();
          jumpIdentities = SSHKeyPair.fromPem(keyContent, jumpHost.password!);
        } catch (e) {
          throw Exception('跳板机私钥或密码错误: $e');
        }
        break;
      default:
        throw Exception('跳板机不支持 SSH Config 认证方式');
    }

    // 创建跳板机SSH客户端
    final jumpClient = SSHClient(
      jumpSocket,
      username: jumpHost.username,
      onPasswordRequest: jumpHost.authType == AuthType.password
          ? () => jumpPassword!
          : null,
      identities: jumpIdentities,
    );

    _outputController.add('跳板机连接成功\r\n');

    // 2. 在跳板机上创建到目标服务器的端口转发
    _outputController.add('建立跳板机隧道...\r\n');

    // 使用本地端口转发（L端口转发）将本地端口转发到目标服务器
    final localPort = 2222; // 使用一个临时本地端口

    // 先在跳板机上建立隧道
    final tunnelCmd =
        'ssh -L $localPort:${connection.host}:${connection.port} localhost';
    await jumpClient.execute(tunnelCmd);

    // 等待一下让隧道建立
    await Future.delayed(const Duration(seconds: 2));

    _outputController.add('跳板机隧道建立成功 (本地端口: $localPort)\r\n');

    // 3. 通过隧道连接到目标服务器
    _outputController.add('通过跳板机连接到目标服务器...\r\n');

    final targetSocket = await SSHSocket.connect('localhost', localPort);

    // 创建目标服务器的SSH客户端
    // 注意：这里需要重新创建identities，因为前面的局部变量已经超出作用域
    List<SSHKeyPair>? targetIdentities;
    switch (connection.authType) {
      case AuthType.key:
      case AuthType.keyWithPassword:
        if (connection.privateKeyContent == null ||
            connection.privateKeyContent!.isEmpty) {
          throw Exception('目标服务器私钥内容未设置');
        }
        try {
          targetIdentities = SSHKeyPair.fromPem(
            connection.privateKeyContent!,
            connection.keyPassphrase,
          );
        } catch (e) {
          throw Exception('目标服务器私钥格式错误: $e');
        }
        break;
      default:
        break;
    }

    _client = SSHClient(
      targetSocket,
      username: connection.username,
      onPasswordRequest: connection.authType == AuthType.password
          ? () => connection.password!
          : null,
      identities: targetIdentities,
    );

    _outputController.add('跳板机连接建立成功\r\n');

    // 保存跳板机相关资源以便关闭连接时清理
    _jumpClient = jumpClient;
  }

  /// 清理资源
  @override
  void dispose() {
    _isDisposed = true;

    // 清理定时器
    _outputTimer?.cancel();

    disconnect();

    // 清理输出缓冲
    _outputBuffer.clear();

    if (!_stateController.isClosed) {
      _stateController.close();
    }
    if (!_outputController.isClosed) {
      _outputController.close();
    }
  }
}
