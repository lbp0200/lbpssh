import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_extended_protocol_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyHyperlinkService', () {
    late _MockTerminalSession mockSession;
    late KittyHyperlinkService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyHyperlinkService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyHyperlinkService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('openHyperlink', () {
      test('sends OSC 8 with URI', () async {
        await service.openHyperlink('https://example.com');
        verify(
          () => mockSession.writeRaw('\x1b]8;https://example.com\x1b\\\\'),
        ).called(1);
      });

      test('includes id when provided', () async {
        await service.openHyperlink('https://example.com', id: 'link123');
        verify(
          () => mockSession.writeRaw(
            '\x1b]8;id=link123;https://example.com\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyHyperlinkService();
        expect(
          () => nullService.openHyperlink('https://example.com'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('closeHyperlink', () {
      test('sends OSC 8 with no parameters', () async {
        await service.closeHyperlink();
        verify(() => mockSession.writeRaw('\x1b]8;\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyHyperlinkService();
        expect(() => nullService.closeHyperlink(), throwsA(isA<Exception>()));
      });
    });
  });

  group('KittyPointerShapeService', () {
    late _MockTerminalSession mockSession;
    late KittyPointerShapeService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyPointerShapeService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyPointerShapeService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setPointerShape', () {
      test('sends OSC 22 with shape name', () async {
        await service.setPointerShape('hand');
        verify(() => mockSession.writeRaw('\x1b]22;hand\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyPointerShapeService();
        expect(
          () => nullService.setPointerShape('default'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('resetPointerShape', () {
      test('sends OSC 22 with empty value', () async {
        await service.resetPointerShape();
        verify(() => mockSession.writeRaw('\x1b]22;\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyPointerShapeService();
        expect(
          () => nullService.resetPointerShape(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('shapes', () {
      test('contains expected shape constants', () {
        expect(KittyPointerShapeService.shapes['default'], 'default');
        expect(KittyPointerShapeService.shapes['pointer'], 'pointer');
        expect(KittyPointerShapeService.shapes['hand'], 'hand');
        expect(KittyPointerShapeService.shapes['text'], 'text');
        expect(KittyPointerShapeService.shapes['crosshair'], 'crosshair');
        expect(KittyPointerShapeService.shapes.length, 17);
      });
    });
  });

  group('KittyColorStackService', () {
    late _MockTerminalSession mockSession;
    late KittyColorStackService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyColorStackService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyColorStackService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('pushColor', () {
      test('sends OSC 4 with foreground color', () async {
        await service.pushColor('#ff0000');
        verify(
          () => mockSession.writeRaw('\x1b]4;0;#ff0000\x1b\\\\'),
        ).called(1);
      });

      test('sends OSC 4 with background color', () async {
        await service.pushColor('#00ff00', isForeground: false);
        verify(
          () => mockSession.writeRaw('\x1b]4;1;#00ff00\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyColorStackService();
        expect(() => nullService.pushColor('#000'), throwsA(isA<Exception>()));
      });
    });

    group('popColor', () {
      test('sends OSC 4 with foreground pop', () async {
        await service.popColor();
        verify(() => mockSession.writeRaw('\x1b]4;0;-\x1b\\\\')).called(1);
      });

      test('sends OSC 4 with background pop', () async {
        await service.popColor(isForeground: false);
        verify(() => mockSession.writeRaw('\x1b]4;1;-\x1b\\\\')).called(1);
      });
    });

    group('setDefaultColor', () {
      test('sends OSC 4 with foreground', () async {
        await service.setDefaultColor('#ffffff');
        verify(
          () => mockSession.writeRaw('\x1b]4;0;#ffffff\x1b\\\\'),
        ).called(1);
      });

      test('sends OSC 4 with background', () async {
        await service.setDefaultColor('#000000', isForeground: false);
        verify(
          () => mockSession.writeRaw('\x1b]4;1;#000000\x1b\\\\'),
        ).called(1);
      });
    });

    group('useOriginalColor', () {
      test('sends OSC 21 with foreground reset', () async {
        await service.useOriginalColor();
        verify(() => mockSession.writeRaw('\x1b]21;P;r=10\x1b\\\\')).called(1);
      });

      test('sends OSC 21 with background reset', () async {
        await service.useOriginalColor(isForeground: false);
        verify(() => mockSession.writeRaw('\x1b]21;P;r=11\x1b\\\\')).called(1);
      });
    });

    group('swapColors', () {
      test('sends OSC 21 with r=104', () async {
        await service.swapColors();
        verify(() => mockSession.writeRaw('\x1b]21;P;r=104\x1b\\\\')).called(1);
      });
    });

    group('resetColorStack', () {
      test('sends OSC 4 with reset command', () async {
        await service.resetColorStack();
        verify(() => mockSession.writeRaw('\x1b]4;r\x1b\\\\')).called(1);
      });
    });

    group('throws when session is null', () {
      test('popColor', () async {
        final nullService = KittyColorStackService();
        expect(() => nullService.popColor(), throwsA(isA<Exception>()));
      });

      test('setDefaultColor', () async {
        final nullService = KittyColorStackService();
        expect(
          () => nullService.setDefaultColor('#fff'),
          throwsA(isA<Exception>()),
        );
      });

      test('useOriginalColor', () async {
        final nullService = KittyColorStackService();
        expect(() => nullService.useOriginalColor(), throwsA(isA<Exception>()));
      });

      test('swapColors', () async {
        final nullService = KittyColorStackService();
        expect(() => nullService.swapColors(), throwsA(isA<Exception>()));
      });

      test('resetColorStack', () async {
        final nullService = KittyColorStackService();
        expect(() => nullService.resetColorStack(), throwsA(isA<Exception>()));
      });
    });
  });

  group('KittyTextSizeService', () {
    late _MockTerminalSession mockSession;
    late KittyTextSizeService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyTextSizeService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyTextSizeService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setTextSize', () {
      test('sends OSC > with size', () async {
        await service.setTextSize(14);
        verify(() => mockSession.writeRaw('\x1b]>14\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyTextSizeService();
        expect(() => nullService.setTextSize(12), throwsA(isA<Exception>()));
      });
    });

    group('queryTextSize', () {
      test('sends OSC > with empty value', () async {
        await service.queryTextSize();
        verify(() => mockSession.writeRaw('\x1b]>\x1b\\\\')).called(1);
      });
    });

    group('increaseTextSize', () {
      test('sends OSC > +', () async {
        await service.increaseTextSize();
        verify(() => mockSession.writeRaw('\x1b]>+\x1b\\\\')).called(1);
      });
    });

    group('decreaseTextSize', () {
      test('sends OSC > -', () async {
        await service.decreaseTextSize();
        verify(() => mockSession.writeRaw('\x1b]>-\x1b\\\\')).called(1);
      });
    });

    group('throws when session is null', () {
      test('queryTextSize', () async {
        final nullService = KittyTextSizeService();
        expect(() => nullService.queryTextSize(), throwsA(isA<Exception>()));
      });

      test('increaseTextSize', () async {
        final nullService = KittyTextSizeService();
        expect(() => nullService.increaseTextSize(), throwsA(isA<Exception>()));
      });

      test('decreaseTextSize', () async {
        final nullService = KittyTextSizeService();
        expect(() => nullService.decreaseTextSize(), throwsA(isA<Exception>()));
      });
    });
  });

  group('KittyMarksService', () {
    late _MockTerminalSession mockSession;
    late KittyMarksService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyMarksService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyMarksService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setMark', () {
      test('sends OSC 133 M with name', () async {
        await service.setMark('mark1');
        verify(
          () => mockSession.writeRaw('\x1b]133;M;mark1\x1b\\\\'),
        ).called(1);
      });

      test('appends ;i when visible is false', () async {
        await service.setMark('hiddenMark', visible: false);
        verify(
          () => mockSession.writeRaw('\x1b]133;M;hiddenMark;i\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMarksService();
        expect(() => nullService.setMark('m'), throwsA(isA<Exception>()));
      });
    });

    group('gotoMark', () {
      test('sends OSC 133 G with name', () async {
        await service.gotoMark('mark1');
        verify(
          () => mockSession.writeRaw('\x1b]133;G;mark1\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMarksService();
        expect(() => nullService.gotoMark('m'), throwsA(isA<Exception>()));
      });
    });

    group('clearMark', () {
      test('sends OSC 133 m with name', () async {
        await service.clearMark(name: 'mark1');
        verify(
          () => mockSession.writeRaw('\x1b]133;m;mark1\x1b\\\\'),
        ).called(1);
      });

      test('uses wildcard when name is null', () async {
        await service.clearMark();
        verify(() => mockSession.writeRaw('\x1b]133;m;*\x1b\\\\')).called(1);
      });
    });

    group('queryMark', () {
      test('sends OSC 133 q with name', () async {
        await service.queryMark(name: 'mark1');
        verify(
          () => mockSession.writeRaw('\x1b]133;q;mark1\x1b\\\\'),
        ).called(1);
      });

      test('uses wildcard when name is null', () async {
        await service.queryMark();
        verify(() => mockSession.writeRaw('\x1b]133;q;*\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMarksService();
        expect(() => nullService.queryMark(), throwsA(isA<Exception>()));
      });
    });
  });

  group('KittyWindowTitleService', () {
    late _MockTerminalSession mockSession;
    late KittyWindowTitleService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyWindowTitleService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyWindowTitleService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setTitle', () {
      test('sends OSC 0 with title', () async {
        await service.setTitle('My Terminal');
        verify(
          () => mockSession.writeRaw('\x1b]0;My Terminal\x1b\\\\'),
        ).called(1);
      });
    });

    group('setIconName', () {
      test('sends OSC 1 with name', () async {
        await service.setIconName('icon');
        verify(() => mockSession.writeRaw('\x1b]1;icon\x1b\\\\')).called(1);
      });
    });

    group('setTitleAndIcon', () {
      test('sends OSC 2 with title', () async {
        await service.setTitleAndIcon('Title');
        verify(() => mockSession.writeRaw('\x1b]2;Title\x1b\\\\')).called(1);
      });

      test('uses iconName when provided', () async {
        await service.setTitleAndIcon('Title', iconName: 'Icon');
        verify(() => mockSession.writeRaw('\x1b]2;Icon\x1b\\\\')).called(1);
      });
    });

    group('reportTitle', () {
      test('sends OSC 21 t', () async {
        await service.reportTitle();
        verify(() => mockSession.writeRaw('\x1b]21;t\x1b\\\\')).called(1);
      });
    });

    group('setBackgroundColor', () {
      test('sends OSC 11 with color', () async {
        await service.setBackgroundColor('#1e1e2e');
        verify(() => mockSession.writeRaw('\x1b]11;#1e1e2e\x1b\\\\')).called(1);
      });
    });

    group('throws when session is null', () {
      test('setTitle', () async {
        final nullService = KittyWindowTitleService();
        expect(() => nullService.setTitle('T'), throwsA(isA<Exception>()));
      });

      test('setIconName', () async {
        final nullService = KittyWindowTitleService();
        expect(() => nullService.setIconName('I'), throwsA(isA<Exception>()));
      });

      test('setTitleAndIcon', () async {
        final nullService = KittyWindowTitleService();
        expect(
          () => nullService.setTitleAndIcon('T'),
          throwsA(isA<Exception>()),
        );
      });

      test('reportTitle', () async {
        final nullService = KittyWindowTitleService();
        expect(() => nullService.reportTitle(), throwsA(isA<Exception>()));
      });

      test('setBackgroundColor', () async {
        final nullService = KittyWindowTitleService();
        expect(
          () => nullService.setBackgroundColor('#fff'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('KittyPromptColorService', () {
    late _MockTerminalSession mockSession;
    late KittyPromptColorService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyPromptColorService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyPromptColorService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('setForegroundColor', () {
      test('sends OSC 10 with color', () async {
        await service.setForegroundColor('#ffffff');
        verify(() => mockSession.writeRaw('\x1b]10;#ffffff\x1b\\\\')).called(1);
      });
    });

    group('setCursorColor', () {
      test('sends OSC 12 with color', () async {
        await service.setCursorColor('#ff0000');
        verify(() => mockSession.writeRaw('\x1b]12;#ff0000\x1b\\\\')).called(1);
      });
    });

    group('setPointerForegroundColor', () {
      test('sends OSC 13 with color', () async {
        await service.setPointerForegroundColor('#000000');
        verify(() => mockSession.writeRaw('\x1b]13;#000000\x1b\\\\')).called(1);
      });
    });

    group('setPointerBackgroundColor', () {
      test('sends OSC 14 with color', () async {
        await service.setPointerBackgroundColor('#ffffff');
        verify(() => mockSession.writeRaw('\x1b]14;#ffffff\x1b\\\\')).called(1);
      });
    });

    group('setHighlightForegroundColor', () {
      test('sends OSC 17 with color', () async {
        await service.setHighlightForegroundColor('#ffff00');
        verify(() => mockSession.writeRaw('\x1b]17;#ffff00\x1b\\\\')).called(1);
      });
    });

    group('setTerminalBackgroundColor', () {
      test('sends OSC 708 with color', () async {
        await service.setTerminalBackgroundColor('#1e1e2e');
        verify(
          () => mockSession.writeRaw('\x1b]708;#1e1e2e\x1b\\\\'),
        ).called(1);
      });
    });

    group('setSelectionForegroundColor', () {
      test('sends OSC 132 with color', () async {
        await service.setSelectionForegroundColor('#cdd6f4');
        verify(
          () => mockSession.writeRaw('\x1b]132;#cdd6f4\x1b\\\\'),
        ).called(1);
      });
    });

    group('setSelectionBackgroundColor', () {
      test('sends OSC 131 with color', () async {
        await service.setSelectionBackgroundColor('#45475a');
        verify(
          () => mockSession.writeRaw('\x1b]131;#45475a\x1b\\\\'),
        ).called(1);
      });
    });

    group('throws when session is null', () {
      test('setForegroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setForegroundColor('#fff'),
          throwsA(isA<Exception>()),
        );
      });

      test('setCursorColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setCursorColor('#000'),
          throwsA(isA<Exception>()),
        );
      });

      test('setPointerForegroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setPointerForegroundColor('#000'),
          throwsA(isA<Exception>()),
        );
      });

      test('setPointerBackgroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setPointerBackgroundColor('#fff'),
          throwsA(isA<Exception>()),
        );
      });

      test('setHighlightForegroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setHighlightForegroundColor('#ff0'),
          throwsA(isA<Exception>()),
        );
      });

      test('setTerminalBackgroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setTerminalBackgroundColor('#000'),
          throwsA(isA<Exception>()),
        );
      });

      test('setSelectionForegroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setSelectionForegroundColor('#fff'),
          throwsA(isA<Exception>()),
        );
      });

      test('setSelectionBackgroundColor', () async {
        final nullService = KittyPromptColorService();
        expect(
          () => nullService.setSelectionBackgroundColor('#000'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
