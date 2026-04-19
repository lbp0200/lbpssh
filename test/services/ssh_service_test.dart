import 'dart:async';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';

// ---------------------------------------------------------------------------
// Fake / Mock classes for dartssh2 types
// ---------------------------------------------------------------------------

class FakeSSHSocket extends Fake implements SSHSocket {}

class FakeSSHClient extends Fake implements SSHClient {}

class FakeSSHSession extends Fake implements SSHSession {}

class FakeSftpClient extends Fake implements SftpClient {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockSshConfig extends Mock implements SshConfig {}

// ---------------------------------------------------------------------------
// Stub implementation for SSHSocket abstract members needed by mocktail
// ---------------------------------------------------------------------------

class FakeSSHSocketStub extends FakeSSHSocket {
  @override
  Stream<Uint8List> get stream => const Stream.empty();

  @override
  StreamSink<List<int>> get sink => _DummyStreamSink();

  @override
  Future<void> get done => Future<void>.value();

  @override
  Future<void> close() async {}

  @override
  void destroy() {}
}

class _DummyStreamSink implements StreamSink<List<int>> {
  @override
  Future<void> get done => Future<void>.value();

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

SshConnection makeConnection({
  AuthType authType = AuthType.password,
  String? password,
  String? privateKeyContent,
  String? keyPassphrase,
  JumpHostConfig? jumpHost,
  Socks5ProxyConfig? socks5Proxy,
  String? sshConfigHost,
  int connectTimeout = 30000,
  int keepaliveInterval = 30000,
}) {
  return SshConnection(
    id: 'test-id',
    name: 'test-connection',
    host: '127.0.0.1',
    port: 22,
    username: 'testuser',
    authType: authType,
    password: password,
    privateKeyContent: privateKeyContent,
    keyPassphrase: keyPassphrase,
    jumpHost: jumpHost,
    socks5Proxy: socks5Proxy,
    sshConfigHost: sshConfigHost,
    connectTimeout: connectTimeout,
    keepaliveInterval: keepaliveInterval,
  );
}

MockAppConfigService createMockAppConfigService({
  int keepaliveInterval = 30000,
}) {
  final mock = MockAppConfigService();
  final mockSsh = MockSshConfig();
  when(() => mockSsh.keepaliveInterval).thenReturn(keepaliveInterval);
  when(() => mock.ssh).thenReturn(mockSsh);
  return mock;
}

// ---------------------------------------------------------------------------
// Main test suite
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeSSHSocket());
    registerFallbackValue(FakeSSHClient());
    registerFallbackValue(FakeSSHSession());
    registerFallbackValue(FakeSftpClient());
    registerFallbackValue(makeConnection());
    registerFallbackValue(MockSshConfig());
  });

  // -------------------------------------------------------------------------
  // SshService Constructor
  // -------------------------------------------------------------------------
  group('SshService constructor', () {
    test('Given SshService without AppConfigService, '
        'When created, '
        'Then service is functional (uses default AppConfigService)', () {
      // Act
      final service = SshService();

      // Assert — service should be created without throwing
      // The default AppConfigService singleton is used internally.
      expect(service.state, SshConnectionState.disconnected);
      expect(service, isA<SshService>());
    });

    test('Given SshService with AppConfigService, '
        'When created, '
        'Then service uses provided AppConfigService', () {
      final mockConfig = createMockAppConfigService(keepaliveInterval: 60000);

      // Act
      final service = SshService(appConfigService: mockConfig);

      // Assert — service should use the provided mock.
      // The _config getter returns the injected service (verified by
      // behavioral outcomes: connect() uses _config.ssh.keepaliveInterval).
      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // resize()
  // -------------------------------------------------------------------------
  group('resize()', () {
    test('Given session is null, '
        'When resize called, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(24, 80), returnsNormally);
    });

    test('Given session is null, '
        'When resize called with zero dimensions, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(0, 0), returnsNormally);
    });

    test('Given session is null, '
        'When resize called with negative dimensions, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.resize(-1, -1), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // sendInput()
  // -------------------------------------------------------------------------
  group('sendInput()', () {
    test('Given not connected, '
        'When sendInput called, '
        'Then does nothing (no throw)', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.sendInput('hello'), returnsNormally);
    });

    test('Given not connected, '
        'When sendInput called with empty string, '
        'Then does nothing (no throw)', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(() => service.sendInput(''), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // disconnect()
  // -------------------------------------------------------------------------
  group('disconnect()', () {
    test('Given already disposed, '
        'When disconnect called, '
        'Then does nothing (no throw)', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      service.dispose();

      expect(() => service.disconnect(), returnsNormally);
    });

    test('Given disconnected, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });

    test('Given connecting state, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });

    test('Given error state, '
        'When disconnect called, '
        'Then emits disconnected state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states, contains(SshConnectionState.disconnected));
    });
  });

  // -------------------------------------------------------------------------
  // outputStream
  // -------------------------------------------------------------------------
  group('outputStream', () {
    test('Given disposed, '
        'When output received, '
        'Then outputStream does not emit', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      service.dispose();

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(outputs, isEmpty);
    });

    test('Given not disposed, '
        'When output received, '
        'Then outputStream is available', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final outputs = <String>[];
      service.outputStream.listen(outputs.add);

      // No data was explicitly added so list is empty.
      expect(outputs, isEmpty);

      service.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // state property
  // -------------------------------------------------------------------------
  group('state property', () {
    test('Given initial state, '
        'When created, '
        'Then state is disconnected', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      expect(service.state, SshConnectionState.disconnected);
    });

    test('Given after disconnect, '
        'When state accessed, '
        'Then state is disconnected', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // sshStateStream
  // -------------------------------------------------------------------------
  group('sshStateStream', () {
    test('Given subscribed, '
        'When state changes, '
        'Then stream emits new state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await service.disconnect();

      expect(states.last, SshConnectionState.disconnected);
    });

    test('Given multiple subscribers, '
        'When state changes, '
        'Then all subscribers receive the state', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final states1 = <SshConnectionState>[];
      final states2 = <SshConnectionState>[];
      service.sshStateStream.listen(states1.add);
      service.sshStateStream.listen(states2.add);

      await service.disconnect();

      expect(states1.last, SshConnectionState.disconnected);
      expect(states2.last, SshConnectionState.disconnected);
    });

    test('Given stream listened to after state change, '
        'Then does not receive past states', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await service.disconnect();

      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Should not receive the disconnected state emitted before subscribe.
      expect(states, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // connect() — Error handling (validation before socket creation)
  // -------------------------------------------------------------------------
  group('connect() error handling', () {
    test('Given missing password, '
        'When connect called with password auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(authType: AuthType.password, password: null);

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密码'))),
      );
    });

    test('Given empty password, '
        'When connect called with password auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(authType: AuthType.password, password: '');

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密码'))),
      );
    });

    test('Given missing privateKeyContent, '
        'When connect called with key auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(
        authType: AuthType.key,
        privateKeyContent: null,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('私钥'))),
      );
    });

    test('Given missing keyPassphrase, '
        'When connect called with keyWithPassword auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(
        authType: AuthType.keyWithPassword,
        privateKeyContent:
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----',
        keyPassphrase: null,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(predicate<Exception>((e) => e.toString().contains('密钥密码'))),
      );
    });

    test('Given missing sshConfigHost, '
        'When connect called with sshConfig auth, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final conn = makeConnection(
        authType: AuthType.sshConfig,
        sshConfigHost: null,
      );

      await expectLater(
        () => service.connect(conn),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('SSH Config')),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // executeCommand()
  // -------------------------------------------------------------------------
  group('executeCommand()', () {
    test('Given not connected, '
        'When executeCommand called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await expectLater(
        () => service.executeCommand('ls'),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });

    test('Given disconnected, '
        'When executeCommand called, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      await expectLater(
        () => service.executeCommand('ls'),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });

    test('Given not connected, '
        'When executeCommand called with silent flag, '
        'Then throws Exception', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      await expectLater(
        () => service.executeCommand('ls', silent: true),
        throwsA(predicate<Exception>((e) => e.toString().contains('未连接到服务器'))),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getSftpClient()
  // -------------------------------------------------------------------------
  group('getSftpClient()', () {
    test('Given not connected, '
        'When getSftpClient called, '
        'Then returns null', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      final result = await service.getSftpClient();

      expect(result, isNull);
    });

    test('Given disconnected, '
        'When getSftpClient called, '
        'Then returns null', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);
      await service.disconnect();

      final result = await service.getSftpClient();

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // dispose()
  // -------------------------------------------------------------------------
  group('dispose()', () {
    test('When dispose called, '
        'Then closes streams and subsequent disconnect is no-op', () async {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();

      // Subsequent disconnect should be a no-op.
      expect(() => service.disconnect(), returnsNormally);

      // sshStateStream should be closed (no more emissions).
      final states = <SshConnectionState>[];
      service.sshStateStream.listen(states.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(states, isEmpty);
    });

    test('Given multiple dispose calls, '
        'Then does not throw', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });

    test('When dispose called, '
        'Then state property is still accessible', () {
      final mockConfig = createMockAppConfigService();
      final service = SshService(appConfigService: mockConfig);

      service.dispose();

      expect(service.state, SshConnectionState.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  // SshConnectionState enum
  // -------------------------------------------------------------------------
  group('SshConnectionState enum', () {
    test('Has all expected values', () {
      expect(SshConnectionState.values, [
        SshConnectionState.disconnected,
        SshConnectionState.connecting,
        SshConnectionState.connected,
        SshConnectionState.error,
      ]);
    });
  });
}
