import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../../data/models/ssh_connection.dart';
import '../../utils/sentry_service.dart';
import 'app_config_service.dart';
import 'socks5_proxy_socket.dart';
import 'ssh_config_service.dart';
import 'terminal_input_service.dart';

export 'jump_host_tunnel.dart';
export 'socks5_proxy_socket.dart';

/// SSH 连接状态
enum SshConnectionState { disconnected, connecting, connected, error }

/// SSHClient 工厂签名（测试时可注入替身，默认使用真实 [SSHClient]）
typedef SSHClientFactory =
    SSHClient Function(
      SSHSocket socket, {
      required String username,
      SSHPasswordRequestHandler? onPasswordRequest,
      List<SSHKeyPair>? identities,
      Duration? keepAliveInterval,
    });

/// SSH socket 连接器签名（测试时可注入替身，默认使用 [SSHSocket.connect]）
typedef SSHSocketConnector =
    Future<SSHSocket> Function(String host, int port, {Duration? timeout});

/// ~/.ssh/config 条目解析器签名（测试时可注入替身，默认使用 [SshConfigService.findHostEntry]）
typedef SshConfigEntryResolver =
    SshConfigEntry? Function(String host, {String? filePath});

/// SSH 连接服务
class SshService implements TerminalInputService {
  final AppConfigService? _appConfigService;
  final SSHClientFactory? _clientFactory;
  final SSHSocketConnector? _socketConnector;
  final SshConfigEntryResolver? _sshConfigResolver;

  SshService({
    AppConfigService? appConfigService,
    SSHClientFactory? clientFactory,
    SSHSocketConnector? socketConnector,
    SshConfigEntryResolver? sshConfigResolver,
  }) : _appConfigService = appConfigService,
       _clientFactory = clientFactory,
       _socketConnector = socketConnector,
       _sshConfigResolver = sshConfigResolver;

  /// 解析 ~/.ssh/config 条目（优先使用注入的解析器，默认 [SshConfigService.findHostEntry]）
  SshConfigEntry? _resolveSshConfigEntry(String host, {String? filePath}) {
    final resolver = _sshConfigResolver;
    return (resolver ?? SshConfigService.findHostEntry)(
      host,
      filePath: filePath,
    );
  }

  AppConfigService get _config =>
      _appConfigService ?? AppConfigService.getInstance();

  /// 连接 SSH socket（优先使用注入的连接器，默认 [SSHSocket.connect]）
  Future<SSHSocket> _connectSocket(String host, int port, {Duration? timeout}) {
    final connector = _socketConnector;
    if (connector != null) {
      return connector(host, port, timeout: timeout);
    }
    return SSHSocket.connect(host, port, timeout: timeout);
  }

  /// 创建 SSH 客户端（优先使用注入的工厂，默认 [SSHClient]）
  SSHClient _createClient(
    SSHSocket socket, {
    required String username,
    SSHPasswordRequestHandler? onPasswordRequest,
    List<SSHKeyPair>? identities,
    Duration? keepAliveInterval,
  }) {
    final factory = _clientFactory;
    if (factory != null) {
      return factory(
        socket,
        username: username,
        onPasswordRequest: onPasswordRequest,
        identities: identities,
        keepAliveInterval: keepAliveInterval,
      );
    }
    return SSHClient(
      socket,
      username: username,
      onPasswordRequest: onPasswordRequest,
      identities: identities,
      keepAliveInterval: keepAliveInterval ?? const Duration(seconds: 10),
    );
  }

  SSHClient? _client;
  final _stateController = StreamController<SshConnectionState>.broadcast(
    sync: true,
  );
  final _outputController = StreamController<String>.broadcast(sync: true);
  SSHSession? _session;
  Completer<void>? _sessionDoneCompleter;

  // 跳板机相关
  SSHClient? _jumpClient;

  // 性能优化：输出缓冲和批处理
  final _outputBuffer = StringBuffer();
  Timer? _outputTimer;
  static const _outputBufferMaxSize = 65536;
  static const _outputFlushInterval = Duration(milliseconds: 16);

  // 是否已显示过 Last login 信息
  bool _hasShownLastLogin = false;

  /// OS 类型: 'Linux', 'Darwin' (macOS), 'Windows' 等
  String get osType {
    if (Platform.isMacOS) return 'Darwin';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Linux';
  }

  /// 最近一次设置的PTY宽度
  int _ptyWidth = 80;

