import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/sftp_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';

class MockTerminalInputService extends Mock implements TerminalInputService {}

class MockTerminalSession extends Mock implements TerminalSession {}

class MockTerminalService extends Mock implements TerminalService {}

void main() {
  late MockTerminalService mockTerminalService;
  late MockTerminalSession mockSession;
  late ProviderContainer container;

  setUp(() {
    mockTerminalService = MockTerminalService();
    mockSession = MockTerminalSession();

    // Setup default mock behavior
    when(() => mockSession.workingDirectory).thenReturn('/home/user');
    when(() => mockSession.id).thenReturn('test-session-id');

    container = ProviderContainer(
      overrides: [
        terminalServiceProvider.overrideWithValue(mockTerminalService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SftpNotifier', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty tabs list', () {
        final state = container.read(sftpProvider);
        expect(state.tabs, isEmpty);
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
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);

          // Act (When)
          final tab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Assert (Then)
          expect(tab, isNotNull);
          expect(tab.connection.id, connection.id);
          verify(() => mockTerminalService.getSession(connection.id)).called(1);
        },
      );

      test(
        'Given session does not exist, When openTab called, Then throws exception',
        () async {
          // Arrange (Given)
          final connection = SshConnection(
            id: 'nonexistent',
            name: 'No Session',
            host: '192.168.1.99',
            port: 22,
            username: 'test',
            authType: AuthType.password,
          );
          when(
            () => mockTerminalService.getSession('nonexistent'),
          ).thenReturn(null);

          // Act & Assert (When)
          expect(
            () => container.read(sftpProvider.notifier).openTab(connection),
            throwsException,
          );
        },
      );
    });

    group('closeTab', () {
      test(
        'Given tab exists, When closeTab called, Then removes tab from state',
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
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);
          final tab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Act (When)
          await container.read(sftpProvider.notifier).closeTab(tab.id);

          // Assert (Then)
          final state = container.read(sftpProvider);
          expect(state.tabs, isEmpty);
        },
      );

      test(
        'Given non-existent tab id, When closeTab called, Then state stays unchanged',
        () async {
          // Act (When)
          await container.read(sftpProvider.notifier).closeTab('nonexistent');

          // Assert (Then)
          final state = container.read(sftpProvider);
          expect(state.tabs, isEmpty);
        },
      );
    });

    group('getTab', () {
      test(
        'Given tab exists, When getTab called, Then returns the tab',
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
          when(
            () => mockTerminalService.getSession(connection.id),
          ).thenReturn(mockSession);
          final createdTab = await container
              .read(sftpProvider.notifier)
              .openTab(connection);

          // Act (When)
          final result = container
              .read(sftpProvider.notifier)
              .getTab(createdTab.id);

          // Assert (Then)
          expect(result, isNotNull);
          expect(result!.id, createdTab.id);
        },
      );

      test(
        'Given non-existent tab id, When getTab called, Then returns null',
        () {
          // Act (When)
          final result = container
              .read(sftpProvider.notifier)
              .getTab('nonexistent');

          // Assert (Then)
          expect(result, isNull);
        },
      );
    });
  });
}
