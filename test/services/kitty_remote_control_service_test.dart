import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_remote_control_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyRemoteControlService', () {
    late _MockTerminalSession mockSession;
    late KittyRemoteControlService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyRemoteControlService(session: mockSession);
    });

    group('TerminalInfo', () {
      test('creates with default values', () {
        final info = const TerminalInfo();
        expect(info.title, isNull);
        expect(info.columns, isNull);
        expect(info.rows, isNull);
        expect(info.cursorX, isNull);
        expect(info.cursorY, isNull);
        expect(info.foregroundProcess, isNull);
      });

      test('creates with all fields', () {
        final info = const TerminalInfo(
          title: 'test',
          columns: 80,
          rows: 24,
          cursorX: 5,
          cursorY: 10,
          foregroundProcess: 'bash',
        );
        expect(info.title, 'test');
        expect(info.columns, 80);
        expect(info.rows, 24);
        expect(info.cursorX, 5);
        expect(info.cursorY, 10);
        expect(info.foregroundProcess, 'bash');
      });
    });

    group('BufferContent', () {
      test('creates with required fields', () {
        final content = const BufferContent(
          startLine: 0,
          lines: 10,
          content: 'abc',
        );
        expect(content.startLine, 0);
        expect(content.lines, 10);
        expect(content.content, 'abc');
      });
    });

    group('ModifierKey enum', () {
      test('has all expected values', () {
        expect(ModifierKey.values.length, 5);
        expect(ModifierKey.none, ModifierKey.none);
        expect(ModifierKey.ctrl, ModifierKey.ctrl);
        expect(ModifierKey.alt, ModifierKey.alt);
        expect(ModifierKey.shift, ModifierKey.shift);
        expect(ModifierKey.super_, ModifierKey.super_);
      });
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyRemoteControlService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('getTitle', () {
      test('sends OSC 21 t', () async {
        final result = await service.getTitle();
        verify(() => mockSession.writeRaw('\x1b]21;t\x1b\\\\')).called(1);
        expect(result, isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.getTitle(), throwsA(isA<Exception>()));
      });
    });

    group('getSize', () {
      test('sends DA and CPR requests', () async {
        await service.getSize();
        verify(() => mockSession.writeRaw('\x1b[c')).called(1);
        verify(() => mockSession.writeRaw('\x1b[6n')).called(1);
      });

      test('returns empty TerminalInfo', () async {
        final result = await service.getSize();
        expect(result.title, isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.getSize(), throwsA(isA<Exception>()));
      });
    });

    group('getCursorPosition', () {
      test('sends CSI 6n', () async {
        await service.getCursorPosition();
        verify(() => mockSession.writeRaw('\x1b[6n')).called(1);
      });
    });

    group('getForegroundProcess', () {
      test('sends OSC 9 c', () async {
        final result = await service.getForegroundProcess();
        verify(() => mockSession.writeRaw('\x1b]9;c\x1b\\\\')).called(1);
        expect(result, isNull);
      });
    });

    group('getClipboard', () {
      test('sends OSC 52 c ?', () async {
        final result = await service.getClipboard();
        verify(() => mockSession.writeRaw('\x1b]52;c;?\x1b\\\\')).called(1);
        expect(result, isNull);
      });
    });

    group('setClipboard', () {
      test('sends OSC 52 with base64 encoded text', () async {
        await service.setClipboard('hello');
        verify(
          () => mockSession.writeRaw('\x1b]52;c;aGVsbG8=\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(
          () => nullService.setClipboard('text'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendText', () {
      test('sends raw text to session', () async {
        await service.sendText('echo hello');
        verify(() => mockSession.writeRaw('echo hello')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.sendText('text'), throwsA(isA<Exception>()));
      });
    });

    group('sendKey', () {
      test('sends special key sequences', () async {
        await service.sendKey('enter');
        verify(() => mockSession.writeRaw('\r')).called(1);
      });

      test('sends escape key', () async {
        await service.sendKey('escape');
        verify(() => mockSession.writeRaw('\x1b')).called(1);
      });

      test('sends tab', () async {
        await service.sendKey('tab');
        verify(() => mockSession.writeRaw('\t')).called(1);
      });

      test('sends backspace', () async {
        await service.sendKey('backspace');
        verify(() => mockSession.writeRaw('\x7f')).called(1);
      });

      test('sends arrow keys', () async {
        await service.sendKey('up');
        verify(() => mockSession.writeRaw('\x1b[A')).called(1);
        await service.sendKey('down');
        verify(() => mockSession.writeRaw('\x1b[B')).called(1);
        await service.sendKey('right');
        verify(() => mockSession.writeRaw('\x1b[C')).called(1);
        await service.sendKey('left');
        verify(() => mockSession.writeRaw('\x1b[D')).called(1);
      });

      test('passes through unknown keys as-is', () async {
        await service.sendKey('x');
        verify(() => mockSession.writeRaw('x')).called(1);
      });

      test('is case-insensitive for special keys', () async {
        await service.sendKey('ENTER');
        verify(() => mockSession.writeRaw('\r')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.sendKey('enter'), throwsA(isA<Exception>()));
      });
    });

    group('sendInterrupt', () {
      test('sends Ctrl+C', () async {
        await service.sendInterrupt();
        verify(() => mockSession.writeRaw('\x1b^c')).called(1);
      });
    });

    group('sendEOF', () {
      test('sends Ctrl+D', () async {
        await service.sendEOF();
        verify(() => mockSession.writeRaw('\x1b^d')).called(1);
      });
    });

    group('sendSuspend', () {
      test('sends Ctrl+Z', () async {
        await service.sendSuspend();
        verify(() => mockSession.writeRaw('\x1b^z')).called(1);
      });
    });

    group('sendKeyWithModifier', () {
      test('sends key with no modifier', () async {
        await service.sendKeyWithModifier('a');
        verify(() => mockSession.writeRaw('a')).called(1);
      });

      test('sends Ctrl+key with prefix', () async {
        await service.sendKeyWithModifier('c', modifier: ModifierKey.ctrl);
        verify(() => mockSession.writeRaw('\x1b^c')).called(1);
      });

      test('sends Alt+key with ESC prefix', () async {
        await service.sendKeyWithModifier('x', modifier: ModifierKey.alt);
        verify(() => mockSession.writeRaw('\x1bx')).called(1);
      });

      test('sends Shift+key with ESC prefix', () async {
        await service.sendKeyWithModifier('X', modifier: ModifierKey.shift);
        verify(() => mockSession.writeRaw('\x1bX')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(
          () => nullService.sendKeyWithModifier('a'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('readScreen', () {
      test('sends OSC 5114 R without line count', () async {
        await service.readScreen();
        verify(() => mockSession.writeRaw('\x1b]5114;R\x1b\\\\')).called(1);
      });

      test('includes n= param when lines is specified', () async {
        await service.readScreen(lines: 20);
        verify(
          () => mockSession.writeRaw('\x1b]5114;R;n=20\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.readScreen(), throwsA(isA<Exception>()));
      });
    });

    group('readBuffer', () {
      test('sends OSC 5114 B with line range', () async {
        await service.readBuffer(startLine: 5, lines: 50);
        verify(
          () => mockSession.writeRaw('\x1b]5114;B;s=5;n=50\x1b\\\\'),
        ).called(1);
      });
    });

    group('clearScreen', () {
      test('sends ESC [2J', () async {
        await service.clearScreen();
        verify(() => mockSession.writeRaw('\x1b[2J')).called(1);
      });
    });

    group('clearLine', () {
      test('sends ESC [2K', () async {
        await service.clearLine();
        verify(() => mockSession.writeRaw('\x1b[2K')).called(1);
      });
    });

    group('sendBell', () {
      test('sends BEL character', () async {
        await service.sendBell();
        verify(() => mockSession.writeRaw('\x07')).called(1);
      });
    });

    group('throws when session is null', () {
      test('getCursorPosition', () async {
        final nullService = KittyRemoteControlService();
        expect(
          () => nullService.getCursorPosition(),
          throwsA(isA<Exception>()),
        );
      });

      test('readBuffer', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.readBuffer(), throwsA(isA<Exception>()));
      });

      test('clearScreen', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.clearScreen(), throwsA(isA<Exception>()));
      });

      test('sendBell', () async {
        final nullService = KittyRemoteControlService();
        expect(() => nullService.sendBell(), throwsA(isA<Exception>()));
      });
    });

    group('handleResponse', () {
      test('parses window title from OSC 21 response', () {
        String? capturedTitle;
        service.onTerminalInfo = (info) => capturedTitle = info.title;
        service.handleResponse('21;My Terminal');
        expect(capturedTitle, 'My Terminal');
      });

      test('parses window title from OSC 21 cursor response', () {
        String? capturedTitle;
        service.onTerminalInfo = (info) => capturedTitle = info.title;
        service.handleResponse('21;cursor:10:20');
        expect(capturedTitle, 'cursor:10:20');
      });

      test('parses screen content response', () {
        BufferContent? captured;
        service.onBufferContent = (content) => captured = content;
        service.handleResponse('5114;R;line1;line2');
        expect(captured?.content, 'line1;line2');
      });

      test('calls onResponse for other responses', () {
        String? captured;
        service.onResponse = (r) => captured = r;
        service.handleResponse('some other response');
        expect(captured, 'some other response');
      });

      test('ignores malformed responses without error', () {
        expect(() => service.handleResponse(';;;'), returnsNormally);
      });
    });
  });
}
