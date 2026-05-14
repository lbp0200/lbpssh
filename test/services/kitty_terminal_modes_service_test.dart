import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_terminal_modes_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyTerminalModesService', () {
    late _MockTerminalSession mockSession;
    late KittyTerminalModesService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyTerminalModesService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyTerminalModesService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setMode', () {
      test('sends CSI h command with mode value', () async {
        await service.setMode(TerminalMode.cursorVisible);
        verify(() => mockSession.writeRaw('\x1b[?25h')).called(1);
      });

      test('caches mode as set', () async {
        await service.setMode(TerminalMode.autoWrap);
        expect(service.getModeState(TerminalMode.autoWrap), isTrue);
      });

      test('throws when session is null', () async {
        final nullService = KittyTerminalModesService();
        expect(
          () => nullService.setMode(TerminalMode.cursorVisible),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('resetMode', () {
      test('sends CSI l command with mode value', () async {
        await service.resetMode(TerminalMode.cursorVisible);
        verify(() => mockSession.writeRaw('\x1b[?25l')).called(1);
      });

      test('caches mode as not set', () async {
        await service.resetMode(TerminalMode.autoWrap);
        expect(service.getModeState(TerminalMode.autoWrap), isFalse);
      });

      test('throws when session is null', () async {
        final nullService = KittyTerminalModesService();
        expect(
          () => nullService.resetMode(TerminalMode.cursorVisible),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('toggleMode', () {
      test('sets mode when currently unknown (default false)', () async {
        await service.toggleMode(TerminalMode.autoWrap);
        verify(() => mockSession.writeRaw('\x1b[?7h')).called(1);
      });

      test('resets mode when currently set', () async {
        await service.setMode(TerminalMode.autoWrap);
        await service.toggleMode(TerminalMode.autoWrap);
        verify(() => mockSession.writeRaw('\x1b[?7l')).called(1);
      });

      test('sets mode when currently reset', () async {
        await service.resetMode(TerminalMode.autoWrap);
        await service.toggleMode(TerminalMode.autoWrap);
        verify(() => mockSession.writeRaw('\x1b[?7h')).called(1);
      });
    });

    group('queryMode', () {
      test('sends CSI p query command', () async {
        await service.queryMode(TerminalMode.cursorKeys);
        verify(() => mockSession.writeRaw('\x1b[?0p')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyTerminalModesService();
        expect(
          () => nullService.queryMode(TerminalMode.cursorKeys),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('queryAllModes', () {
      test('queries every TerminalMode value', () async {
        await service.queryAllModes();
        for (final mode in TerminalMode.values) {
          verify(() => mockSession.writeRaw('\x1b[?${mode.value}p')).called(1);
        }
      });
    });

    group('getModeState', () {
      test('returns null for uncached mode', () {
        expect(service.getModeState(TerminalMode.cursorVisible), isNull);
      });

      test('returns cached value after setMode', () async {
        await service.setMode(TerminalMode.cursorVisible);
        expect(service.getModeState(TerminalMode.cursorVisible), isTrue);
      });

      test('returns cached value after resetMode', () async {
        await service.resetMode(TerminalMode.cursorVisible);
        expect(service.getModeState(TerminalMode.cursorVisible), isFalse);
      });
    });

    group('Bracketed Paste', () {
      test('enableBracketedPaste sets bracketedPaste mode', () async {
        await service.enableBracketedPaste();
        verify(() => mockSession.writeRaw('\x1b[?2004h')).called(1);
      });

      test('disableBracketedPaste resets bracketedPaste mode', () async {
        await service.disableBracketedPaste();
        verify(() => mockSession.writeRaw('\x1b[?2004l')).called(1);
      });
    });

    group('Kitty Graphics', () {
      test('enableKittyGraphics sets kittyGraphics mode', () async {
        await service.enableKittyGraphics();
        verify(() => mockSession.writeRaw('\x1b[?71h')).called(1);
      });

      test('disableKittyGraphics resets kittyGraphics mode', () async {
        await service.disableKittyGraphics();
        verify(() => mockSession.writeRaw('\x1b[?71l')).called(1);
      });
    });

    group('Mouse Tracking', () {
      test('enableMouseTracking with click sets sgrMouse', () async {
        await service.enableMouseTracking();
        verify(() => mockSession.writeRaw('\x1b[?1006h')).called(1);
      });

      test('enableMouseTracking with any sets kittyGraphics', () async {
        await service.enableMouseTracking(mode: MouseTrackingMode.any);
        verify(() => mockSession.writeRaw('\x1b[?71h')).called(1);
      });

      test('enableMouseTracking with highlight sets iTerm2Highlight', () async {
        await service.enableMouseTracking(mode: MouseTrackingMode.highlight);
        verify(() => mockSession.writeRaw('\x1b[?1002h')).called(1);
      });

      test('disableMouseTracking resets all mouse tracking modes', () async {
        await service.disableMouseTracking();
        verify(() => mockSession.writeRaw('\x1b[?1000l')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?1002l')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?1005l')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?1006l')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?1015l')).called(1);
      });
    });

    group('Application Cursor Keys', () {
      test('enableApplicationCursorKeys sets cursorKeys mode', () async {
        await service.enableApplicationCursorKeys();
        verify(() => mockSession.writeRaw('\x1b[?0h')).called(1);
      });

      test('disableApplicationCursorKeys resets cursorKeys mode', () async {
        await service.disableApplicationCursorKeys();
        verify(() => mockSession.writeRaw('\x1b[?0l')).called(1);
      });
    });

    group('Auto Wrap', () {
      test('enableAutoWrap sets autoWrap mode', () async {
        await service.enableAutoWrap();
        verify(() => mockSession.writeRaw('\x1b[?7h')).called(1);
      });

      test('disableAutoWrap resets autoWrap mode', () async {
        await service.disableAutoWrap();
        verify(() => mockSession.writeRaw('\x1b[?7l')).called(1);
      });
    });

    group('Cursor', () {
      test('showCursor sets cursorVisible mode', () async {
        await service.showCursor();
        verify(() => mockSession.writeRaw('\x1b[?25h')).called(1);
      });

      test('hideCursor resets cursorVisible mode', () async {
        await service.hideCursor();
        verify(() => mockSession.writeRaw('\x1b[?25l')).called(1);
      });
    });

    group('132 Columns', () {
      test('enable132Columns sets column132 mode', () async {
        await service.enable132Columns();
        verify(() => mockSession.writeRaw('\x1b[?1h')).called(1);
      });

      test('disable132Columns resets column132 mode', () async {
        await service.disable132Columns();
        verify(() => mockSession.writeRaw('\x1b[?1l')).called(1);
      });
    });

    group('Synchronized Output', () {
      test('enableSynchronizedOutput sets synchronizedOutput mode', () async {
        await service.enableSynchronizedOutput();
        verify(() => mockSession.writeRaw('\x1b[?2022h')).called(1);
      });

      test(
        'disableSynchronizedOutput resets synchronizedOutput mode',
        () async {
          await service.disableSynchronizedOutput();
          verify(() => mockSession.writeRaw('\x1b[?2022l')).called(1);
        },
      );
    });

    group('Sixel', () {
      test('enableSixel sets both sixel modes', () async {
        await service.enableSixel();
        verify(() => mockSession.writeRaw('\x1b[?6070h')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?8452h')).called(1);
      });

      test('disableSixel resets both sixel modes', () async {
        await service.disableSixel();
        verify(() => mockSession.writeRaw('\x1b[?6070l')).called(1);
        verify(() => mockSession.writeRaw('\x1b[?8452l')).called(1);
      });
    });

    group('resetAllModes', () {
      test('sends soft reset ESC ! p', () async {
        await service.resetAllModes();
        verify(() => mockSession.writeRaw('\x1b[!p')).called(1);
      });

      test('clears mode cache', () async {
        await service.setMode(TerminalMode.autoWrap);
        await service.resetAllModes();
        expect(service.getModeState(TerminalMode.autoWrap), isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittyTerminalModesService();
        expect(() => nullService.resetAllModes(), throwsA(isA<Exception>()));
      });
    });

    group('hardReset', () {
      test('sends RIS escape sequences', () async {
        await service.hardReset();
        verify(() => mockSession.writeRaw('\x1b c')).called(1);
        verify(() => mockSession.writeRaw('\x1b]c\x1b\\\\')).called(1);
      });

      test('clears mode cache', () async {
        await service.setMode(TerminalMode.autoWrap);
        await service.hardReset();
        expect(service.getModeState(TerminalMode.autoWrap), isNull);
      });

      test('throws when session is null', () async {
        final nullService = KittyTerminalModesService();
        expect(() => nullService.hardReset(), throwsA(isA<Exception>()));
      });
    });

    group('handleModeResponse', () {
      test('parses set response and updates cache', () {
        service.handleModeResponse('[\x1b[?25\x241');
        // \x1b[?25$1 → mode 25 (cursorVisible) = set
      });

      test('parses reset response and updates cache', () {
        service.handleModeResponse('\x1b[?0\x242');
        // \x1b[?0$2 → mode 0 (cursorKeys) = reset
        expect(service.getModeState(TerminalMode.cursorKeys), isFalse);
      });

      test('ignores invalid response', () {
        // Should not throw
        service.handleModeResponse('garbage');
        // No cache update
      });
    });

    group('TerminalMode enum', () {
      test('has all expected values', () {
        expect(TerminalMode.cursorKeys.value, 0);
        expect(TerminalMode.column132.value, 1);
        expect(TerminalMode.smoothScroll.value, 4);
        expect(TerminalMode.reverseVideo.value, 5);
        expect(TerminalMode.originMode.value, 6);
        expect(TerminalMode.autoWrap.value, 7);
        expect(TerminalMode.autoRepeat.value, 8);
        expect(TerminalMode.cursorVisible.value, 25);
        expect(TerminalMode.bracketedPaste.value, 2004);
        expect(TerminalMode.synchronizedOutput.value, 2022);
        expect(TerminalMode.sixelScrolling.value, 8452);
        expect(TerminalMode.kittyGraphics.value, 71);
      });

      test('has descriptions', () {
        expect(TerminalMode.autoWrap.description, contains('DECAWM'));
        expect(TerminalMode.cursorVisible.description, contains('DECTCEM'));
      });
    });

    group('MouseTrackingMode enum', () {
      test('has expected values', () {
        expect(MouseTrackingMode.values.length, 3);
      });
    });
  });
}
