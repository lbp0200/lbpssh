import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_actions_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyActionsService', () {
    late _MockTerminalSession mockSession;
    late KittyActionsService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyActionsService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyActionsService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('openUrl', () {
      test('writes OSC 5 sequence with URL', () async {
        await service.openUrl('https://example.com');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes id when provided', () async {
        await service.openUrl('https://example.com', id: 'url-1');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(
          () => nullService.openUrl('https://example.com'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('openFile', () {
      test('writes OSC 5 sequence with file path', () async {
        await service.openFile('/path/to/file.txt');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes line number when provided', () async {
        await service.openFile('/path/to/file.txt', line: 42);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes column number when provided', () async {
        await service.openFile('/path/to/file.txt', column: 10);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes both line and column when provided', () async {
        await service.openFile('/path/to/file.txt', line: 42, column: 10);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(
          () => nullService.openFile('/path/to/file.txt'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('runProgram', () {
      test('writes OSC 5 sequence with program', () async {
        await service.runProgram('ls');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes arguments when provided', () async {
        await service.runProgram('ls', arguments: ['-la', '/tmp']);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes cwd when provided', () async {
        await service.runProgram('bash', cwd: '/home/user');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(() => nullService.runProgram('ls'), throwsA(isA<Exception>()));
      });
    });

    group('click', () {
      test('writes OSC 5 sequence with coordinates', () async {
        await service.click(100, 200);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(() => nullService.click(0, 0), throwsA(isA<Exception>()));
      });
    });

    group('scroll', () {
      test('writes OSC 5 sequence with deltaY', () async {
        await service.scroll(deltaY: -3);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence with deltaX', () async {
        await service.scroll(deltaX: 1);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence with both deltas', () async {
        await service.scroll(deltaX: 1, deltaY: -3);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(() => nullService.scroll(deltaY: -1), throwsA(isA<Exception>()));
      });
    });

    group('input', () {
      test('writes OSC 5 sequence with text', () async {
        await service.input('hello');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('escapes backslashes in text', () async {
        await service.input(r'path\to\file');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('escapes semicolons in text', () async {
        await service.input('a;b;c');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('escapes commas in text', () async {
        await service.input('a,b,c');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(() => nullService.input('test'), throwsA(isA<Exception>()));
      });
    });

    group('navigate', () {
      test('writes OSC 5 sequence with direction', () async {
        await service.navigate('up');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('supports all directions', () async {
        for (final direction in [
          'up',
          'down',
          'left',
          'right',
          'home',
          'end',
        ]) {
          await service.navigate(direction);
        }
        verify(() => mockSession.writeRaw(any())).called(6);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(() => nullService.navigate('up'), throwsA(isA<Exception>()));
      });
    });

    group('requestAction', () {
      test('writes OSC 5 sequence for openUrl action', () async {
        await service.requestAction(ActionType.openUrl);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for openFile action', () async {
        await service.requestAction(ActionType.openFile);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for runProgram action', () async {
        await service.requestAction(ActionType.runProgram);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for click action', () async {
        await service.requestAction(ActionType.click);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for scroll action', () async {
        await service.requestAction(ActionType.scroll);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for input action', () async {
        await service.requestAction(ActionType.input);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('writes OSC 5 sequence for navigate action', () async {
        await service.requestAction(ActionType.navigate);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes params when provided', () async {
        await service.requestAction(
          ActionType.openUrl,
          params: {'url': 'https://example.com'},
        );
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyActionsService();
        expect(
          () => nullService.requestAction(ActionType.openUrl),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('handleActionResponse', () {
      test('calls onAction for open-url response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;open-url;u=https://example.com');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.openUrl);
        expect(receivedArgs!.url, 'https://example.com');
      });

      test('calls onAction for open-file response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;open-file;f=/path/to/file;l=42;c=10');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.openFile);
        expect(receivedArgs!.filePath, '/path/to/file');
        expect(receivedArgs!.line, 42);
        expect(receivedArgs!.column, 10);
      });

      test('calls onAction for run-program response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;run-program;p=ls;a=-la,/tmp');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.runProgram);
        expect(receivedArgs!.program, 'ls');
        expect(receivedArgs!.arguments, ['-la', '/tmp']);
      });

      test('calls onAction for click response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;click;x=100;y=200');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.click);
        expect(receivedArgs!.x, 100);
        expect(receivedArgs!.y, 200);
      });

      test('calls onAction for scroll response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;scroll;x=1;y=-3');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.scroll);
        expect(receivedArgs!.deltaX, 1);
        expect(receivedArgs!.deltaY, -3);
      });

      test('calls onAction for input response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;input;t=hello world');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.input);
        expect(receivedArgs!.text, 'hello world');
      });

      test('calls onAction for navigate response', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;navigate;d=up');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.type, ActionType.navigate);
        expect(receivedArgs!.text, 'up');
      });

      test('does nothing for non-5 response', () {
        var called = false;
        service.onAction = (_) => called = true;
        service.handleActionResponse('garbage');
        expect(called, isFalse);
      });

      test('does not throw for empty response', () {
        expect(() => service.handleActionResponse(''), returnsNormally);
      });

      test('does not throw for malformed response', () {
        expect(
          () => service.handleActionResponse('5;unknown;no_equals_sign'),
          returnsNormally,
        );
      });

      test('does not throw for unparseable integers', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;click;x=abc;y=def');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.x, isNull);
        expect(receivedArgs!.y, isNull);
      });

      test('does not throw for empty line/column in open-file', () {
        ActionArgs? receivedArgs;
        service.onAction = (args) => receivedArgs = args;
        service.handleActionResponse('5;open-file;f=/path');
        expect(receivedArgs, isNotNull);
        expect(receivedArgs!.line, isNull);
        expect(receivedArgs!.column, isNull);
      });
    });
  });
}
