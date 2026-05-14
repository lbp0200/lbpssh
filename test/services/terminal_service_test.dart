import 'package:flutter_test/flutter_test.dart';
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
          isLocal: false,
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
}
