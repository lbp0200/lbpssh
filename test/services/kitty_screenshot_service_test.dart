import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_screenshot_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyScreenshotService', () {
    late _MockTerminalSession mockSession;
    late KittyScreenshotService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyScreenshotService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyScreenshotService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('captureScreen', () {
      test('sends png format by default', () async {
        await service.captureScreen();
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:area=screen:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      for (final entry in [
        (format: ScreenshotFormat.png, expected: 'png'),
        (format: ScreenshotFormat.jpeg, expected: 'jpg'),
        (format: ScreenshotFormat.svg, expected: 'svg'),
      ]) {
        test('sends ${entry.format.name} format', () async {
          await service.captureScreen(format: entry.format);
          verify(
            () => mockSession.writeRaw(
              '\x1b]20;screenshot:area=screen:format=${entry.expected}\x1b\\\\',
            ),
          ).called(1);
        });
      }

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(() => nullService.captureScreen(), throwsA(isA<Exception>()));
      });
    });

    group('captureWindow', () {
      test('sends window area', () async {
        await service.captureWindow();
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:area=window:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      for (final entry in [
        (format: ScreenshotFormat.png, expected: 'png'),
        (format: ScreenshotFormat.jpeg, expected: 'jpg'),
        (format: ScreenshotFormat.svg, expected: 'svg'),
      ]) {
        test('sends ${entry.format.name} format', () async {
          await service.captureWindow(format: entry.format);
          verify(
            () => mockSession.writeRaw(
              '\x1b]20;screenshot:area=window:format=${entry.expected}\x1b\\\\',
            ),
          ).called(1);
        });
      }

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(() => nullService.captureWindow(), throwsA(isA<Exception>()));
      });
    });

    group('captureSelection', () {
      test('sends selection area', () async {
        await service.captureSelection();
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:area=selection:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      for (final entry in [
        (format: ScreenshotFormat.jpeg, expected: 'jpg'),
        (format: ScreenshotFormat.svg, expected: 'svg'),
      ]) {
        test('sends ${entry.format.name} format', () async {
          await service.captureSelection(format: entry.format);
          verify(
            () => mockSession.writeRaw(
              '\x1b]20;screenshot:area=selection:format=${entry.expected}\x1b\\\\',
            ),
          ).called(1);
        });
      }
    });

    group('captureArea', () {
      test('sends rect area with coordinates', () async {
        await service.captureArea(10, 20, 800, 600);
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:area=rect:x=10:y=20:w=800:h=600:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      for (final entry in [
        (format: ScreenshotFormat.jpeg, expected: 'jpg'),
        (format: ScreenshotFormat.svg, expected: 'svg'),
      ]) {
        test('sends ${entry.format.name} format', () async {
          await service.captureArea(0, 0, 100, 100, format: entry.format);
          verify(
            () => mockSession.writeRaw(
              '\x1b]20;screenshot:area=rect:x=0:y=0:w=100:h=100:format=${entry.expected}\x1b\\\\',
            ),
          ).called(1);
        });
      }

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(
          () => nullService.captureArea(0, 0, 100, 100),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('saveScreenshot', () {
      test('saves to file with screen area and png by default', () async {
        await service.saveScreenshot('/tmp/shot.png');
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:save:/tmp/shot.png:area=screen:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      test('saves with window area', () async {
        await service.saveScreenshot(
          '/tmp/shot.png',
          area: ScreenshotArea.window,
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:save:/tmp/shot.png:area=window:format=png\x1b\\\\',
          ),
        ).called(1);
      });

      test('saves with jpeg format', () async {
        await service.saveScreenshot(
          '/tmp/shot.jpg',
          format: ScreenshotFormat.jpeg,
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:save:/tmp/shot.jpg:area=screen:format=jpg\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(
          () => nullService.saveScreenshot('/tmp/x.png'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('copyToClipboard', () {
      test('copies screen by default', () async {
        await service.copyToClipboard();
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:clipboard:area=screen\x1b\\\\',
          ),
        ).called(1);
      });

      test('copies window area', () async {
        await service.copyToClipboard(area: ScreenshotArea.window);
        verify(
          () => mockSession.writeRaw(
            '\x1b]20;screenshot:clipboard:area=window\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(() => nullService.copyToClipboard(), throwsA(isA<Exception>()));
      });
    });

    group('startInteractiveCapture', () {
      test('sends interactive command', () async {
        await service.startInteractiveCapture();
        verify(
          () => mockSession.writeRaw('\x1b]20;screenshot:interactive\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(
          () => nullService.startInteractiveCapture(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('cancelCapture', () {
      test('sends ESC escape character', () async {
        await service.cancelCapture();
        verify(() => mockSession.writeRaw('\x1b')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(() => nullService.cancelCapture(), throwsA(isA<Exception>()));
      });
    });

    group('setQuality', () {
      test('sends quality command with valid values', () async {
        await service.setQuality(85);
        verify(
          () => mockSession.writeRaw('\x1b]20;screenshot:quality=85\x1b\\\\'),
        ).called(1);
      });

      test('throws on quality below 1', () async {
        expect(() => service.setQuality(0), throwsA(isA<Exception>()));
      });

      test('throws on quality above 100', () async {
        expect(() => service.setQuality(101), throwsA(isA<Exception>()));
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(() => nullService.setQuality(50), throwsA(isA<Exception>()));
      });
    });

    group('setTransparentBackground', () {
      test('sends transparent=1 when true', () async {
        await service.setTransparentBackground(true);
        verify(
          () =>
              mockSession.writeRaw('\x1b]20;screenshot:transparent=1\x1b\\\\'),
        ).called(1);
      });

      test('sends transparent=0 when false', () async {
        await service.setTransparentBackground(false);
        verify(
          () =>
              mockSession.writeRaw('\x1b]20;screenshot:transparent=0\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyScreenshotService();
        expect(
          () => nullService.setTransparentBackground(true),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('handleScreenshotResponse', () {
      test('invokes callback with decoded data', () {
        Uint8List? captured;
        service.onScreenshot = (data) => captured = data;

        // "TWFu" is "Man" in base64
        service.handleScreenshotResponse('TWFu');

        expect(captured, isNotNull);
        expect(captured!.length, 3);
        expect(captured![0], 77); // 'M'
        expect(captured![1], 97); // 'a'
        expect(captured![2], 110); // 'n'
      });

      test('strips data: prefix before decoding', () {
        Uint8List? captured;
        service.onScreenshot = (data) => captured = data;

        service.handleScreenshotResponse('data:image/png;base64,TWFu');

        expect(captured, isNotNull);
        expect(captured!.length, 3);
      });

      test('does not throw when callback is null', () {
        expect(() => service.handleScreenshotResponse('TWFu'), returnsNormally);
      });
    });

    group('ScreenshotFormat enum', () {
      test('has all expected values', () {
        expect(ScreenshotFormat.values.length, 3);
      });
    });

    group('ScreenshotArea enum', () {
      test('has all expected values', () {
        expect(ScreenshotArea.values.length, 3);
      });
    });
  });
}
