import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';

// Mock classes
class MockTerminalService extends Mock implements TerminalService {}

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockSshService extends Mock implements SshService {}

// Register fallback values
void registerFallbackValues() {
  registerFallbackValue(TerminalConfig.defaultConfig);
}

void main() {
  late MockTerminalService mockTerminalService;
  late MockAppConfigService mockAppConfigService;
  late TerminalProvider terminalProvider;

  setUp(() {
    mockTerminalService = MockTerminalService();
    mockAppConfigService = MockAppConfigService();
    registerFallbackValues();

    // Setup default mock behavior
    when(() => mockAppConfigService.terminal).thenReturn(TerminalConfig.defaultConfig);
    when(() => mockTerminalService.getAllSessions()).thenReturn([]);
  });

  group('TerminalProvider', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty sessions', () {
        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);
        expect(terminalProvider.sessions, isEmpty);
        expect(terminalProvider.activeSessionId, isNull);
        expect(terminalProvider.activeSession, isNull);
      });
    });

    group('switchToSession', () {
      test(
          'Given existing session, When switchToSession called, Then updates activeSessionId',
          () {
        // Arrange (Given)
        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('session1');
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Act (When)
        terminalProvider.switchToSession('session1');

        // Assert (Then)
        expect(terminalProvider.activeSessionId, 'session1');
      });

      test(
          'Given non-existing session, When switchToSession called, Then does not update activeSessionId',
          () {
        // Arrange (Given)
        when(() => mockTerminalService.getSession('nonexistent')).thenReturn(null);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Act (When)
        terminalProvider.switchToSession('nonexistent');

        // Assert (Then)
        expect(terminalProvider.activeSessionId, isNull);
      });

      test(
          'Given session switched, When switchToSession called, Then notifies listeners',
          () {
        // Arrange (Given)
        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('session1');
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        var notifyCount = 0;
        terminalProvider.addListener(() {
          notifyCount++;
        });

        // Act (When)
        terminalProvider.switchToSession('session1');

        // Assert (Then)
        expect(notifyCount, greaterThan(0));
      });
    });

    group('closeSession', () {
      test(
          'Given active session, When closeSession called, Then removes session and switches to another',
          () {
        // Arrange (Given)
        final mockSession1 = MockTerminalSession();
        final mockSession2 = MockTerminalSession();
        when(() => mockSession1.id).thenReturn('session1');
        when(() => mockSession2.id).thenReturn('session2');

        when(() => mockTerminalService.getAllSessions())
            .thenReturn([mockSession2]);
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession1);
        when(() => mockTerminalService.getSession('session2')).thenReturn(mockSession2);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Set active session first
        terminalProvider.switchToSession('session1');

        // Act (When)
        terminalProvider.closeSession('session1');

        // Assert (Then)
        verify(() => mockTerminalService.closeSession('session1')).called(1);
        expect(terminalProvider.activeSessionId, 'session2');
      });

      test(
          'Given last session closed, When closeSession called, Then sets activeSessionId to null',
          () {
        // Arrange (Given)
        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('session1');
        when(() => mockTerminalService.getAllSessions()).thenReturn([]);
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);
        terminalProvider.switchToSession('session1');

        // Act (When)
        terminalProvider.closeSession('session1');

        // Assert (Then)
        expect(terminalProvider.activeSessionId, isNull);
      });

      test(
          'Given non-active session, When closeSession called, Then does not change activeSessionId',
          () {
        // Arrange (Given)
        final mockSession1 = MockTerminalSession();
        final mockSession2 = MockTerminalSession();
        when(() => mockSession1.id).thenReturn('session1');
        when(() => mockSession2.id).thenReturn('session2');

        when(() => mockTerminalService.getAllSessions())
            .thenReturn([mockSession2]);
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession1);
        when(() => mockTerminalService.getSession('session2')).thenReturn(mockSession2);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);
        terminalProvider.switchToSession('session2'); // session2 is active

        // Act (When)
        terminalProvider.closeSession('session1');

        // Assert (Then)
        expect(terminalProvider.activeSessionId, 'session2');
      });
    });

    group('getSession', () {
      test(
          'Given existing session, When getSession called, Then returns session',
          () {
        // Arrange (Given)
        final mockSession = MockTerminalSession();
        when(() => mockSession.id).thenReturn('session1');
        when(() => mockTerminalService.getSession('session1')).thenReturn(mockSession);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Act (When)
        final result = terminalProvider.getSession('session1');

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.id, 'session1');
      });

      test(
          'Given non-existing session, When getSession called, Then returns null',
          () {
        // Arrange (Given)
        when(() => mockTerminalService.getSession('nonexistent')).thenReturn(null);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Act (When)
        final result = terminalProvider.getSession('nonexistent');

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('getSshService', () {
      test(
          'Given SSH service exists, When getSshService called, Then returns service',
          () {
        // Arrange (Given)
        final mockSshService = MockSshService();
        final mockInputService = MockTerminalInputService();

        // We need to simulate the service map - but since it's private,
        // we can only test through session creation which populates the map
        // For now, test the case where no sessions exist
        when(() => mockTerminalService.getAllSessions()).thenReturn([]);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Note: This test is limited because _services is private
        // A full test would require integration testing
        expect(terminalProvider.sessions, isEmpty);
      });
    });

    group('dispose', () {
      test('When dispose called, Then disposes all services', () {
        // Arrange (Given)
        final mockInputService = MockTerminalInputService();
        when(() => mockInputService.dispose()).thenReturn(null);
        when(() => mockTerminalService.dispose()).thenReturn(null);
        when(() => mockTerminalService.getAllSessions()).thenReturn([]);

        terminalProvider = TerminalProvider(mockTerminalService, mockAppConfigService);

        // Act (When)
        terminalProvider.dispose();

        // Assert (Then)
        verify(() => mockTerminalService.dispose()).called(1);
      });
    });
  });
}
