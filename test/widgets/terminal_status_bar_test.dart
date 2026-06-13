import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/l10n/app_localizations.dart';
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

Widget createApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('zh')],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalStatusBar Widget', () {
    testWidgets(
      'Given SSH session connected, When rendered, Then shows Connected status',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.text('Connected'), findsOneWidget);
      },
    );

    testWidgets(
      'Given SSH session disconnected, When rendered, Then shows Disconnected status',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.disconnected;

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.text('Disconnected'), findsOneWidget);
      },
    );

    testWidgets('Given local session, When rendered, Then shows Local status', (
      tester,
    ) async {
      final localService = MockTerminalInputService();
      final session = TerminalSession(
        id: 'local-session',
        name: 'Local Session',
        inputService: localService,
        isLocal: true,
      );

      await tester.pumpWidget(
        createApp(child: TerminalStatusBar(session: session)),
      );
      await tester.pump();

      expect(find.text('Local'), findsOneWidget);
    });

    testWidgets(
      'Given SSH session with serverInfo, When rendered, Then shows server info',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'admin@server.example.com',
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.textContaining('admin@server.example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'Given disconnected SSH session with onReconnect, When rendered, Then shows reconnect button',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.disconnected;

        bool reconnectCalled = false;

        await tester.pumpWidget(
          createApp(
            child: TerminalStatusBar(
              session: session,
              onReconnect: () {
                reconnectCalled = true;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Reconnect'), findsOneWidget);
        await tester.tap(find.text('Reconnect'));
        expect(reconnectCalled, true);
      },
    );

    testWidgets(
      'Given connected session, When rendered, Then shows connection duration',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now().subtract(
          const Duration(minutes: 5),
        );

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.textContaining(':'), findsWidgets);
      },
    );

    testWidgets(
      'Given session connecting, When rendered, Then shows Connecting status',
      (tester) async {
        final mockService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'test-session',
          name: 'Test Session',
          inputService: mockService,
          serverInfo: 'user@192.168.1.1',
        );
        session.connectionState = SshConnectionState.connecting;

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.text('Connecting...'), findsOneWidget);
      },
    );

    testWidgets(
      'Given local session, When rendered, Then does not show server info',
      (tester) async {
        final localService = MockTerminalInputService();
        final session = TerminalSession(
          id: 'local-session',
          name: 'Local Session',
          inputService: localService,
          isLocal: true,
        );
        session.connectionState = SshConnectionState.connected;
        session.connectionStartTime = DateTime.now();

        await tester.pumpWidget(
          createApp(child: TerminalStatusBar(session: session)),
        );
        await tester.pump();

        expect(find.text('Local'), findsOneWidget);
        expect(find.textContaining('@'), findsNothing);
      },
    );
  });
}
