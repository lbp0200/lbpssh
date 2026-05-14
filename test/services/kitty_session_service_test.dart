import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_session_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

class _MockTerminalInputService extends Mock implements TerminalInputService {}

void main() {
  group('KittySessionService', () {
    late _MockTerminalSession mockSession;
    late _MockTerminalInputService mockInputService;
    late KittySessionService service;
    late StreamController<String> outputController;

    setUp(() {
      mockSession = _MockTerminalSession();
      mockInputService = _MockTerminalInputService();
      outputController = StreamController<String>.broadcast();

      when(() => mockSession.inputService).thenReturn(mockInputService);
      when(
        () => mockInputService.outputStream,
      ).thenAnswer((_) => outputController.stream);

      service = KittySessionService(session: mockSession);
    });

    tearDown(() {
      outputController.close();
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittySessionService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('SessionState', () {
      test('uses default isRunning', () {
        const state = SessionState();
        expect(state.isRunning, isTrue);
      });

      test('stores all fields', () {
        const state = SessionState(
          workingDirectory: '/home/user',
          title: 'Terminal',
          foregroundProcess: 'bash',
          exitCode: 0,
          isRunning: false,
        );
        expect(state.workingDirectory, '/home/user');
        expect(state.title, 'Terminal');
        expect(state.foregroundProcess, 'bash');
        expect(state.exitCode, 0);
        expect(state.isRunning, isFalse);
      });
    });

    group('getTitle', () {
      test('sends OSC 21 command', () async {
        await service.getTitle();
        verify(() => mockSession.writeRaw('\x1b]21;t\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(() => nullService.getTitle(), throwsA(isA<Exception>()));
      });
    });

    group('setTitle', () {
      test('sends OSC 0 command', () async {
        await service.setTitle('My Terminal');
        verify(
          () => mockSession.writeRaw('\x1b]0;My Terminal\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(() => nullService.setTitle('Test'), throwsA(isA<Exception>()));
      });
    });

    group('getForegroundProcess', () {
      test('sends OSC 9 command', () async {
        await service.getForegroundProcess();
        verify(() => mockSession.writeRaw('\x1b]9;c\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(
          () => nullService.getForegroundProcess(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getWorkingDirectory', () {
      test('sends echo command', () async {
        // Trigger the method but let it timeout
        unawaited(service.getWorkingDirectory());
        await Future<void>.delayed(Duration.zero);
        verify(() => mockSession.writeRaw('echo \$PWD\r')).called(1);
      });

      test('returns parsed path from output stream', () async {
        final result = service.getWorkingDirectory();
        outputController.add('/home/user\r\n');
        expect(await result, '/home/user');
      });

      test('returns null on timeout', () async {
        final result = await service.getWorkingDirectory();
        expect(result, isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(
          () => nullService.getWorkingDirectory(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getTerminalSize', () {
      test('sends CSI 6n query', () async {
        unawaited(service.getTerminalSize());
        await Future<void>.delayed(Duration.zero);
        verify(() => mockSession.writeRaw('\x1b[6n')).called(1);
      });

      test('returns parsed size from response', () async {
        final result = service.getTerminalSize();
        outputController.add('\x1b[24;80R');
        final size = await result;
        expect(size, isNotNull);
        expect(size!.columns, 80);
        expect(size.rows, 24);
      });

      test('returns null on timeout', () async {
        final result = await service.getTerminalSize();
        expect(result, isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(() => nullService.getTerminalSize(), throwsA(isA<Exception>()));
      });
    });

    group('sendText', () {
      test('sends raw text', () async {
        await service.sendText('hello');
        verify(() => mockSession.writeRaw('hello')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(() => nullService.sendText('x'), throwsA(isA<Exception>()));
      });
    });

    group('sendCommand', () {
      test('appends carriage return', () async {
        await service.sendCommand('ls -la');
        verify(() => mockSession.writeRaw('ls -la\r')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittySessionService();
        expect(() => nullService.sendCommand('x'), throwsA(isA<Exception>()));
      });
    });

    group('control character methods', () {
      test('sendInterrupt sends Ctrl+C', () async {
        await service.sendInterrupt();
        verify(() => mockSession.writeRaw('\x03')).called(1);
      });

      test('sendSuspend sends Ctrl+Z', () async {
        await service.sendSuspend();
        verify(() => mockSession.writeRaw('\x1a')).called(1);
      });

      test('sendEOF sends Ctrl+D', () async {
        await service.sendEOF();
        verify(() => mockSession.writeRaw('\x04')).called(1);
      });

      for (final methodName in ['sendInterrupt', 'sendSuspend', 'sendEOF']) {
        test('$methodName throws when session is null', () async {
          final nullService = KittySessionService();
          expect(
            () => switch (methodName) {
              'sendInterrupt' => nullService.sendInterrupt(),
              'sendSuspend' => nullService.sendSuspend(),
              'sendEOF' => nullService.sendEOF(),
              _ => Future<void>.value(),
            },
            throwsA(isA<Exception>()),
          );
        });
      }
    });

    group('screen control methods', () {
      test('clearScreen sends clear command', () async {
        await service.clearScreen();
        verify(() => mockSession.writeRaw('\x1b[2J\x1b[H')).called(1);
      });

      test('cursorHome sends home command', () async {
        await service.cursorHome();
        verify(() => mockSession.writeRaw('\x1b[H')).called(1);
      });

      test('bell sends bell command', () async {
        await service.bell();
        verify(() => mockSession.writeRaw('\x07')).called(1);
      });

      test('saveCursor sends both save commands', () async {
        await service.saveCursor();
        verify(() => mockSession.writeRaw('\x1b7')).called(1);
        verify(() => mockSession.writeRaw('\x1b[s')).called(1);
      });

      test('restoreCursor sends both restore commands', () async {
        await service.restoreCursor();
        verify(() => mockSession.writeRaw('\x1b8')).called(1);
        verify(() => mockSession.writeRaw('\x1b[u')).called(1);
      });

      for (final methodName in [
        'clearScreen',
        'cursorHome',
        'bell',
        'saveCursor',
        'restoreCursor',
      ]) {
        test('$methodName throws when session is null', () async {
          final nullService = KittySessionService();
          expect(
            () => switch (methodName) {
              'clearScreen' => nullService.clearScreen(),
              'cursorHome' => nullService.cursorHome(),
              'bell' => nullService.bell(),
              'saveCursor' => nullService.saveCursor(),
              'restoreCursor' => nullService.restoreCursor(),
              _ => Future<void>.value(),
            },
            throwsA(isA<Exception>()),
          );
        });
      }
    });

    group('scroll and line control methods', () {
      test('scrollUp sends CSI S with default', () async {
        await service.scrollUp();
        verify(() => mockSession.writeRaw('\x1b[1S')).called(1);
      });

      test('scrollUp sends CSI S with custom lines', () async {
        await service.scrollUp(lines: 5);
        verify(() => mockSession.writeRaw('\x1b[5S')).called(1);
      });

      test('scrollDown sends CSI T with default', () async {
        await service.scrollDown();
        verify(() => mockSession.writeRaw('\x1b[1T')).called(1);
      });

      test('scrollDown sends CSI T with custom lines', () async {
        await service.scrollDown(lines: 3);
        verify(() => mockSession.writeRaw('\x1b[3T')).called(1);
      });

      test('insertLine sends CSI L with default', () async {
        await service.insertLine();
        verify(() => mockSession.writeRaw('\x1b[1L')).called(1);
      });

      test('insertLine sends CSI L with custom count', () async {
        await service.insertLine(count: 4);
        verify(() => mockSession.writeRaw('\x1b[4L')).called(1);
      });

      test('deleteLine sends CSI M with default', () async {
        await service.deleteLine();
        verify(() => mockSession.writeRaw('\x1b[1M')).called(1);
      });

      test('deleteLine sends CSI M with custom count', () async {
        await service.deleteLine(count: 2);
        verify(() => mockSession.writeRaw('\x1b[2M')).called(1);
      });

      test('deleteChar sends CSI P with default', () async {
        await service.deleteChar();
        verify(() => mockSession.writeRaw('\x1b[1P')).called(1);
      });

      test('deleteChar sends CSI P with custom count', () async {
        await service.deleteChar(count: 7);
        verify(() => mockSession.writeRaw('\x1b[7P')).called(1);
      });

      test('eraseChar sends CSI X with default', () async {
        await service.eraseChar();
        verify(() => mockSession.writeRaw('\x1b[1X')).called(1);
      });

      test('eraseChar sends CSI X with custom count', () async {
        await service.eraseChar(count: 9);
        verify(() => mockSession.writeRaw('\x1b[9X')).called(1);
      });

      for (final entry in [
        'scrollUp',
        'scrollDown',
        'insertLine',
        'deleteLine',
        'deleteChar',
        'eraseChar',
      ]) {
        test('$entry throws when session is null', () async {
          final nullService = KittySessionService();
          expect(
            () => switch (entry) {
              'scrollUp' => nullService.scrollUp(),
              'scrollDown' => nullService.scrollDown(),
              'insertLine' => nullService.insertLine(),
              'deleteLine' => nullService.deleteLine(),
              'deleteChar' => nullService.deleteChar(),
              'eraseChar' => nullService.eraseChar(),
              _ => Future<void>.value(),
            },
            throwsA(isA<Exception>()),
          );
        });
      }
    });

    group('reportState', () {
      test('returns SessionState with working directory', () async {
        final result = service.reportState();
        outputController.add('/usr/local\r\n');
        final state = await result;
        expect(state.workingDirectory, '/usr/local');
        expect(state.isRunning, isTrue);
      });
    });
  });
}
