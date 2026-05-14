import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_keyboard_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyKeyboardService', () {
    late _MockTerminalSession mockSession;
    late KittyKeyboardService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyKeyboardService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyKeyboardService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('ModifierKeys', () {
      test('isEmpty returns true when no modifiers', () {
        const modifiers = ModifierKeys();
        expect(modifiers.isEmpty, isTrue);
      });

      test('isEmpty returns false when any modifier is set', () {
        expect(const ModifierKeys(shift: true).isEmpty, isFalse);
        expect(const ModifierKeys(alt: true).isEmpty, isFalse);
        expect(const ModifierKeys(ctrl: true).isEmpty, isFalse);
        expect(const ModifierKeys(super_: true).isEmpty, isFalse);
      });
    });

    group('sendText', () {
      test('writes raw text to session', () async {
        await service.sendText('hello world');
        verify(() => mockSession.writeRaw('hello world')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyKeyboardService();
        expect(() => nullService.sendText('test'), throwsA(isA<Exception>()));
      });
    });

    group('sendKey', () {
      test('writes key without modifiers', () async {
        await service.sendKey('a');
        verify(() => mockSession.writeRaw('a')).called(1);
      });

      test('prepends ESC for alt modifier', () async {
        await service.sendKey('a', modifiers: const ModifierKeys(alt: true));
        verify(() => mockSession.writeRaw('\x1ba')).called(1);
      });

      test('prepends ESC for shift modifier', () async {
        await service.sendKey('a', modifiers: const ModifierKeys(shift: true));
        verify(() => mockSession.writeRaw('\x1ba')).called(1);
      });

      test('prepends ESC^ for ctrl modifier', () async {
        await service.sendKey('a', modifiers: const ModifierKeys(ctrl: true));
        verify(() => mockSession.writeRaw('\x1b^a')).called(1);
      });

      test('combines multiple modifiers', () async {
        await service.sendKey(
          'a',
          modifiers: const ModifierKeys(alt: true, shift: true, ctrl: true),
        );
        verify(() => mockSession.writeRaw('\x1b^\x1b\x1ba')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyKeyboardService();
        expect(() => nullService.sendKey('a'), throwsA(isA<Exception>()));
      });
    });

    group('sendFunctionKey', () {
      test('sends F1 sequence', () async {
        await service.sendFunctionKey(1);
        verify(() => mockSession.writeRaw('\x1bOQ')).called(1);
      });

      test('sends F2 sequence', () async {
        await service.sendFunctionKey(2);
        verify(() => mockSession.writeRaw('\x1bOR')).called(1);
      });

      test('sends F3 sequence', () async {
        await service.sendFunctionKey(3);
        verify(() => mockSession.writeRaw('\x1bOS')).called(1);
      });

      test('sends F4 sequence', () async {
        await service.sendFunctionKey(4);
        verify(() => mockSession.writeRaw('\x1bOP')).called(1);
      });

      test('sends F5 sequence', () async {
        await service.sendFunctionKey(5);
        verify(() => mockSession.writeRaw('\x1b[15~')).called(1);
      });

      test('sends F9 sequence', () async {
        await service.sendFunctionKey(9);
        verify(() => mockSession.writeRaw('\x1b[20~')).called(1);
      });

      test('sends F12 sequence', () async {
        await service.sendFunctionKey(12);
        verify(() => mockSession.writeRaw('\x1b[24~')).called(1);
      });

      test('throws for function number below 1', () async {
        expect(() => service.sendFunctionKey(0), throwsA(isA<Exception>()));
      });

      test('throws for function number above 12', () async {
        expect(() => service.sendFunctionKey(13), throwsA(isA<Exception>()));
      });
    });

    group('sendCursorKey', () {
      test('sends up cursor sequence', () async {
        await service.sendCursorKey('up');
        verify(() => mockSession.writeRaw('\x1b[A')).called(1);
      });

      test('sends down cursor sequence', () async {
        await service.sendCursorKey('down');
        verify(() => mockSession.writeRaw('\x1b[B')).called(1);
      });

      test('sends right cursor sequence', () async {
        await service.sendCursorKey('right');
        verify(() => mockSession.writeRaw('\x1b[C')).called(1);
      });

      test('sends left cursor sequence', () async {
        await service.sendCursorKey('left');
        verify(() => mockSession.writeRaw('\x1b[D')).called(1);
      });

      test('throws for invalid direction', () async {
        expect(
          () => service.sendCursorKey('invalid'),
          throwsA(isA<Exception>()),
        );
      });

      test('is case insensitive', () async {
        await service.sendCursorKey('UP');
        verify(() => mockSession.writeRaw('\x1b[A')).called(1);
      });
    });

    group('sendHomeEnd', () {
      test('sends Home sequence', () async {
        await service.sendHomeEnd('home');
        verify(() => mockSession.writeRaw('\x1b[1~')).called(1);
      });

      test('sends End sequence', () async {
        await service.sendHomeEnd('end');
        verify(() => mockSession.writeRaw('\x1b[4~')).called(1);
      });

      test('throws for invalid key', () async {
        expect(() => service.sendHomeEnd('invalid'), throwsA(isA<Exception>()));
      });
    });

    group('sendPageUpDown', () {
      test('sends Page Up sequence', () async {
        await service.sendPageUpDown('up');
        verify(() => mockSession.writeRaw('\x1b[5~')).called(1);
      });

      test('sends Page Down sequence', () async {
        await service.sendPageUpDown('down');
        verify(() => mockSession.writeRaw('\x1b[6~')).called(1);
      });

      test('throws for invalid direction', () async {
        expect(
          () => service.sendPageUpDown('invalid'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendInsert', () {
      test('sends Insert sequence', () async {
        await service.sendInsert();
        verify(() => mockSession.writeRaw('\x1b[2~')).called(1);
      });
    });

    group('sendDelete', () {
      test('sends Delete sequence', () async {
        await service.sendDelete();
        verify(() => mockSession.writeRaw('\x1b[3~')).called(1);
      });
    });

    group('sendTab', () {
      test('sends tab character without shift', () async {
        await service.sendTab();
        verify(() => mockSession.writeRaw('\t')).called(1);
      });

      test('sends shift-tab sequence with shift', () async {
        await service.sendTab(shift: true);
        verify(() => mockSession.writeRaw('\x1b[Z')).called(1);
      });
    });

    group('sendEnter', () {
      test('sends carriage return', () async {
        await service.sendEnter();
        verify(() => mockSession.writeRaw('\r')).called(1);
      });
    });

    group('sendEscape', () {
      test('sends escape character', () async {
        await service.sendEscape();
        verify(() => mockSession.writeRaw('\x1b')).called(1);
      });
    });

    group('sendBackspace', () {
      test('sends backspace character', () async {
        await service.sendBackspace();
        verify(() => mockSession.writeRaw('\x7f')).called(1);
      });
    });

    group('setModifierKeys', () {
      test('sends modifier state OSC 200 sequence', () async {
        await service.setModifierKeys(
          const ModifierKeys(shift: true, alt: true),
        );
        verify(
          () => mockSession.writeRaw('\x1b]200;shift+alt\x1b\\'),
        ).called(1);
      });

      test('handles empty modifiers', () async {
        await service.setModifierKeys(const ModifierKeys());
        verify(() => mockSession.writeRaw('\x1b]200;\x1b\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyKeyboardService();
        expect(
          () => nullService.setModifierKeys(const ModifierKeys(shift: true)),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('queryModifierKeys', () {
      test('sends query OSC 200 sequence', () async {
        await service.queryModifierKeys();
        verify(() => mockSession.writeRaw('\x1b]200;?\x1b\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyKeyboardService();
        expect(
          () => nullService.queryModifierKeys(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('handleKeyboardResponse', () {
      test('calls onModifierChange for OSC 200 response', () {
        KeyboardEvent? receivedEvent;
        service.onModifierChange = (event) => receivedEvent = event;
        service.handleKeyboardResponse('200;shift+alt');
        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.type, KeyboardEventType.modifier);
        expect(receivedEvent!.modifiers.shift, isTrue);
        expect(receivedEvent!.modifiers.alt, isTrue);
        expect(receivedEvent!.modifiers.ctrl, isFalse);
        expect(receivedEvent!.modifiers.super_, isFalse);
      });

      test('calls onModifierChange for full modifier state', () {
        KeyboardEvent? receivedEvent;
        service.onModifierChange = (event) => receivedEvent = event;
        service.handleKeyboardResponse('200;shift+alt+ctrl+super');
        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.modifiers.shift, isTrue);
        expect(receivedEvent!.modifiers.alt, isTrue);
        expect(receivedEvent!.modifiers.ctrl, isTrue);
        expect(receivedEvent!.modifiers.super_, isTrue);
      });

      test('calls onTextInput for OSC 201 response', () {
        KeyboardEvent? receivedEvent;
        service.onTextInput = (event) => receivedEvent = event;
        service.handleKeyboardResponse('201;hello world');
        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.type, KeyboardEventType.textInput);
        expect(receivedEvent!.text, 'hello world');
      });

      test('handles empty modifier state', () {
        KeyboardEvent? receivedEvent;
        service.onModifierChange = (event) => receivedEvent = event;
        service.handleKeyboardResponse('200;');
        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.modifiers.isEmpty, isTrue);
      });

      test('does nothing for non-200/201 response', () {
        var modifierCalled = false;
        var textInputCalled = false;
        service.onModifierChange = (_) => modifierCalled = true;
        service.onTextInput = (_) => textInputCalled = true;
        service.handleKeyboardResponse('garbage');
        expect(modifierCalled, isFalse);
        expect(textInputCalled, isFalse);
      });

      test('does not throw for empty response', () {
        expect(() => service.handleKeyboardResponse(''), returnsNormally);
      });

      test('does not throw for malformed response', () {
        expect(() => service.handleKeyboardResponse('200;'), returnsNormally);
      });
    });
  });
}
