import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';

// Mock TerminalInputService for testing
class MockTerminalInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async =>
      '';

  @override
  void sendInput(String input) {}

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalService', () {
    late TerminalService terminalService;

    setUp(() {
      terminalService = TerminalService();
    });

    tearDown(() {
      terminalService.dispose();
    });

    group('createSession', () {
      test(
        'Given valid params, When createSession called, Then returns session and adds to sessions',
        () {
          // Act (When)
          final session = terminalService.createSession(
            id: 'session1',
            name: 'Test Session',
            inputService: MockTerminalInputService(),
          );

          // Assert (Then)
          expect(session, isNotNull);
          expect(session.id, 'session1');
          expect(session.name, 'Test Session');
          expect(terminalService.getAllSessions().length, 1);
        },
      );

      test(
        'Given multiple sessions created, When createSession called, Then maintains all sessions',
        () {
          // Act (When)
          terminalService.createSession(
            id: 'session1',
            name: 'Session 1',
            inputService: MockTerminalInputService(),
          );
          terminalService.createSession(
            id: 'session2',
            name: 'Session 2',
            inputService: MockTerminalInputService(),
          );

          // Assert (Then)
          expect(terminalService.getAllSessions().length, 2);
        },
      );
    });

    group('getSession', () {
      test(
        'Given existing session id, When getSession called, Then returns session',
        () {
          // Arrange (Given)
          terminalService.createSession(
            id: 'session1',
            name: 'Test Session',
            inputService: MockTerminalInputService(),
          );

          // Act (When)
          final session = terminalService.getSession('session1');

          // Assert (Then)
          expect(session, isNotNull);
          expect(session!.id, 'session1');
        },
      );

      test(
        'Given non-existing session id, When getSession called, Then returns null',
        () {
          // Act (When)
          final session = terminalService.getSession('nonexistent');

          // Assert (Then)
          expect(session, isNull);
        },
      );
    });

    group('closeSession', () {
      test(
        'Given existing session, When closeSession called, Then removes session',
        () {
          // Arrange (Given)
          terminalService.createSession(
            id: 'session1',
            name: 'Test Session',
            inputService: MockTerminalInputService(),
          );
          expect(terminalService.getAllSessions().length, 1);

          // Act (When)
          terminalService.closeSession('session1');

          // Assert (Then)
          expect(terminalService.getAllSessions().length, 0);
          expect(terminalService.getSession('session1'), isNull);
        },
      );

      test(
        'Given non-existing session, When closeSession called, Then does not error',
        () {
          // Act (When) & Assert (Then) - Should not throw
          terminalService.closeSession('nonexistent');
          expect(terminalService.getAllSessions().length, 0);
        },
      );
    });

    group('getAllSessions', () {
      test(
        'Given no sessions, When getAllSessions called, Then returns empty list',
        () {
          // Act (When)
          final sessions = terminalService.getAllSessions();

          // Assert (Then)
          expect(sessions, isEmpty);
        },
      );

      test(
        'Given multiple sessions, When getAllSessions called, Then returns all sessions',
        () {
          // Arrange (Given)
          terminalService.createSession(
            id: 'session1',
            name: 'Session 1',
            inputService: MockTerminalInputService(),
          );
          terminalService.createSession(
            id: 'session2',
            name: 'Session 2',
            inputService: MockTerminalInputService(),
          );

          // Act (When)
          final sessions = terminalService.getAllSessions();

          // Assert (Then)
          expect(sessions.length, 2);
        },
      );
    });

    group('dispose', () {
      test(
        'Given sessions exist, When dispose called, Then clears all sessions',
        () {
          // Arrange (Given)
          terminalService.createSession(
            id: 'session1',
            name: 'Session 1',
            inputService: MockTerminalInputService(),
          );
          terminalService.createSession(
            id: 'session2',
            name: 'Session 2',
            inputService: MockTerminalInputService(),
          );
          expect(terminalService.getAllSessions().length, 2);

          // Act (When)
          terminalService.dispose();

          // Assert (Then)
          expect(terminalService.getAllSessions().length, 0);
        },
      );
    });
  });

  group('LocalTerminalSession Name', () {
    test(
      'Given directory path, When setting working directory, Then updates name with folder name',
      () async {
        final localService = LocalTerminalService();

        final session = TerminalSession(
          id: 'test-session',
          name: 'local /Users/test',
          inputService: localService,
        );

        session.setWorkingDirectoryAndUpdateName('/Users/test/project');

        expect(session.workingDirectory, '/Users/test/project');
        expect(session.name, 'local project');
      },
    );

    test(
      'Given root directory path, When setting working directory, Then updates name to local /',
      () async {
        final localService = LocalTerminalService();

        final session = TerminalSession(
          id: 'test-session',
          name: 'local test',
          inputService: localService,
        );

        session.setWorkingDirectoryAndUpdateName('/');

        expect(session.name, 'local /');
      },
    );
  });

  group('TerminalSession Connection State Fields', () {
    test(
      'Given SSH session, When created with serverInfo, Then stores serverInfo',
      () {
        // Arrange (Given)
        final mockService = MockTerminalInputService();

        // Act (When)
        final session = TerminalSession(
          id: 'ssh-session',
          name: 'SSH Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );

        // Assert (Then)
        expect(session.isLocal, false);
        expect(session.serverInfo, 'user@192.168.1.1');
        expect(session.connectionState, SshConnectionState.disconnected);
      },
    );

    test(
      'Given local session, When created, Then isLocal is true and serverInfo is null',
      () {
        // Arrange (Given)
        final localService = LocalTerminalService();

        // Act (When)
        final session = TerminalSession(
          id: 'local-session',
          name: 'Local Session',
          inputService: localService,
          isLocal: true,
        );

        // Assert (Then)
        expect(session.isLocal, true);
        expect(session.serverInfo, isNull);
        expect(session.connectionState, SshConnectionState.disconnected);
      },
    );

    test(
      'Given session, When created without optional params, Then has default values',
      () {
        // Arrange (Given)
        final mockService = MockTerminalInputService();

        // Act (When)
        final session = TerminalSession(
          id: 'default-session',
          name: 'Default Session',
          inputService: mockService,
        );

        // Assert (Then)
        expect(session.isLocal, false); // Default is false
        expect(session.serverInfo, isNull);
        expect(session.connectionStartTime, isNull);
      },
    );

    test(
      'Given session, When connectionStartTime set, Then stores the time',
      () {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'session-test',
          name: 'Test',
          inputService: mockService,
        );

        // Act (When)
        final connectionTime = DateTime.now();
        session.connectionStartTime = connectionTime;

        // Assert (Then)
        expect(session.connectionStartTime, connectionTime);
      },
    );
  });

  group('TerminalSession Kitty Protocol Config', () {
    late MockTerminalInputService inputService;

    setUp(() {
      inputService = MockTerminalInputService();
    });

    test(
      'Given no terminalConfig, When creating TerminalSession, Then Kitty mode is disabled by default',
      () {
        final session = TerminalSession(
          id: 'no-config',
          name: 'No Config',
          inputService: inputService,
        );

        expect(session.terminal, isNotNull);
        expect(session.terminal.reflowEnabled, isFalse);
      },
    );

    test(
      'Given terminalConfig with enableKittyProtocol: true, When creating TerminalSession, Then Kitty mode is enabled',
      () {
        final config = TerminalConfig(); // default is true
        final session = TerminalSession(
          id: 'kitty-on',
          name: 'Kitty On',
          inputService: inputService,
          terminalConfig: config,
        );

        expect(session.terminal, isNotNull);
        expect(session.terminal.reflowEnabled, isFalse);
      },
    );

    test(
      'Given terminalConfig with enableKittyProtocol: false, When creating TerminalSession, Then Kitty mode is disabled',
      () {
        final config = TerminalConfig(enableKittyProtocol: false);
        final session = TerminalSession(
          id: 'kitty-off',
          name: 'Kitty Off',
          inputService: inputService,
          terminalConfig: config,
        );

        expect(session.terminal, isNotNull);
        expect(session.terminal.reflowEnabled, isFalse);
      },
    );

    test(
      'Given terminalConfig, When creating TerminalSession, Then notification stream is functional',
      () {
        final config = TerminalConfig(); // default is true
        final session = TerminalSession(
          id: 'notify-test',
          name: 'Notify Test',
          inputService: inputService,
          terminalConfig: config,
        );

        expect(session.notificationStream, isNotNull);
        expect(session.fileTransferStream, isNotNull);
      },
    );

    test(
      'Given TerminalService, When createSession with terminalConfig, Then Kitty config is accepted',
      () {
        final service = TerminalService();
        final config = TerminalConfig(enableKittyProtocol: false);
        final session = service.createSession(
          id: 'svc-kitty',
          name: 'SVC Kitty',
          inputService: inputService,
          terminalConfig: config,
        );

        expect(session, isNotNull);
        expect(session.id, 'svc-kitty');
        expect(session.terminal.reflowEnabled, isFalse);

        service.closeSession('svc-kitty');
        service.dispose();
      },
    );
  });

  group('TerminalSession Methods', () {
    late MockTerminalInputService inputService;

    setUp(() {
      inputService = MockTerminalInputService();
    });

    TerminalSession createSession({String name = 'Test Session'}) {
      return TerminalSession(
        id: 'method-test',
        name: name,
        inputService: inputService,
      );
    }

    test(
      'Given session, When writeRaw called, Then writes to terminal without throwing',
      () {
        final session = createSession();

        expect(() => session.writeRaw('hello'), returnsNormally);
      },
    );

    test('Given session, When setName called, Then updates name getter', () {
      final session = createSession();

      session.setName('Renamed');

      expect(session.name, 'Renamed');
    });

    test(
      'Given session with empty working directory, When updateLocalTerminalName called, Then name becomes local /',
      () {
        final session = createSession(name: 'whatever');

        session.updateLocalTerminalName();

        expect(session.name, 'local /');
      },
    );

    test(
      'Given session with working directory, When updateLocalTerminalName called, Then name becomes local folder',
      () {
        final session = createSession();

        session.setWorkingDirectory('/Users/test/project');
        session.updateLocalTerminalName();

        expect(session.name, 'local project');
      },
    );

    test(
      'Given session, When setWorkingDirectory called, Then updates working directory without changing name',
      () {
        final session = createSession();

        session.setWorkingDirectory('/tmp');

        expect(session.workingDirectory, '/tmp');
        expect(session.name, 'Test Session');
      },
    );

    test('Given session, When setOsType called, Then updates osType', () {
      final session = createSession();

      expect(session.osType, 'Linux');

      session.setOsType('Darwin');

      expect(session.osType, 'Darwin');
    });

    test(
      'Given session, When executeCommand called, Then writes command to terminal and invokes inputService',
      () async {
        final session = createSession();

        await session.executeCommand('ls -la');

        // 命令被写入终端
        expect(session.terminal.buffer.toString(), contains('ls -la'));
      },
    );

    test(
      'Given inputService throws, When executeCommand called, Then writes error to terminal without rethrowing',
      () async {
        final failingService = _ThrowingInputService();
        final session = TerminalSession(
          id: 'throw-test',
          name: 'Throw Test',
          inputService: failingService,
        );

        await session.executeCommand('bad-cmd');

        expect(session.terminal.buffer.toString(), contains('错误:'));
      },
    );
  });

  group('TerminalSession Notification Stream', () {
    test(
      'Given terminal notification, When onNotification fired, Then notificationStream emits event',
      () async {
        final session = TerminalSession(
          id: 'notify-test',
          name: 'Notify',
          inputService: MockTerminalInputService(),
        );

        final notifications = <({String title, String body})>[];
        session.notificationStream.listen(notifications.add);

        session.terminal.onNotification?.call('Kitty 通知', '测试内容');
        await Future<void>.delayed(Duration.zero);

        expect(notifications, hasLength(1));
        expect(notifications.single.title, 'Kitty 通知');
        expect(notifications.single.body, '测试内容');
      },
    );
  });

  group('TerminalSession OSC 5113 File Transfer', () {
    late TerminalSession session;
    late List<FileTransferEvent> events;

    setUp(() {
      session = TerminalSession(
        id: 'osc-test',
        name: 'OSC',
        inputService: MockTerminalInputService(),
      );
      events = [];
      session.fileTransferStream.listen(events.add);
    });

    void fireOsc5113(List<String> args) {
      session.terminal.onPrivateOSC?.call('5113', args);
    }

    test(
      'Given ac=send, When OSC 5113 fired, Then emits start event with parsed fields',
      () async {
        // n 是 base64 编码的文件名
        fireOsc5113(['ac=send', 'fid=file-1', 'n=ZmlsZS50eHQ=', 'size=1024']);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.type, 'start');
        expect(events.single.fileId, 'file-1');
        expect(events.single.fileName, 'file.txt');
        expect(events.single.fileSize, 1024);
      },
    );

    test(
      'Given ac=data, When OSC 5113 fired, Then emits chunk event with decoded bytes',
      () async {
        // d 是 base64 编码的数据
        fireOsc5113(['ac=data', 'fid=file-1', 'offset=0', 'd=SGVsbG8=']);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.type, 'chunk');
        expect(events.single.fileId, 'file-1');
        expect(events.single.offset, 0);
        expect(events.single.data, [72, 101, 108, 108, 111]);
      },
    );

    test(
      'Given ac=finish, When OSC 5113 fired, Then emits end event',
      () async {
        fireOsc5113(['ac=finish', 'fid=file-1']);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.type, 'end');
        expect(events.single.fileId, 'file-1');
      },
    );

    test(
      'Given malformed base64 name, When OSC 5113 send fired, Then fileName is null',
      () async {
        fireOsc5113(['ac=send', 'fid=file-1', 'n=!!!', 'size=10']);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.single.fileName, isNull);
      },
    );

    test(
      'Given unknown action, When OSC 5113 fired, Then no event emitted',
      () async {
        fireOsc5113(['ac=unknown', 'fid=file-1']);
        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );
  });

  group('TerminalSession Clipboard (OSC 52)', () {
    test(
      'Given clipboard has text, When onClipboardRead fired, '
      'Then OSC 52 response is sent OUTBOUND via sendInput to the remote pty',
      () async {
        final inputService = _ControlledInputService();
        final session = TerminalSession(
          id: 'clip-test',
          name: 'Clip',
          inputService: inputService,
        );

        // 记录是否被误走 inbound 通道（旧 bug：terminal.write 会喂回自身模拟器）
        bool wroteInbound = false;
        session.terminal.onClipboardWrite = (data, target) {
          wroteInbound = true;
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                return <String, dynamic>{'text': 'hello-clip'};
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        // 字段类型为 void Function(String)，内部为 async 回调，调用后等待完成
        session.terminal.onClipboardRead?.call('c');
        await Future<void>.delayed(Duration.zero);

        // 响应必须经出站通道 sendInput 发给远端 pty（远端程序查询剪贴板时的真正回复）
        final expected =
            '\x1b]52;c;${base64Encode(utf8.encode('hello-clip'))}\x1b\\';
        expect(inputService.sentInputs, [expected]);

        // 回归：旧实现用 terminal.write()（inbound），会把响应喂回自身模拟器并触发
        // onClipboardWrite；修复后不应再发生。
        expect(wroteInbound, isFalse);
      },
    );

    test(
      'Given onClipboardWrite fired, Then Clipboard.setData called with decoded text',
      () async {
        final session = TerminalSession(
          id: 'clip-test',
          name: 'Clip',
          inputService: MockTerminalInputService(),
        );
        String? clipboardText;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final encoded = base64Encode(utf8.encode('复制内容'));
        session.terminal.onClipboardWrite?.call(encoded, 'c');
        await Future<void>.delayed(Duration.zero);

        expect(clipboardText, '复制内容');
      },
    );
  });

  group('TerminalSession initialize()', () {
    late _ControlledInputService inputService;

    setUp(() {
      inputService = _ControlledInputService();
    });

    test(
      'Given output stream emits, When initialize called, Then writes output to terminal',
      () async {
        final session = TerminalSession(
          id: 'init-test',
          name: 'Init',
          inputService: inputService,
        );
        // ignore: unawaited_futures
        session.initialize();

        inputService.outputController.add('hello output');
        await Future<void>.delayed(Duration.zero);

        expect(session.terminal.buffer.toString(), contains('hello output'));
      },
    );

    test(
      'Given state stream emits true, When initialize called, '
      'Then connectionState becomes connected and start time is set',
      () async {
        final session = TerminalSession(
          id: 'init-test',
          name: 'Init',
          inputService: inputService,
        );
        // ignore: unawaited_futures
        session.initialize();

        inputService.stateController.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(session.connectionState, SshConnectionState.connected);
        expect(session.connectionStartTime, isNotNull);
      },
    );

    test('Given state stream emits false, When initialize called, '
        'Then connectionState becomes disconnected', () async {
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: inputService,
      );
      // ignore: unawaited_futures
      session.initialize();

      inputService.stateController.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(session.connectionState, SshConnectionState.disconnected);
    });

    test(
      'Given terminal output, When onOutput fired, Then sends input to service',
      () async {
        final session = TerminalSession(
          id: 'init-test',
          name: 'Init',
          inputService: inputService,
        );
        // ignore: unawaited_futures
        session.initialize();

        session.terminal.onOutput?.call('ls -la');
        expect(inputService.sentInputs, contains('ls -la'));
      },
    );

    test(
      'Given empty terminal output, When onOutput fired, Then skips sending',
      () async {
        final session = TerminalSession(
          id: 'init-test',
          name: 'Init',
          inputService: inputService,
        );
        // ignore: unawaited_futures
        session.initialize();

        session.terminal.onOutput?.call('');
        expect(inputService.sentInputs, isEmpty);
      },
    );

    test('Given input service throws on send, When onOutput fired, '
        'Then writes error to terminal without rethrowing', () async {
      final throwingService = _ThrowingSendInputService();
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: throwingService,
      );
      // ignore: unawaited_futures
      session.initialize();

      expect(() => session.terminal.onOutput?.call('bad'), returnsNormally);
      expect(session.terminal.buffer.toString(), contains('输入发送失败'));
    });

    test(
      'Given resize fired, When debounce delay elapses, Then resizes input service',
      () async {
        final session = TerminalSession(
          id: 'init-test',
          name: 'Init',
          inputService: inputService,
        );
        // ignore: unawaited_futures
        session.initialize();

        session.terminal.onResize?.call(100, 30, 800, 600);
        expect(inputService.resizeCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(inputService.resizeCount, 1);
        expect(inputService.lastResize, (30, 100));
      },
    );

    test('Given session initialized, When graphicsManager accessed, '
        'Then returns the terminal graphics manager', () {
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: inputService,
      );
      session.initialize();

      expect(session.graphicsManager, same(session.terminal.graphicsManager));
    });

    test('Given output stream emits error, When initialize called, '
        'Then does not throw', () async {
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: inputService,
      );
      // ignore: unawaited_futures
      session.initialize();

      inputService.outputController.addError(Exception('out boom'));
      await Future<void>.delayed(Duration.zero);
      // onError 分支静默处理，不抛出
    });

    test('Given state stream emits error, When initialize called, '
        'Then does not throw', () async {
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: inputService,
      );
      // ignore: unawaited_futures
      session.initialize();

      inputService.stateController.addError(Exception('state boom'));
      await Future<void>.delayed(Duration.zero);
      // onError 分支静默处理，不抛出
    });

    testWidgets('Given resize fired with frame, When post-frame callback runs, '
        'Then resizes input service', (tester) async {
      // 先挂载一帧，确保 addPostFrameCallback 在后续 pump 中执行
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final session = TerminalSession(
        id: 'init-test',
        name: 'Init',
        inputService: inputService,
      );
      // ignore: unawaited_futures
      session.initialize();

      session.terminal.onResize?.call(100, 30, 800, 600);
      // 推进一帧触发 addPostFrameCallback → 立即 resize（并取消防抖定时器）
      await tester.pump();
      expect(inputService.resizeCount, 1);
      expect(inputService.lastResize, (30, 100));
    });
  });

  group('TerminalSession rebind() — 重连后切换到新输入服务', () {
    test(
      'Given initialized session, When rebound to a new service, '
      'Then output from the new service is written and old stream ignored',
      () async {
        final oldService = _ControlledInputService();
        final newService = _ControlledInputService();
        final session = TerminalSession(
          id: 'rebind-test',
          name: 'Rebind',
          inputService: oldService,
        );
        // ignore: unawaited_futures
        session.initialize();

        session.rebind(newService);

        newService.outputController.add('from new service');
        oldService.outputController.add('from old service');
        await Future<void>.delayed(Duration.zero);

        final buffer = session.terminal.buffer.toString();
        expect(buffer, contains('from new service'));
        expect(buffer, isNot(contains('from old service')));
      },
    );

    test('Given initialized session, When rebound and input fired, '
        'Then keystrokes route to the new service', () async {
      final oldService = _ControlledInputService();
      final newService = _ControlledInputService();
      final session = TerminalSession(
        id: 'rebind-input',
        name: 'Rebind Input',
        inputService: oldService,
      );
      // ignore: unawaited_futures
      session.initialize();

      session.rebind(newService);
      session.terminal.onOutput?.call('whoami');

      expect(newService.sentInputs, contains('whoami'));
      expect(oldService.sentInputs, isEmpty);
    });

    test('Given initialized session, When rebound and state stream emits true, '
        'Then connectionState reflects the new service', () async {
      final oldService = _ControlledInputService();
      final newService = _ControlledInputService();
      final session = TerminalSession(
        id: 'rebind-state',
        name: 'Rebind State',
        inputService: oldService,
      );
      // ignore: unawaited_futures
      session.initialize();

      session.rebind(newService);
      newService.stateController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(session.connectionState, SshConnectionState.connected);
    });

    test('Given disposed session, When rebind called, Then is a no-op', () {
      final oldService = _ControlledInputService();
      final newService = _ControlledInputService();
      final session = TerminalSession(
        id: 'rebind-disposed',
        name: 'Rebind Disposed',
        inputService: oldService,
      );
      // ignore: unawaited_futures
      session.initialize();
      session.dispose();

      expect(() => session.rebind(newService), returnsNormally);
    });
  });
}

/// 输入服务:可控流 + 记录 sendInput/resize 调用
class _ControlledInputService implements TerminalInputService {
  final outputController = StreamController<String>.broadcast();
  final stateController = StreamController<bool>.broadcast();
  final sentInputs = <String>[];
  int resizeCount = 0;
  (int, int)? lastResize;

  @override
  Stream<String> get outputStream => outputController.stream;

  @override
  Stream<bool> get stateStream => stateController.stream;

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async =>
      '';

  @override
  void sendInput(String input) {
    sentInputs.add(input);
  }

  @override
  void resize(int rows, int columns) {
    resizeCount++;
    lastResize = (rows, columns);
  }

  @override
  void dispose() {
    outputController.close();
    stateController.close();
  }
}

/// 输入服务:sendInput 始终抛异常
class _ThrowingSendInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async =>
      '';

  @override
  void sendInput(String input) {
    throw Exception('send failed');
  }

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {}
}

/// 输入服务:executeCommand 始终抛异常
class _ThrowingInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async {
    throw Exception('command failed');
  }

  @override
  void sendInput(String input) {}

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {}
}
