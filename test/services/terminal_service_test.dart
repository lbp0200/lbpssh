import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';

// Mock TerminalInputService for testing
class MockTerminalInputService implements TerminalInputService {
  @override
  Stream<String> get outputStream => const Stream.empty();

  @override
  Stream<bool> get stateStream => const Stream.empty();

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async => '';

  @override
  void sendInput(String input) {}

  @override
  void dispose() {}
}

void main() {
  group('TerminalService', () {
    late TerminalService terminalService;

    setUp(() {
      terminalService = TerminalService();
    });

    tearDown(() {
      terminalService.dispose();
    });

    group('createSession', () {
      test('Given valid params, When createSession called, Then returns session and adds to sessions', () {
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
      });

      test('Given multiple sessions created, When createSession called, Then maintains all sessions', () {
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
      });
    });

    group('getSession', () {
      test('Given existing session id, When getSession called, Then returns session', () {
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
      });

      test('Given non-existing session id, When getSession called, Then returns null', () {
        // Act (When)
        final session = terminalService.getSession('nonexistent');

        // Assert (Then)
        expect(session, isNull);
      });
    });

    group('closeSession', () {
      test('Given existing session, When closeSession called, Then removes session', () {
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
      });

      test('Given non-existing session, When closeSession called, Then does not error', () {
        // Act (When) & Assert (Then) - Should not throw
        terminalService.closeSession('nonexistent');
        expect(terminalService.getAllSessions().length, 0);
      });
    });

    group('getAllSessions', () {
      test('Given no sessions, When getAllSessions called, Then returns empty list', () {
        // Act (When)
        final sessions = terminalService.getAllSessions();

        // Assert (Then)
        expect(sessions, isEmpty);
      });

      test('Given multiple sessions, When getAllSessions called, Then returns all sessions', () {
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
      });
    });

    group('dispose', () {
      test('Given sessions exist, When dispose called, Then clears all sessions', () {
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
      });
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
    });

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
    });

    test(
        'Given various paths, When extracting folder name, Then extracts correct name',
        () {
      final paths = [
        '/Users/lbp/Projects/lbpSSH',
        '/home/user/documents',
        '/var/log',
        '/',
      ];

      final expectedFolders = [
        'lbpSSH',
        'documents',
        'log',
        '', // Root directory has no folder name
      ];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final parts = path.split('/');
        final folderName = parts.last;
        expect(folderName, expectedFolders[i]);
      }
    });
  });
}
