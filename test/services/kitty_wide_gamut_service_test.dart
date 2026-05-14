import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_wide_gamut_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyWideGamutService', () {
    late _MockTerminalSession mockSession;
    late KittyWideGamutService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyWideGamutService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyWideGamutService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('ColorSpace', () {
      test('has all space values', () {
        expect(ColorSpace.values, hasLength(5));
        expect(ColorSpace.values[0], ColorSpace.sRGB);
        expect(ColorSpace.values[1], ColorSpace.displayP3);
        expect(ColorSpace.values[2], ColorSpace.rec2020);
        expect(ColorSpace.values[3], ColorSpace.a98RGB);
        expect(ColorSpace.values[4], ColorSpace.proPhoto);
      });
    });

    group('ColorProfile', () {
      test('stores space', () {
        const profile = ColorProfile(space: ColorSpace.displayP3);
        expect(profile.space, ColorSpace.displayP3);
      });

      test('stores optional chromaticity values', () {
        const profile = ColorProfile(
          space: ColorSpace.sRGB,
          redX: 0.64,
          redY: 0.33,
          greenX: 0.3,
          greenY: 0.6,
          blueX: 0.15,
          blueY: 0.06,
          whiteX: 0.3127,
          whiteY: 0.329,
          gamma: 2.2,
        );
        expect(profile.redX, 0.64);
        expect(profile.redY, 0.33);
        expect(profile.greenX, 0.3);
        expect(profile.greenY, 0.6);
        expect(profile.blueX, 0.15);
        expect(profile.blueY, 0.06);
        expect(profile.whiteX, 0.3127);
        expect(profile.whiteY, 0.329);
        expect(profile.gamma, 2.2);
      });
    });

    group('currentProfile', () {
      test('defaults to sRGB', () {
        expect(service.currentProfile.space, ColorSpace.sRGB);
      });
    });

    group('setColorSpace', () {
      for (final entry in [
        (space: ColorSpace.sRGB, str: 'srgb'),
        (space: ColorSpace.displayP3, str: 'display-p3'),
        (space: ColorSpace.rec2020, str: 'rec2020'),
        (space: ColorSpace.a98RGB, str: 'a98rgb'),
        (space: ColorSpace.proPhoto, str: 'prophoto'),
      ]) {
        test('sends correct OSC for ${entry.space.name}', () async {
          await service.setColorSpace(entry.space);
          verify(
            () =>
                mockSession.writeRaw('\x1b]10;colorspace=${entry.str}\x1b\\\\'),
          ).called(1);
        });

        test('updates profile for ${entry.space.name}', () async {
          await service.setColorSpace(entry.space);
          expect(service.currentProfile.space, entry.space);
        });
      }

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setColorSpace(ColorSpace.displayP3),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('color space convenience methods', () {
      test('useSRGB delegates to setColorSpace', () async {
        await service.useSRGB();
        verify(
          () => mockSession.writeRaw('\x1b]10;colorspace=srgb\x1b\\\\'),
        ).called(1);
      });

      test('useDisplayP3 delegates to setColorSpace', () async {
        await service.useDisplayP3();
        verify(
          () => mockSession.writeRaw('\x1b]10;colorspace=display-p3\x1b\\\\'),
        ).called(1);
      });

      test('useRec2020 delegates to setColorSpace', () async {
        await service.useRec2020();
        verify(
          () => mockSession.writeRaw('\x1b]10;colorspace=rec2020\x1b\\\\'),
        ).called(1);
      });

      test('useA98RGB delegates to setColorSpace', () async {
        await service.useA98RGB();
        verify(
          () => mockSession.writeRaw('\x1b]10;colorspace=a98rgb\x1b\\\\'),
        ).called(1);
      });

      test('useProPhoto delegates to setColorSpace', () async {
        await service.useProPhoto();
        verify(
          () => mockSession.writeRaw('\x1b]10;colorspace=prophoto\x1b\\\\'),
        ).called(1);
      });
    });

    group('setCustomProfile', () {
      test('sends base OSC command', () async {
        await service.setCustomProfile(
          const ColorProfile(space: ColorSpace.sRGB),
        );
        verify(
          () => mockSession.writeRaw('\x1b]10;profile=custom\x1b\\\\'),
        ).called(1);
      });

      test('includes red chromaticity', () async {
        await service.setCustomProfile(
          const ColorProfile(space: ColorSpace.sRGB, redX: 0.64, redY: 0.33),
        );
        verify(
          () => mockSession.writeRaw(any(that: contains(';r=0.64,0.33'))),
        ).called(1);
      });

      test('includes green chromaticity', () async {
        await service.setCustomProfile(
          const ColorProfile(space: ColorSpace.sRGB, greenX: 0.3, greenY: 0.6),
        );
        verify(
          () => mockSession.writeRaw(any(that: contains(';g=0.3,0.6'))),
        ).called(1);
      });

      test('includes blue chromaticity', () async {
        await service.setCustomProfile(
          const ColorProfile(space: ColorSpace.sRGB, blueX: 0.15, blueY: 0.06),
        );
        verify(
          () => mockSession.writeRaw(any(that: contains(';b=0.15,0.06'))),
        ).called(1);
      });

      test('includes white point', () async {
        await service.setCustomProfile(
          const ColorProfile(
            space: ColorSpace.sRGB,
            whiteX: 0.3127,
            whiteY: 0.329,
          ),
        );
        verify(
          () => mockSession.writeRaw(any(that: contains(';w=0.3127,0.329'))),
        ).called(1);
      });

      test('includes gamma', () async {
        await service.setCustomProfile(
          const ColorProfile(space: ColorSpace.sRGB, gamma: 2.2),
        );
        verify(
          () => mockSession.writeRaw(any(that: contains(';gamma=2.2'))),
        ).called(1);
      });

      test('updates current profile', () async {
        const profile = ColorProfile(space: ColorSpace.displayP3);
        await service.setCustomProfile(profile);
        expect(service.currentProfile.space, ColorSpace.displayP3);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setCustomProfile(
            const ColorProfile(space: ColorSpace.sRGB),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setForegroundColor', () {
      test('sends CSI 38:2 with converted values', () async {
        await service.setForegroundColor(0.5, 0.3, 0.8);
        // 0.5 * 65535 = 32767.5 ≈ 32768
        // 0.3 * 65535 = 19660.5 ≈ 19661
        // 0.8 * 65535 = 52428.0
        verify(
          () => mockSession.writeRaw('\x1b[38:2:32768:19661:52428m'),
        ).called(1);
      });

      test('handles 0.0 values', () async {
        await service.setForegroundColor(0.0, 0.0, 0.0);
        verify(() => mockSession.writeRaw('\x1b[38:2:0:0:0m')).called(1);
      });

      test('handles 1.0 values', () async {
        await service.setForegroundColor(1.0, 1.0, 1.0);
        verify(
          () => mockSession.writeRaw('\x1b[38:2:65535:65535:65535m'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setForegroundColor(0.5, 0.5, 0.5),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setBackgroundColor', () {
      test('sends CSI 48:2 with converted values', () async {
        await service.setBackgroundColor(0.2, 0.5, 0.9);
        // 0.2 * 65535 = 13107
        // 0.5 * 65535 = 32767.5 ≈ 32768
        // 0.9 * 65535 = 58981.5 ≈ 58982
        verify(
          () => mockSession.writeRaw('\x1b[48:2:13107:32768:58982m'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setBackgroundColor(0.5, 0.5, 0.5),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setCursorColor', () {
      test('sends OSC 12 command', () async {
        await service.setCursorColor(0.5, 0.0, 1.0);
        // 0.5 * 65535 ≈ 32768 → rgb:128/0/0/0/255/255 → (32768 ~/ 256=128, 32768 % 256=0, 0, 0, 65535 ~/ 256=255, 65535 % 256=255)
        verify(
          () => mockSession.writeRaw(
            '\x1b]12;color=rgb:128/0/0/0/255/255\x1b\\\\',
          ),
        ).called(1);
      });

      test('handles zero values', () async {
        await service.setCursorColor(0.0, 0.0, 0.0);
        verify(
          () => mockSession.writeRaw('\x1b]12;color=rgb:0/0/0/0/0/0\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setCursorColor(0.5, 0.5, 0.5),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setSelectionBackgroundColor', () {
      test('sends OSC 131 command', () async {
        await service.setSelectionBackgroundColor(0.3, 0.6, 0.1);
        // 0.3 * 65535 ≈ 19661 → rgb:76/205/153/153/25/230
        // 19661 ~/ 256 = 76, 19661 % 256 = 205
        // 0.6 * 65535 = 39321 → 39321 ~/ 256 = 153, 39321 % 256 = 153
        // 0.1 * 65535 = 6553.5 ≈ 6554 → 6554 ~/ 256 = 25, 6554 % 256 = 154

        // Let me recalculate:
        // (0.3 * 65535).round() = 19661
        // 19661 ~/ 256 = 76
        // 19661 % 256 = 205
        // (0.6 * 65535).round() = 39321
        // 39321 ~/ 256 = 153
        // 39321 % 256 = 153
        // (0.1 * 65535).round() = 6554
        // 6554 ~/ 256 = 25
        // 6554 % 256 = 154

        verify(
          () => mockSession.writeRaw(
            '\x1b]131;color=rgb:76/205/153/153/25/154\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setSelectionBackgroundColor(0.5, 0.5, 0.5),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setSelectionForegroundColor', () {
      test('sends OSC 132 command', () async {
        await service.setSelectionForegroundColor(1.0, 1.0, 1.0);
        verify(
          () => mockSession.writeRaw(
            '\x1b]132;color=rgb:255/255/255/255/255/255\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(
          () => nullService.setSelectionForegroundColor(0.5, 0.5, 0.5),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('resetColors', () {
      test('sends CSI 0m and OSC 10 reset', () async {
        await service.resetColors();
        verify(() => mockSession.writeRaw('\x1b[0m')).called(1);
        verify(() => mockSession.writeRaw('\x1b]10;\x1b\\\\')).called(1);
      });

      test('resets profile to sRGB', () async {
        await service.setColorSpace(ColorSpace.displayP3);
        await service.resetColors();
        expect(service.currentProfile.space, ColorSpace.sRGB);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(() => nullService.resetColors(), throwsA(isA<Exception>()));
      });
    });

    group('queryColorSpace', () {
      test('sends OSC 10;? command', () async {
        await service.queryColorSpace();
        verify(() => mockSession.writeRaw('\x1b]10;?\x1b\\\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyWideGamutService();
        expect(() => nullService.queryColorSpace(), throwsA(isA<Exception>()));
      });
    });
  });
}
