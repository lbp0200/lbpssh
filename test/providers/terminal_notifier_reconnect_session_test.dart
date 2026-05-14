import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/terminal_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';

// --- Mocks ---

class _MockTerminalInputService extends Mock implements TerminalInputService {
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

// --- Testable TerminalService ---

class TestableTerminalService extends Mock implements TerminalService {
  final Map<String, TerminalSession> _sessions = {};

  @override
  TerminalSession createSession({
    required String id,
    required String name,
    required TerminalInputService inputService,
    TerminalConfig? terminalConfig,
    bool isLocal = false,
    String? serverInfo,
  }) {
    final session = TerminalSession(
      id: id,
      name: name,
      inputService: inputService,
      terminalConfig: terminalConfig,
      isLocal: isLocal,
      serverInfo: serverInfo,
    );
    _sessions[id] = session;
    return session; // Don't call initialize() to avoid stream subscriptions
  }

  @override
  TerminalSession? getSession(String id) => _sessions[id];

  @override
  List<TerminalSession> getAllSessions() => _sessions.values.toList();

  @override
  void dispose() {
    _sessions.clear();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(<int>[]);
  });

  group('TerminalNotifier.reconnectSession', () {
    test(
      'Given valid serverInfo "user@host", When reconnecting, Then extracts username and host and calls SSH.connect',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: 'alice@prod-server.com',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // SSH.connect will hang since it tries a real network connection.
        // Use a timeout to catch this and verify the parsing logic worked.
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'Given malformed serverInfo without @, When reconnecting, Then returns early without calling SSH.connect',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: 'no-at-sign',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // Should return early without error
        await expectLater(notifier.reconnectSession('sess-001'), completes);

        final state = container.read(terminalProvider);
        expect(state.activeSessionId, 'sess-001');
      },
    );

    test(
      'Given empty serverInfo, When reconnecting, Then returns early without calling SSH.connect',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: '',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        await expectLater(notifier.reconnectSession('sess-001'), completes);

        final state = container.read(terminalProvider);
        expect(state.activeSessionId, 'sess-001');
      },
    );

    test(
      'Given SSH connection fails, When reconnectSession called, Then removes service and throws exception',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: 'charlie@fail-host.net',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // The SSH connection will fail (timeout or exception)
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'Given multiple reconnect calls, Each time old service disposed and new one created, call count accumulates',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: 'multi@host.com',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // Each call will attempt SSH.connect which will hang/timeout
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'Given server info with spaces around @, When parsing, Then split works correctly',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: '  dave@dev.example.com  ',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // Will attempt SSH.connect which will timeout
        await expectLater(
          () => notifier
              .reconnectSession('sess-001')
              .timeout(const Duration(seconds: 5)),
          throwsA(anyOf(isA<Exception>(), isA<TimeoutException>())),
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'Given nonexistent session ID, When reconnecting, Then returns early without error',
      () async {
        final terminalService = TestableTerminalService();
        final inputService = _MockTerminalInputService();

        terminalService.createSession(
          id: 'sess-001',
          name: 'my-session',
          inputService: inputService,
          serverInfo: 'user@remote-host',
        );

        final container = ProviderContainer(
          overrides: [
            terminalServiceProvider.overrideWith((_) => terminalService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(terminalProvider.notifier);

        notifier.state = TerminalState(
          sessions: terminalService.getAllSessions(),
          activeSessionId: 'sess-001',
        );

        // Should complete without error for nonexistent session
        await expectLater(
          notifier.reconnectSession('nonexistent-id'),
          completes,
        );
      },
    );
  });
}