  /// 最近一次设置的PTY高度
  int _ptyHeight = 24;

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

  /// 性能优化：批量输出处理（固定间隔刷新，不停顿）
  void _scheduleOutputFlush() {
    _outputTimer ??= Timer.periodic(_outputFlushInterval, (_) {
      _flushOutputBuffer();
    });
  }

  void _flushOutputBuffer() {
    if (_isDisposed || _outputController.isClosed) return;

    if (_outputBuffer.isEmpty) {
      _outputTimer?.cancel();
      _outputTimer = null;
      return;
    }

    var output = _outputBuffer.toString();
    _outputBuffer.clear();

    // 过滤重复的 Last login 行 — 避免 split('\n') 整个缓冲
    if (!_hasShownLastLogin && output.contains('Last login:')) {
      _hasShownLastLogin = true;
      // 按行扫描，只保留第一个 Last login 行
      var result = StringBuffer();
      var start = 0;
      var foundLastLogin = false;
      while (start < output.length) {
        var end = output.indexOf('\n', start);
        if (end == -1) end = output.length;
        final line = output.substring(start, end);
        if (line.startsWith('Last login:')) {
          if (!foundLastLogin) {
            result.writeln(line);
            foundLastLogin = true;
          }
        } else {
          result.writeln(line);
        }
        start = end + 1;
      }
      output = result.toString().trimRight();
    }

    if (output.isNotEmpty) {
      _outputController.add(output);
    }
  }

  /// 连接到 SSH 服务器
  Future<void> connect(SshConnection connection) async {
    try {
      _updateState(SshConnectionState.connecting);

      // 通过 SOCKS5 代理连接（如果配置了）
      final timeout = Duration(milliseconds: connection.connectTimeout);
      // 跳板机模式下目标主机通常不可直达，连接由 _connectViaJumpHost 独立完成
      // （先连跳板机，再经其 direct-tcpip 通道打穿到目标）。这里不预先直连
      // 目标主机，否则会白白发起并泄漏一条 TCP 连接。
      SSHSocket? socket;
      if (connection.jumpHost == null) {
        if (connection.socks5Proxy != null) {
          final proxy = connection.socks5Proxy!;
          socket = await connectViaSocks5Proxy(
            proxy.host,
            proxy.port,
            connection.host,
            connection.port,
            username: proxy.username,
            password: proxy.password,
            timeout: timeout,
          );
        } else {
          socket = await _connectSocket(
            connection.host,
            connection.port,
            timeout: timeout,
          );
        }
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

          final configEntry = _resolveSshConfigEntry(configHost);
          if (configEntry == null) {
            throw Exception('未在 ~/.ssh/config 中找到主机 "$configHost" 的配置');
          }

          // 使用配置中的主机和端口
          final targetHost = configEntry.getConnectHost();
          final targetPort = configEntry.port ?? connection.port;

          // 重新创建 socket（如果使用了不同的 host/port）
          // 避免首个 socket 泄漏
          try {
            await socket?.close();
          } catch (e, stackTrace) {
            // close() 幂等，此处抛出属异常路径，上报一次便于排查
            unawaited(SentryService().captureException(e, stackTrace: stackTrace));
          }
          // 跳板机模式下目标主机通常不可直达，连接由 _connectViaJumpHost 独立完成。
          // 这里不预先直连目标主机（否则会白白发起并泄漏一条 TCP 连接，
          // 且目标不可直达时还会导致连接失败）。
          if (connection.jumpHost == null) {
            if (connection.socks5Proxy != null) {
              final proxy = connection.socks5Proxy!;
              socket = await connectViaSocks5Proxy(
                proxy.host,
                proxy.port,
                targetHost,
                targetPort,
                username: proxy.username,
                password: proxy.password,
                timeout: timeout,
              );
            } else {
              socket = await _connectSocket(
                targetHost,
                targetPort,
                timeout: timeout,
              );
            }
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
                    // 尝试下一个身份文件（单文件解析失败属预期流程，不上报）
                    continue;
                  }
                }
              } catch (_) {
                // 尝试下一个身份文件（读取失败同样属预期流程）
                continue;
              }
            }
            // 全部身份文件均不可用：记录一次，便于定位配置问题
            if (identities == null) {
              unawaited(
                SentryService().captureException(
                  StateError(
                    'SSH config identity files all failed: '
                    '${configEntry.identityFiles!.length} file(s)',
                  ),
                ),
              );
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
        _client = _createClient(
          socket!,
          username: connection.username,
          onPasswordRequest: connection.authType == AuthType.password
              ? () => password!
              : null,
          identities: identities,
          keepAliveInterval: Duration(
            milliseconds: _config.ssh.keepaliveInterval,
          ),
        );
      }

