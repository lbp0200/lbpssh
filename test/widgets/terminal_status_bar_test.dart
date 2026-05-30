import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_status_bar.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';

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

  group('TerminalStatusBar Widget', () {
    testWidgets(
      'Given SSH session connected, When rendered, Then shows Connected status',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then)
        expect(find.text('Connected'), findsOneWidget);
      },
    );

    testWidgets(
      'Given SSH session disconnected, When rendered, Then shows Disconnected status',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.disconnected;

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then)
        expect(find.text('Disconnected'), findsOneWidget);
      },
    );

    testWidgets('Given local session, When rendered, Then shows Local status', (
      tester,
    ) async {
      // Arrange (Given)
      final localService = MockTerminalInputService();
      final session = TerminalSession(
        id: 'local-session',
        name: 'Local Session',
        inputService: localService,
        isLocal: true,
      );

      // Act (When)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TerminalStatusBar(session: session)),
        ),
      );

      // Assert (Then)
      expect(find.text('Local'), findsOneWidget);
    });

    testWidgets(
      'Given SSH session with serverInfo, When rendered, Then shows server info',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'admin@server.example.com',
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then)
        expect(find.textContaining('admin@server.example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'Given disconnected SSH session with onReconnect, When rendered, Then shows reconnect button',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.disconnected;

        bool reconnectCalled = false;

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalStatusBar(
                session: session,
                onReconnect: () {
                  reconnectCalled = true;
                },
              ),
            ),
          ),
        );

        // Assert (Then)
        expect(find.text('Reconnect'), findsOneWidget);

        // When tap reconnect
        await tester.tap(find.text('Reconnect'));
        expect(reconnectCalled, true);
      },
    );

    testWidgets(
      'Given connected session, When rendered, Then shows connection duration',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connected;
        // Set connection start time to 5 minutes ago
        session.connectionStartTime = DateTime.now().subtract(
          const Duration(minutes: 5),
        );

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then) - Should show time format HH:MM:SS
        expect(find.textContaining(':'), findsWidgets);
      },
    );

    testWidgets(
      'Given session connecting, When rendered, Then shows Connecting status',
      (tester) async {
        // Arrange (Given)
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connecting;

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then)
        expect(find.text('Connecting...'), findsOneWidget);
      },
    );

    testWidgets(
      'Given local session, When rendered, Then does not show server info',
      (tester) async {
        // Arrange (Given)
        final localService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'local-session',
          name: 'Local Session',
          inputService: localService,
          isLocal: true,
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        // Act (When)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalStatusBar(session: session)),
          ),
        );

        // Assert (Then) - Should show Local, not server info
        expect(find.text('Local'), findsOneWidget);
        // Should NOT show @ symbol (server info indicator)
        expect(find.textContaining('@'), findsNothing);
      },
    );
  });
}
