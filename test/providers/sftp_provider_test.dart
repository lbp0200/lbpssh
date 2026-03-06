import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/providers/terminal_provider.dart';
import 'package:kterm/kterm.dart';

// Mock classes
class MockTerminalProvider extends Mock implements TerminalProvider {}

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockKittyFileTransferService extends Mock
    implements KittyFileTransferService {}

void main() {
  late MockTerminalProvider mockTerminalProvider;
  late MockTerminalSession mockSession;
  late SftpProvider sftpProvider;

  setUp(() {
    mockTerminalProvider = MockTerminalProvider();
    mockSession = MockTerminalSession();

    // Setup default mock behavior
    when(() => mockSession.workingDirectory).thenReturn('/home/user');
    when(() => mockSession.id).thenReturn('test-session-id');

    sftpProvider = SftpProvider(mockTerminalProvider);
  });

  group('SftpProvider', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty tabs list', () {
        expect(sftpProvider.tabs, isEmpty);
      });
    });

    group('openTab', () {
      test(
          'Given session exists, When openTab called, Then creates new tab and returns it',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        // Act (When)
        final tab = await sftpProvider.openTab(connection);

        // Assert (Then)
        expect(tab, isNotNull);
        expect(tab.connection.id, connection.id);
        expect(tab.currentPath, '/home/user');
        expect(sftpProvider.tabs.length, 1);
        verify(() => mockTerminalProvider.getSession(connection.id)).called(1);
      });

      test(
          'Given session does not exist, When openTab called, Then throws exception',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'nonexistent',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(null);

        // Act & Assert (When)
        expect(
          () => sftpProvider.openTab(connection),
          throwsException,
        );
        expect(sftpProvider.tabs, isEmpty);
      });

      test(
          'Given session with empty working directory, When openTab called, Then uses root path',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockSession.workingDirectory).thenReturn('');
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        // Act (When)
        final tab = await sftpProvider.openTab(connection);

        // Assert (Then)
        expect(tab.currentPath, '/');
      });

      test(
          'Given openTab called multiple times, When called, Then creates multiple tabs',
          () async {
        // Arrange (Given)
        final connection1 = SshConnection(
          id: 'conn1',
          name: 'Server 1',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        final connection2 = SshConnection(
          id: 'conn2',
          name: 'Server 2',
          host: '192.168.1.2',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(any()))
            .thenReturn(mockSession);

        // Act (When)
        await sftpProvider.openTab(connection1);
        await sftpProvider.openTab(connection2);

        // Assert (Then)
        expect(sftpProvider.tabs.length, 2);
      });
    });

    group('closeTab', () {
      test(
          'Given existing tab, When closeTab called, Then removes tab from list',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        final tab = await sftpProvider.openTab(connection);
        expect(sftpProvider.tabs.length, 1);

        // Act (When)
        await sftpProvider.closeTab(tab.id);

        // Assert (Then)
        expect(sftpProvider.tabs, isEmpty);
      });

      test(
          'Given non-existing tab id, When closeTab called, Then does nothing',
          () async {
        // Arrange (Given)
        when(() => mockTerminalProvider.getSession(any()))
            .thenReturn(mockSession);

        // Act (When)
        await sftpProvider.closeTab('nonexistent-tab-id');

        // Assert (Then)
        expect(sftpProvider.tabs, isEmpty);
      });

      test(
          'Given tab closed, When closeTab called again, Then does nothing without error',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        final tab = await sftpProvider.openTab(connection);

        // Act (When)
        await sftpProvider.closeTab(tab.id);
        await sftpProvider.closeTab(tab.id); // Close again

        // Assert (Then)
        expect(sftpProvider.tabs, isEmpty);
      });
    });

    group('getTab', () {
      test('Given existing tab id, When getTab called, Then returns tab', () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        final tab = await sftpProvider.openTab(connection);

        // Act (When)
        final result = sftpProvider.getTab(tab.id);

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.id, tab.id);
      });

      test(
          'Given non-existing tab id, When getTab called, Then returns null',
          () async {
        // Act (When)
        final result = sftpProvider.getTab('nonexistent');

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('notifyListeners', () {
      test('Given tab opened, When openTab called, Then notifies listeners', () async {
        // Arrange (Given)
        var notifyCount = 0;
        sftpProvider.addListener(() {
          notifyCount++;
        });

        final connection = SshConnection(
          id: 'conn1',
          name: 'Test Server',
          host: '192.168.1.1',
          port: 22,
          username: 'testuser',
          authType: AuthType.password,
        );
        when(() => mockTerminalProvider.getSession(connection.id))
            .thenReturn(mockSession);

        // Act (When)
        await sftpProvider.openTab(connection);

        // Assert (Then)
        expect(notifyCount, greaterThan(0));
      });
    });
  });
}