      // 创建交互式会话
      // 修复：直接使用 PTY 模式，避免 pre-exec 消耗 MOTD
      // 之前的 _getShellEnvironment() 会通过 execute() 打开额外通道，
      // 导致首次通道被占用，欢迎信息只在第一个通道发送
      SSHSession? session;
      try {
        // 首选 PTY 模式（支持颜色、交互），使用保存的最新尺寸
        session = await _client!.shell(
          pty: SSHPtyConfig(
            type: 'xterm',
            width: _ptyWidth,
            height: _ptyHeight,
          ),
        );
      } catch (e) {
        // 回退：不使用 PTY 的标准 shell
        try {
          session = await _client!.shell();
        } catch (e2) {
          throw Exception('建立会话失败: $e2');
        }
      }
      _session = session;
      _sessionDoneCompleter = Completer<void>();
      unawaited(_session!.done.then((_) => _onSessionDone()));

      // 使用 UTF-8 解码器正确处理多字节字符（如中文）
      _session!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) {
              _outputBuffer.write(data);
              if (_outputBuffer.length > _outputBufferMaxSize) {
                _flushOutputBuffer();
              } else {
                _scheduleOutputFlush();
              }
            },
            onError: (Object error) {
              if (!_isDisposed && !_outputController.isClosed) {
                _outputController.add('\r\n[输出流错误: $error]\r\n');
              }
              _onSessionDone();
            },
            onDone: () {
              _onSessionDone();
            },
            cancelOnError: false,
          );

      _session!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) {
              _outputBuffer.write(data);
              _scheduleOutputFlush();
            },
            onError: (Object error) {
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
      // 连接失败时回收已创建的客户端（含跳板机），避免泄漏打开的连接。
      // shell() 建立失败是典型场景：_client 已在前面创建但会话未建立；
      // 跳板机模式下 _jumpClient 及其上的 ssh -L 隧道同理。close() 幂等。
      try {
        unawaited(_jumpClient?.close());
      } catch (e, stackTrace) {
        // close() 幂等，抛出属异常路径，上报一次便于排查
        unawaited(SentryService().captureException(e, stackTrace: stackTrace));
      }
      _jumpClient = null;
      try {
        unawaited(_client?.close());
      } catch (e, stackTrace) {
        // close() 幂等，抛出属异常路径，上报一次便于排查
        unawaited(SentryService().captureException(e, stackTrace: stackTrace));
      }
      _client = null;

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
        const Utf8Decoder(allowMalformed: true),
      )) {
        output.add(data);
        if (!silent && !_isDisposed && !_outputController.isClosed) {
          // 通过 _outputBuffer 路由，确保与交互输出的顺序一致
          _outputBuffer.write(data);
          _scheduleOutputFlush();
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
      try {
        final bytes = const Utf8Encoder().convert(input);
        _session!.stdin.add(bytes);
      } catch (e) {
        // stdin.add 在 session 已关闭时会失败，静默忽略
      }
    }
  }

  /// 调整终端尺寸
  @override
  void resize(int rows, int columns) {
    // 保存最新的尺寸，确保连接建立前的尺寸变化不会丢失
    _ptyHeight = rows;
    _ptyWidth = columns;

    // 如果会话已经创建，立刻发送resize请求
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
      // 刷新剩余输出缓冲
      _outputTimer?.cancel();
      _outputTimer = null;
      _flushOutputBuffer();

      _session?.close();
      _session = null;

      // 清理目标连接
      await _client?.close();
      _client = null;

      // 清理跳板机资源
      if (_jumpClient != null) {
        await _jumpClient?.close();
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

  /// SSH session 意外断开时调用（由 _session.done 触发）
  void _onSessionDone() {
    if (_isDisposed) return;
    // 刷新剩余输出缓冲
    _outputTimer?.cancel();
    _outputTimer = null;
    _flushOutputBuffer();
    if (_sessionDoneCompleter?.isCompleted == false) {
      _sessionDoneCompleter?.complete();
    }
    _sessionDoneCompleter = null;
    _session = null;
    if (_state != SshConnectionState.disconnected &&
        _state != SshConnectionState.error) {
      _updateState(SshConnectionState.disconnected);
      if (!_outputController.isClosed) {
        _outputController.add('\r\n[连接已断开]\r\n');
      }
    }
  }

  /// 通过跳板机连接到目标服务器
  Future<void> _connectViaJumpHost(SshConnection connection) async {
    final jumpHost = connection.jumpHost!;

    // 1. 连接到跳板机
    _outputController.add('正在连接到跳板机 ${jumpHost.host}:${jumpHost.port}...\r\n');

    final jumpSocket = await _connectSocket(jumpHost.host, jumpHost.port);

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
    final jumpClient = _createClient(
      jumpSocket,
      username: jumpHost.username,
      onPasswordRequest: jumpHost.authType == AuthType.password
          ? () => jumpPassword!
          : null,
      identities: jumpIdentities,
      keepAliveInterval: Duration(milliseconds: _config.ssh.keepaliveInterval),
    );

    // 立即记录跳板机客户端：其后的 forwardLocal / 目标客户端创建若失败，
    // connect() 的 catch 才能通过 _jumpClient 关闭它，避免已建立的跳板机连接泄漏。
    _jumpClient = jumpClient;

    _outputController.add('跳板机连接成功\r\n');

    // 2. 在跳板机上创建到目标服务器的端口转发。
    //    使用 dartssh2 原生的 direct-tcpip 转发通道：由 SSH 协议通过已建立的
    //    跳板机连接直接打穿到 targetHost:targetPort，无需再在跳板机上 shell
    //    执行 `ssh -L`、分配本地端口并轮询探测（那套做法只在「本机==跳板机」时成立）。
    _outputController.add('建立跳板机隧道...\r\n');

    final targetSocket = await jumpClient.forwardLocal(
      connection.host,
      connection.port,
    );

    _outputController.add('跳板机隧道建立成功\r\n');

    // 3. 通过隧道连接到目标服务器
    _outputController.add('通过跳板机连接到目标服务器...\r\n');

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

    _client = _createClient(
      targetSocket,
      username: connection.username,
      onPasswordRequest: connection.authType == AuthType.password
          ? () => connection.password!
          : null,
      identities: targetIdentities,
      keepAliveInterval: Duration(milliseconds: _config.ssh.keepaliveInterval),
    );

    _outputController.add('跳板机连接建立成功\r\n');
  }

  /// 清理资源
  @override
  void dispose() {
    _isDisposed = true;

    // 执行真正的拆除。不能复用 disconnect() —— 它开头的 `if (_isDisposed) return;`
    // 会因 _isDisposed 已置位而直接早退，导致目标客户端（及跳板机客户端与其上
    // 的 ssh -L 隧道孤儿进程）泄漏。
    _teardown();

    if (!_stateController.isClosed) {
      _stateController.close();
    }
    if (!_outputController.isClosed) {
      _outputController.close();
    }
  }

  /// dispose 专用拆除：关闭会话与底层客户端（跳板机 + 目标），并清空缓冲。
  ///
  /// 与各 close() 一致，采用同步触发、fire-and-forget 的写法；各 close() 幂等，
  /// 重复调用安全。
  void _teardown() {
    _outputTimer?.cancel();
    _outputBuffer.clear();
    if (_sessionDoneCompleter?.isCompleted == false) {
      _sessionDoneCompleter?.complete();
    }

    try {
      _session?.close();
    } catch (e, stackTrace) {
      // close() 幂等，抛出属异常路径，上报一次便于排查
      unawaited(SentryService().captureException(e, stackTrace: stackTrace));
    }
    // 先关跳板机：其上的 ssh -L 隧道进程随客户端关闭而终止，避免孤儿进程。
    try {
      unawaited(_jumpClient?.close());
    } catch (e, stackTrace) {
      // close() 幂等，抛出属异常路径，上报一次便于排查
      unawaited(SentryService().captureException(e, stackTrace: stackTrace));
    }
    _jumpClient = null;

    try {
      unawaited(_client?.close());
    } catch (e, stackTrace) {
      // close() 幂等，抛出属异常路径，上报一次便于排查
      unawaited(SentryService().captureException(e, stackTrace: stackTrace));
    }
    _client = null;
    _session = null;
  }
}
