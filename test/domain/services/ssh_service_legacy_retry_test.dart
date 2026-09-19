import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSocket extends Fake implements SSHSocket {
  int closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

/// shell() 始终抛出协商失败链（模拟只懂旧算法的服务器），close 可计数。
class _NegotiationFailClient extends Fake implements SSHClient {
  _NegotiationFailClient(this.failure);

  final Object failure;
  int closeCalls = 0;

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    throw failure;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

class _DummySink implements StreamSink<Uint8List> {
  @override
  Future<void> get done => Future<void>.value();

  @override
  void add(Uint8List data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {}

  @override
  Future<void> close() async {}
}

/// 连接成功所需的最小会话桩（connect 成功后订阅 stdout/stderr/done）。
class _OkSession extends Fake implements SSHSession {
  // ignore: close_sinks
  final _stdout = StreamController<Uint8List>.broadcast();
  // ignore: close_sinks
  final _stderr = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  Future<void> get done => Completer<void>().future;

  @override
  StreamSink<Uint8List> get stdin => _DummySink();
}

/// shell() 成功的客户端桩，close 可计数。
class _OkClient extends Fake implements SSHClient {
  _OkClient(this.session);

  final SSHSession session;
  int closeCalls = 0;

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    return session;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

class _MockAppConfigService extends Mock implements AppConfigService {}

class _MockSshConfig extends Mock implements SshConfig {}

/// 真实 v4 协商失败经 shell() 冒泡时的错误形态。
Object _negotiationFailure() => SSHAuthAbortError(
  'Connection closed before authentication',
  SSHSocketError(StateError('No matching key exchange algorithm')),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _MockAppConfigService makeConfig() {
    final config = _MockAppConfigService();
    final ssh = _MockSshConfig();
    when(() => ssh.keepaliveInterval).thenReturn(30000);
    when(() => config.ssh).thenReturn(ssh);
    return config;
  }

  SshConnection makeConnection() => SshConnection(
    id: 'legacy-test',
    name: 'legacy-test',
    host: '192.0.2.1',
    username: 'admin',
    authType: AuthType.password,
    password: 'secret',
  );

  group('connect() legacy algorithm fallback (dartssh2 v4)', () {
    test('Given server only speaks legacy algorithms, '
        'When connect fails negotiation then legacy retry succeeds, '
        'Then reconnects once to the same target and connects', () async {
      // Arrange
      final failClient = _NegotiationFailClient(_negotiationFailure());
      final okClient = _OkClient(_OkSession());
      final sockets = <_FakeSocket>[];
      final openedHosts = <String>[];
      var factoryCalls = 0;
      final service = SshService(
        appConfigService: makeConfig(),
        clientFactory:
            (
              socket, {
              required username,
              onPasswordRequest,
              identities,
              keepAliveInterval,
            }) {
              factoryCalls++;
              return factoryCalls == 1 ? failClient : okClient;
            },
        socketConnector: (host, port, {timeout}) async {
          openedHosts.add('$host:$port');
          final socket = _FakeSocket();
          sockets.add(socket);
          return socket;
        },
      );
      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // Act
      await service.connect(makeConnection());

      // Assert
      expect(service.state, SshConnectionState.connected);
      expect(factoryCalls, 2);
      expect(sockets, hasLength(2));
      // 重试打向同一目标，而非丢配置回退到别处。
      expect(openedHosts, ['192.0.2.1:22', '192.0.2.1:22']);
      // 已死的首连 socket 与客户端被回收（各关闭恰好一次）。
      expect(sockets[0].closeCalls, 1);
      expect(failClient.closeCalls, 1);
      expect(okClient.closeCalls, 0);
      expect(outputs.join(), contains('兼容模式'));

      service.dispose();
    });

    test('Given shell fails for non-negotiation reason, '
        'When connect called, '
        'Then does NOT retry and throws 建立会话失败', () async {
      // Arrange
      var factoryCalls = 0;
      var connectorCalls = 0;
      final service = SshService(
        appConfigService: makeConfig(),
        clientFactory:
            (
              socket, {
              required username,
              onPasswordRequest,
              identities,
              keepAliveInterval,
            }) {
              factoryCalls++;
              return _NegotiationFailClient(Exception('wrong password'));
            },
        socketConnector: (host, port, {timeout}) async {
          connectorCalls++;
          return _FakeSocket();
        },
      );

      // Act & Assert — 普通认证失败不得触发重连（避免重复弹密码/打扰）。
      await expectLater(
        () => service.connect(makeConnection()),
        throwsA(predicate<Exception>((e) => e.toString().contains('建立会话失败'))),
      );
      expect(factoryCalls, 1);
      expect(connectorCalls, 1);

      service.dispose();
    });

    test('Given legacy retry also fails negotiation, '
        'When connect called, '
        'Then throws 兼容模式重连失败 with remediation hint', () async {
      // Arrange
      final service = SshService(
        appConfigService: makeConfig(),
        clientFactory:
            (
              socket, {
              required username,
              onPasswordRequest,
              identities,
              keepAliveInterval,
            }) => _NegotiationFailClient(_negotiationFailure()),
        socketConnector: (host, port, {timeout}) async => _FakeSocket(),
      );

      // Act & Assert
      await expectLater(
        () => service.connect(makeConnection()),
        throwsA(
          predicate<Exception>(
            (e) =>
                e.toString().contains('兼容模式重连失败') &&
                e.toString().contains('3DES'),
          ),
        ),
      );

      service.dispose();
    });
  });
}
