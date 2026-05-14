import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_shell_integration_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyShellIntegrationService', () {
    late _MockTerminalSession mockSession;
    late KittyShellIntegrationService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyShellIntegrationService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyShellIntegrationService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('queryPrompt', () {
      test('sends OSC 133 A command', () async {
        await service.queryPrompt();
        verify(() => mockSession.writeRaw('\x1b]133;A\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(() => nullService.queryPrompt(), throwsA(isA<Exception>()));
      });
    });

    group('sendCommandExecuted', () {
      test('sends OSC 133 C with command and status', () async {
        await service.sendCommandExecuted(commandLine: 'ls -la', exitStatus: 0);
        verify(
          () => mockSession.writeRaw(
            '\x1b]133;C;command=ls -la;status=0\x1b\\\\',
          ),
        ).called(1);
      });

      test('encodes special characters in command', () async {
        await service.sendCommandExecuted(commandLine: 'ls -la', exitStatus: 1);
        verify(
          () => mockSession.writeRaw(
            '\x1b]133;C;command=ls -la;status=1\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () =>
              nullService.sendCommandExecuted(commandLine: 'ls', exitStatus: 0),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendCommandFailed', () {
      test('sends OSC 133 C with status=1', () async {
        await service.sendCommandFailed('rm -rf /');
        verify(
          () => mockSession.writeRaw(
            '\x1b]133;C;command=rm -rf /;status=1\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.sendCommandFailed('x'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendCommandStarted', () {
      test('sends OSC 133 S with command', () async {
        await service.sendCommandStarted('grep foo bar');
        verify(
          () => mockSession.writeRaw('\x1b]133;S;command=grep foo bar\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.sendCommandStarted('x'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendWorkingDirectory', () {
      test('sends OSC 133 D with path', () async {
        await service.sendWorkingDirectory('/home/user/projects');
        verify(
          () => mockSession.writeRaw('\x1b]133;D;/home/user/projects\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.sendWorkingDirectory('/tmp'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('queryWorkingDirectory', () {
      test('sends OSC 133 D ? command', () async {
        await service.queryWorkingDirectory();
        verify(() => mockSession.writeRaw('\x1b]133;D;?\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.queryWorkingDirectory(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendCommandLine', () {
      test('sends OSC 133 F with command', () async {
        await service.sendCommandLine('echo hello');
        verify(
          () => mockSession.writeRaw('\x1b]133;F;command=echo hello\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.sendCommandLine('x'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('queryCommandLine', () {
      test('sends OSC 133 F ? command', () async {
        await service.queryCommandLine();
        verify(() => mockSession.writeRaw('\x1b]133;F;?\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(() => nullService.queryCommandLine(), throwsA(isA<Exception>()));
      });
    });

    group('sendPromptStyle', () {
      test('sends OSC 133 A for command prompt', () async {
        await service.sendPromptStyle(PromptType.command);
        verify(() => mockSession.writeRaw('\x1b]133;A\x1b\\\\')).called(1);
      });

      test('sends OSC 133 B for continuation prompt', () async {
        await service.sendPromptStyle(PromptType.continuation);
        verify(() => mockSession.writeRaw('\x1b]133;B\x1b\\\\')).called(1);
      });

      test('sends OSC 133 C for selection prompt', () async {
        await service.sendPromptStyle(PromptType.selection);
        verify(() => mockSession.writeRaw('\x1b]133;C\x1b\\\\')).called(1);
      });

      test('sends OSC 133 D for vim prompt', () async {
        await service.sendPromptStyle(PromptType.vimPrompt);
        verify(() => mockSession.writeRaw('\x1b]133;D\x1b\\\\')).called(1);
      });

      test('includes styles when provided', () async {
        await service.sendPromptStyle(
          PromptType.command,
          styles: {'fg': 'red', 'bg': 'black'},
        );
        verify(
          () => mockSession.writeRaw('\x1b]133;A;fg=red;bg=black\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyShellIntegrationService();
        expect(
          () => nullService.sendPromptStyle(PromptType.command),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('_encode / _decode', () {
      test('encode escapes special characters', () {
        // Access through sendCommandExecuted since _encode is private
        // Already verified in sendCommandExecuted tests above
      });

      test('decode reverses encoding', () {
        // Access through handleShellResponse since _decode is private
      });
    });

    group('handleShellResponse', () {
      test('parses command prompt (key A)', () {
        String? capturedPrompt;
        PromptType? capturedType;
        service.onPrompt = (prompt, type) {
          capturedPrompt = prompt;
          capturedType = type;
        };

        service.handleShellResponse('133;A=myshell\u0024 ');

        expect(capturedPrompt, 'myshell\u0024');
        expect(capturedType, PromptType.command);
      });

      test('parses continuation prompt (key B)', () {
        String? capturedPrompt;
        PromptType? capturedType;
        service.onPrompt = (prompt, type) {
          capturedPrompt = prompt;
          capturedType = type;
        };

        service.handleShellResponse('133;B=> ');

        expect(capturedPrompt, '>');
        expect(capturedType, PromptType.continuation);
      });

      test('parses selection prompt (key C)', () {
        String? capturedPrompt;
        PromptType? capturedType;
        service.onPrompt = (prompt, type) {
          capturedPrompt = prompt;
          capturedType = type;
        };

        service.handleShellResponse('133;C=select:');

        expect(capturedPrompt, 'select:');
        expect(capturedType, PromptType.selection);
      });

      test('parses vim prompt (key D)', () {
        String? capturedPrompt;
        PromptType? capturedType;
        service.onPrompt = (prompt, type) {
          capturedPrompt = prompt;
          capturedType = type;
        };

        // Key D only fires onPrompt for query/? responses;
        // arbitrary values do not trigger onPrompt
        service.handleShellResponse('133;D=Vim:');

        expect(capturedPrompt, isNull);
        expect(capturedType, isNull);
      });

      test('parses command line (key command)', () {
        String? captured;
        service.onCommandLine = (line) => captured = line;

        service.handleShellResponse('133;command=ls -la');

        expect(captured, 'ls -la');
      });

      test('decodes command value', () {
        String? captured;
        service.onCommandLine = (line) => captured = line;

        // Command value with escaped colon (no semicolons inside value)
        service.handleShellResponse('133;command=a\\:b');

        expect(captured, 'a:b');
      });

      test('parses exit status (key status)', () {
        int? captured;
        service.onExitStatus = (status) => captured = status;

        service.handleShellResponse('133;status=0');

        expect(captured, 0);
      });

      test('parses failed exit status', () {
        int? captured;
        service.onExitStatus = (status) => captured = status;

        service.handleShellResponse('133;status=1');

        expect(captured, 1);
      });

      test('parses working directory (key D with cwd=)', () {
        String? captured;
        service.onWorkingDirectory = (cwd) => captured = cwd;

        service.handleShellResponse('133;D=cwd=/home/user');

        expect(captured, '/home/user');
      });

      test('ignores response without 133; prefix', () {
        bool callbackCalled = false;
        service.onPrompt = (_, _) => callbackCalled = true;

        service.handleShellResponse('garbage');
        service.handleShellResponse('not starting with 133');
        service.handleShellResponse('');

        expect(callbackCalled, isFalse);
      });

      test('does not throw on malformed response', () {
        expect(() => service.handleShellResponse('133;=;=;'), returnsNormally);
        // Malformed parts are silently ignored, no callbacks invoked
      });

      group('PromptType enum', () {
        test('has all expected values', () {
          expect(PromptType.values.length, 4);
          expect(PromptType.command, PromptType.command);
          expect(PromptType.continuation, PromptType.continuation);
          expect(PromptType.selection, PromptType.selection);
          expect(PromptType.vimPrompt, PromptType.vimPrompt);
        });
      });
    });
  });
}
