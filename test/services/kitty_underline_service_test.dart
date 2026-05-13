import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_underline_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyUnderlineService', () {
    late _MockTerminalSession mockSession;
    late KittyUnderlineService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyUnderlineService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyUnderlineService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('UnderlineConfig', () {
      test('uses default values', () {
        const config = UnderlineConfig();
        expect(config.style, UnderlineStyle.none);
        expect(config.color, UnderlineColor.default_);
        expect(config.customColor, isNull);
      });

      test('stores all fields', () {
        const config = UnderlineConfig(
          style: UnderlineStyle.double,
          color: UnderlineColor.curl,
          customColor: '#ff0000',
        );
        expect(config.style, UnderlineStyle.double);
        expect(config.color, UnderlineColor.curl);
        expect(config.customColor, '#ff0000');
      });
    });

    group('UnderlineStyle', () {
      test('has all style values', () {
        expect(UnderlineStyle.values, hasLength(7));
        expect(UnderlineStyle.values[0], UnderlineStyle.none);
        expect(UnderlineStyle.values[1], UnderlineStyle.single);
        expect(UnderlineStyle.values[2], UnderlineStyle.double);
        expect(UnderlineStyle.values[3], UnderlineStyle.curly);
        expect(UnderlineStyle.values[4], UnderlineStyle.dotted);
        expect(UnderlineStyle.values[5], UnderlineStyle.dashed);
        expect(UnderlineStyle.values[6], UnderlineStyle.underline);
      });
    });

    group('UnderlineColor', () {
      test('has all color values', () {
        expect(UnderlineColor.values, hasLength(6));
        expect(UnderlineColor.values[0], UnderlineColor.default_);
        expect(UnderlineColor.values[1], UnderlineColor.curl);
        expect(UnderlineColor.values[2], UnderlineColor.strike);
        expect(UnderlineColor.values[3], UnderlineColor.hyperlink);
        expect(UnderlineColor.values[4], UnderlineColor.foreground);
        expect(UnderlineColor.values[5], UnderlineColor.background);
      });
    });

    group('currentConfig', () {
      test('starts with default config', () {
        expect(service.currentConfig.style, UnderlineStyle.none);
        expect(service.currentConfig.color, UnderlineColor.default_);
        expect(service.currentConfig.customColor, isNull);
      });
    });

    group('setStyle', () {
      for (final entry in [
        (style: UnderlineStyle.none, cmd: '\x1b[4:58:0m'),
        (style: UnderlineStyle.single, cmd: '\x1b[4:58:1m'),
        (style: UnderlineStyle.double, cmd: '\x1b[4:58:2m'),
        (style: UnderlineStyle.curly, cmd: '\x1b[4:58:3m'),
        (style: UnderlineStyle.dotted, cmd: '\x1b[4:58:4m'),
        (style: UnderlineStyle.dashed, cmd: '\x1b[4:58:5m'),
        (style: UnderlineStyle.underline, cmd: '\x1b[4:58:6m'),
      ]) {
        test('sends correct CSI for ${entry.style.name}', () async {
          await service.setStyle(entry.style);
          verify(() => mockSession.writeRaw(entry.cmd)).called(1);
        });

        test('updates config for ${entry.style.name}', () async {
          await service.setStyle(entry.style);
          expect(service.currentConfig.style, entry.style);
        });
      }

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.setStyle(UnderlineStyle.single),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setColor', () {
      test('sends command for curl color', () async {
        await service.setColor(UnderlineColor.curl);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=1m')).called(1);
      });

      test('sends command for strike color', () async {
        await service.setColor(UnderlineColor.strike);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=2m')).called(1);
      });

      test('sends command for hyperlink color', () async {
        await service.setColor(UnderlineColor.hyperlink);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=3m')).called(1);
      });

      test('sends command for foreground color', () async {
        await service.setColor(UnderlineColor.foreground);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=4m')).called(1);
      });

      test('sends command for background color', () async {
        await service.setColor(UnderlineColor.background);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=5m')).called(1);
      });

      test('sends custom color with default_', () async {
        await service.setColor(UnderlineColor.default_, customColor: '#ff0');
        verify(() => mockSession.writeRaw('\x1b[4:58:color=#ff0m')).called(1);
      });

      test('does not send command for default_ without custom color', () async {
        await service.setColor(UnderlineColor.default_);
        verifyNever(() => mockSession.writeRaw(any()));
      });

      test('updates config', () async {
        await service.setColor(UnderlineColor.curl);
        expect(service.currentConfig.color, UnderlineColor.curl);
      });

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.setColor(UnderlineColor.curl),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setCustomColor', () {
      test('converts #rrggbb to rgb format', () async {
        await service.setCustomColor('#ff8800');
        verify(() => mockSession.writeRaw('\x1b[4:58:color=rgb:ff/88/00m'))
            .called(1);
      });

      test('passes through rgb format', () async {
        await service.setCustomColor('rgb:ff/88/00');
        verify(
          () => mockSession.writeRaw('\x1b[4:58:color=rgb:ff/88/00m'),
        ).called(1);
      });

      test('passes through short hex', () async {
        await service.setCustomColor('#f80');
        verify(() => mockSession.writeRaw('\x1b[4:58:color=#f80m')).called(1);
      });

      test('updates config', () async {
        await service.setCustomColor('#ff0000');
        expect(service.currentConfig.customColor, 'rgb:ff/00/00');
      });

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.setCustomColor('#ff0000'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setConfig', () {
      test('sets style and custom color', () async {
        await service.setConfig(
          const UnderlineConfig(
            style: UnderlineStyle.double,
            customColor: '#ff0000',
          ),
        );
        verify(() => mockSession.writeRaw('\x1b[4:58:2m')).called(1);
        verify(() => mockSession.writeRaw('\x1b[4:58:color=rgb:ff/00/00m'))
            .called(1);
      });

      test('sets style without custom color', () async {
        await service.setConfig(
          const UnderlineConfig(style: UnderlineStyle.curly),
        );
        verify(() => mockSession.writeRaw('\x1b[4:58:3m')).called(1);
        verifyNever(
          () => mockSession.writeRaw(any(that: contains('color='))),
        );
      });

      test('updates config', () async {
        await service.setConfig(
          const UnderlineConfig(style: UnderlineStyle.dashed),
        );
        expect(service.currentConfig.style, UnderlineStyle.dashed);
      });
    });

    group('style convenience methods', () {
      test('disable delegates to setStyle none', () async {
        await service.disable();
        verify(() => mockSession.writeRaw('\x1b[4:58:0m')).called(1);
      });

      test('single delegates to setStyle single', () async {
        await service.single();
        verify(() => mockSession.writeRaw('\x1b[4:58:1m')).called(1);
      });

      test('double_ delegates to setStyle double', () async {
        await service.double_();
        verify(() => mockSession.writeRaw('\x1b[4:58:2m')).called(1);
      });

      test('curly delegates to setStyle curly', () async {
        await service.curly();
        verify(() => mockSession.writeRaw('\x1b[4:58:3m')).called(1);
      });

      test('dotted delegates to setStyle dotted', () async {
        await service.dotted();
        verify(() => mockSession.writeRaw('\x1b[4:58:4m')).called(1);
      });

      test('dashed delegates to setStyle dashed', () async {
        await service.dashed();
        verify(() => mockSession.writeRaw('\x1b[4:58:5m')).called(1);
      });

      test('thick delegates to setStyle underline', () async {
        await service.thick();
        verify(() => mockSession.writeRaw('\x1b[4:58:6m')).called(1);
      });

      test('convenience methods update config', () async {
        await service.double_();
        expect(service.currentConfig.style, UnderlineStyle.double);

        await service.thick();
        expect(service.currentConfig.style, UnderlineStyle.underline);
      });
    });

    group('color convenience methods', () {
      test('resetColor delegates to setColor default_', () async {
        await service.resetColor();
        verifyNever(() => mockSession.writeRaw(any()));
      });

      test('useCurlColor sends curl color command', () async {
        await service.useCurlColor();
        verify(() => mockSession.writeRaw('\x1b[4:58:color=1m')).called(1);
      });

      test('useStrikeColor sends strike color command', () async {
        await service.useStrikeColor();
        verify(() => mockSession.writeRaw('\x1b[4:58:color=2m')).called(1);
      });

      test('useHyperlinkColor sends hyperlink color command', () async {
        await service.useHyperlinkColor();
        verify(() => mockSession.writeRaw('\x1b[4:58:color=3m')).called(1);
      });

      test('useForegroundColor sends foreground color command', () async {
        await service.useForegroundColor();
        verify(() => mockSession.writeRaw('\x1b[4:58:color=4m')).called(1);
      });

      test('useBackgroundColor sends background color command', () async {
        await service.useBackgroundColor();
        verify(() => mockSession.writeRaw('\x1b[4:58:color=5m')).called(1);
      });

      test('convenience methods update config', () async {
        await service.useCurlColor();
        expect(service.currentConfig.color, UnderlineColor.curl);
      });
    });

    group('reset', () {
      test('sends reset command', () async {
        await service.reset();
        verify(() => mockSession.writeRaw('\x1b[4:58:0m')).called(1);
      });

      test('resets config to defaults', () async {
        await service.setStyle(UnderlineStyle.double);
        await service.setColor(UnderlineColor.curl);
        await service.reset();
        expect(service.currentConfig.style, UnderlineStyle.none);
        expect(service.currentConfig.color, UnderlineColor.default_);
      });

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.reset(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setColorIndex', () {
      test('sends SGR 58 command', () async {
        await service.setColorIndex(42);
        verify(() => mockSession.writeRaw('\x1b[58:5:42m')).called(1);
      });

      test('throws for index below 0', () async {
        expect(
          () => service.setColorIndex(-1),
          throwsA(isA<Exception>()),
        );
      });

      test('throws for index above 255', () async {
        expect(
          () => service.setColorIndex(256),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.setColorIndex(0),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setTrueColor', () {
      test('sends SGR 58:2 command', () async {
        await service.setTrueColor(100, 150, 200);
        verify(() => mockSession.writeRaw('\x1b[58:2:100;150;200m'))
            .called(1);
      });

      test('throws for r below 0', () async {
        expect(
          () => service.setTrueColor(-1, 0, 0),
          throwsA(isA<Exception>()),
        );
      });

      test('throws for g above 255', () async {
        expect(
          () => service.setTrueColor(0, 256, 0),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when session is null', () async {
        final nullService = KittyUnderlineService();
        expect(
          () => nullService.setTrueColor(0, 0, 0),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
