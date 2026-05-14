import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_graphics_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyGraphicsService', () {
    late _MockTerminalSession mockSession;
    late KittyGraphicsService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyGraphicsService(session: mockSession);
    });

    group('ImagePlacement enum', () {
      test('has all expected values', () {
        expect(ImagePlacement.values.length, 3);
        expect(ImagePlacement.any, ImagePlacement.any);
        expect(ImagePlacement.cursor, ImagePlacement.cursor);
        expect(ImagePlacement.absolute, ImagePlacement.absolute);
      });
    });

    group('GraphicsImage', () {
      test('creates with required fields', () {
        final img = GraphicsImage(id: 1);
        expect(img.id, 1);
        expect(img.path, isNull);
        expect(img.toBuffer, isFalse);
      });

      test('creates with all fields', () {
        final img = GraphicsImage(
          id: 2,
          path: '/tmp/test.png',
          width: 100,
          height: 50,
          x: 10,
          y: 20,
          toBuffer: true,
        );
        expect(img.path, '/tmp/test.png');
        expect(img.width, 100);
        expect(img.height, 50);
        expect(img.x, 10);
        expect(img.y, 20);
        expect(img.toBuffer, isTrue);
      });
    });

    group('GraphicsTransferProgress', () {
      test('creates with required fields', () {
        final progress = GraphicsTransferProgress(
          imageId: 1,
          transmittedBytes: 500,
          totalBytes: 1000,
        );
        expect(progress.imageId, 1);
        expect(progress.transmittedBytes, 500);
        expect(progress.totalBytes, 1000);
      });
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyGraphicsService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('loadImage', () {
      test('sends OSC 71 with base64 encoded image', () async {
        final data = Uint8List.fromList([0x48, 0x65, 0x6c]); // "Hel"
        final imageId = await service.loadImage(data);
        expect(imageId, 1);
        verify(
          () => mockSession.writeRaw('\x1b]71;a=i;id=1;d=SGVs\x1b\\'),
        ).called(1);
      });

      test('includes placement parameter', () async {
        final data = Uint8List.fromList([0x41]);
        await service.loadImage(data, placement: ImagePlacement.cursor);
        verify(
          () => mockSession.writeRaw('\x1b]71;a=i;id=1;p=cursor;d=QQ==\x1b\\'),
        ).called(1);
      });

      test('includes width and height when provided', () async {
        final data = Uint8List.fromList([0x41]);
        await service.loadImage(data, width: 100, height: 50);
        verify(
          () =>
              mockSession.writeRaw('\x1b]71;a=i;id=1;w=100;h=50;d=QQ==\x1b\\'),
        ).called(1);
      });

      test('includes x and y when provided', () async {
        final data = Uint8List.fromList([0x41]);
        await service.loadImage(data, x: 10, y: 20);
        verify(
          () => mockSession.writeRaw('\x1b]71;a=i;id=1;x=10;y=20;d=QQ==\x1b\\'),
        ).called(1);
      });

      test('returns incrementing image IDs', () async {
        final data = Uint8List.fromList([0x41]);
        final id1 = await service.loadImage(data);
        final id2 = await service.loadImage(data);
        expect(id1, 1);
        expect(id2, 2);
      });

      test('throws when session is null', () async {
        final nullService = KittyGraphicsService();
        expect(
          () => nullService.loadImage(Uint8List(0)),
          throwsA(isA<Exception>()),
        );
      });

      test('accepts onProgress callback', () async {
        bool called = false;
        final data = Uint8List.fromList([0x41]);
        await service.loadImage(data, onProgress: (p) => called = true);
        expect(called, isFalse); // callback not invoked synchronously
      });
    });

    group('loadImageFromPath', () {
      test('sends OSC 71 with file path', () async {
        final imageId = await service.loadImageFromPath('/tmp/test.png');
        expect(imageId, 1);
        verify(
          () => mockSession.writeRaw(
            '\x1b]71;a=i;id=1;f=L3RtcC90ZXN0LnBuZw==\x1b\\',
          ),
        ).called(1);
      });

      test('includes optional parameters', () async {
        await service.loadImageFromPath(
          '/tmp/test.png',
          width: 200,
          height: 100,
          placement: ImagePlacement.absolute,
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]71;a=i;id=1;w=200;h=100;p=absolute;f=L3RtcC90ZXN0LnBuZw==\x1b\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyGraphicsService();
        expect(
          () => nullService.loadImageFromPath('/tmp/x.png'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteImage', () {
      test('sends OSC 71 a=d with image id', () async {
        await service.deleteImage(5);
        verify(() => mockSession.writeRaw('\x1b]71;a=d;id=5\x1b\\')).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyGraphicsService();
        expect(() => nullService.deleteImage(1), throwsA(isA<Exception>()));
      });
    });

    group('deleteAllImages', () {
      test('sends OSC 71 a=d;a=*', () async {
        await service.deleteAllImages();
        verify(() => mockSession.writeRaw('\x1b]71;a=d;a=*\x1b\\')).called(1);
      });
    });

    group('queryImageLocation', () {
      test('sends OSC 71 a=q with image id', () async {
        await service.queryImageLocation(3);
        verify(() => mockSession.writeRaw('\x1b]71;a=q;id=3\x1b\\')).called(1);
      });
    });

    group('dumpImage', () {
      test('sends OSC 71 a=t with id and file path', () async {
        await service.dumpImage(2, '/tmp/output.png');
        verify(
          () => mockSession.writeRaw(
            '\x1b]71;a=t;id=2;f=L3RtcC9vdXRwdXQucG5n\x1b\\',
          ),
        ).called(1);
      });
    });

    group('moveImage', () {
      test('sends OSC 71 a=m with id, x, y', () async {
        await service.moveImage(1, 50, 100);
        verify(
          () => mockSession.writeRaw('\x1b]71;a=m;id=1;x=50;y=100\x1b\\'),
        ).called(1);
      });
    });

    group('listImages', () {
      test('sends OSC 71 a=l', () async {
        await service.listImages();
        verify(() => mockSession.writeRaw('\x1b]71;a=l\x1b\\')).called(1);
      });
    });

    group('throws when session is null', () {
      test('deleteAllImages', () async {
        final nullService = KittyGraphicsService();
        expect(() => nullService.deleteAllImages(), throwsA(isA<Exception>()));
      });

      test('queryImageLocation', () async {
        final nullService = KittyGraphicsService();
        expect(
          () => nullService.queryImageLocation(1),
          throwsA(isA<Exception>()),
        );
      });

      test('dumpImage', () async {
        final nullService = KittyGraphicsService();
        expect(
          () => nullService.dumpImage(1, '/tmp/x.png'),
          throwsA(isA<Exception>()),
        );
      });

      test('moveImage', () async {
        final nullService = KittyGraphicsService();
        expect(() => nullService.moveImage(1, 0, 0), throwsA(isA<Exception>()));
      });

      test('listImages', () async {
        final nullService = KittyGraphicsService();
        expect(() => nullService.listImages(), throwsA(isA<Exception>()));
      });
    });
  });
}
