import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_layout_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyLayoutService', () {
    late _MockTerminalSession mockSession;
    late KittyLayoutService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyLayoutService(session: mockSession);
    });

    group('LayoutType enum', () {
      test(
        'has all expected values (grid, stack, horizontal, vertical, split)',
        () {
          expect(LayoutType.values.length, 5);
          expect(LayoutType.grid, LayoutType.grid);
          expect(LayoutType.stack, LayoutType.stack);
          expect(LayoutType.horizontal, LayoutType.horizontal);
          expect(LayoutType.vertical, LayoutType.vertical);
          expect(LayoutType.split, LayoutType.split);
        },
      );
    });

    group('WindowInfo', () {
      test('creates with required fields', () {
        const info = WindowInfo(id: '1', isActive: true);
        expect(info.id, '1');
        expect(info.isActive, isTrue);
        expect(info.title, isNull);
      });

      test('creates with all fields', () {
        const info = WindowInfo(
          id: '2',
          title: 'test',
          width: 80,
          height: 24,
          x: 10,
          y: 5,
        );
        expect(info.title, 'test');
        expect(info.width, 80);
        expect(info.height, 24);
        expect(info.x, 10);
        expect(info.y, 5);
      });
    });

    group('LayoutConfig', () {
      test('creates with required fields', () {
        const config = LayoutConfig(type: LayoutType.grid);
        expect(config.type, LayoutType.grid);
        expect(config.width, isNull);
        expect(config.fraction, isNull);
      });

      test('creates with all fields', () {
        const config = LayoutConfig(
          type: LayoutType.horizontal,
          width: 100,
          height: 50,
          x: 0,
          y: 0,
          fraction: 0.5,
        );
        expect(config.width, 100);
        expect(config.height, 50);
        expect(config.fraction, 0.5);
      });
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyLayoutService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('currentLayout', () {
      test('defaults to grid', () {
        expect(service.currentLayout.type, LayoutType.grid);
      });
    });

    group('windows', () {
      test('returns unmodifiable empty list by default', () {
        expect(service.windows, isEmpty);
        expect(
          () => service.windows.add(const WindowInfo(id: '1')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('setGridLayout', () {
      test('sends OSC 20 with grid layout', () async {
        await service.setGridLayout(3, 2);
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=grid:3:2\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.type, LayoutType.grid);
        expect(service.currentLayout.width, 3);
        expect(service.currentLayout.height, 2);
      });

      test('throws when session is null', () async {
        final nullService = KittyLayoutService();
        expect(
          () => nullService.setGridLayout(1, 1),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setStackLayout', () {
      test('sends OSC 20 with stack layout', () async {
        await service.setStackLayout();
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=stack\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.type, LayoutType.stack);
      });

      test('throws when session is null', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.setStackLayout(), throwsA(isA<Exception>()));
      });
    });

    group('setHorizontalLayout', () {
      test('sends OSC 20 with horizontal layout', () async {
        await service.setHorizontalLayout();
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=horizontal\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.type, LayoutType.horizontal);
      });

      test('includes fraction when provided', () async {
        await service.setHorizontalLayout(fraction: 0.33);
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=horizontal:0.33\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.fraction, 0.33);
      });

      test('throws when session is null', () async {
        final nullService = KittyLayoutService();
        expect(
          () => nullService.setHorizontalLayout(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setVerticalLayout', () {
      test('sends OSC 20 with vertical layout', () async {
        await service.setVerticalLayout();
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=vertical\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.type, LayoutType.vertical);
      });

      test('includes fraction when provided', () async {
        await service.setVerticalLayout(fraction: 0.33);
        verify(
          () => mockSession.writeRaw('\x1b]20;layout=vertical:0.33\x1b\\\\'),
        ).called(1);
        expect(service.currentLayout.fraction, 0.33);
      });
    });

    group('createSplit', () {
      test('sends OSC 20 with split direction', () async {
        await service.createSplit('h');
        verify(() => mockSession.writeRaw('\x1b]20;split:h\x1b\\\\')).called(1);
        expect(service.currentLayout.type, LayoutType.split);
      });

      test('includes size when provided', () async {
        await service.createSplit('v', size: 50);
        verify(
          () => mockSession.writeRaw('\x1b]20;split:v:50\x1b\\\\'),
        ).called(1);
      });
    });

    group('closeSplit', () {
      test('sends OSC 20 split:close', () async {
        await service.closeSplit();
        verify(
          () => mockSession.writeRaw('\x1b]20;split:close\x1b\\\\'),
        ).called(1);
      });
    });

    group('nextWindow', () {
      test('sends OSC 20 window:next', () async {
        await service.nextWindow();
        verify(
          () => mockSession.writeRaw('\x1b]20;window:next\x1b\\\\'),
        ).called(1);
      });
    });

    group('previousWindow', () {
      test('sends OSC 20 window:prev', () async {
        await service.previousWindow();
        verify(
          () => mockSession.writeRaw('\x1b]20;window:prev\x1b\\\\'),
        ).called(1);
      });
    });

    group('focusWindow', () {
      test('sends OSC 20 window:focus with id', () async {
        await service.focusWindow('w1');
        verify(
          () => mockSession.writeRaw('\x1b]20;window:focus:w1\x1b\\\\'),
        ).called(1);
      });
    });

    group('resizeWindow', () {
      test('sends OSC 20 window:resize', () async {
        await service.resizeWindow(120, 40);
        verify(
          () => mockSession.writeRaw('\x1b]20;window:resize:120:40\x1b\\\\'),
        ).called(1);
      });
    });

    group('moveWindow', () {
      test('sends OSC 20 window:move', () async {
        await service.moveWindow(100, 200);
        verify(
          () => mockSession.writeRaw('\x1b]20;window:move:100:200\x1b\\\\'),
        ).called(1);
      });
    });

    group('maximizeWindow', () {
      test('sends OSC 20 window:maximize', () async {
        await service.maximizeWindow();
        verify(
          () => mockSession.writeRaw('\x1b]20;window:maximize\x1b\\\\'),
        ).called(1);
      });
    });

    group('restoreWindow', () {
      test('sends OSC 20 window:restore', () async {
        await service.restoreWindow();
        verify(
          () => mockSession.writeRaw('\x1b]20;window:restore\x1b\\\\'),
        ).called(1);
      });
    });

    group('queryWindows', () {
      test('sends OSC 20 windows:?', () async {
        await service.queryWindows();
        verify(
          () => mockSession.writeRaw('\x1b]20;windows:?\x1b\\\\'),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.queryWindows(), throwsA(isA<Exception>()));
      });
    });

    group('queryLayout', () {
      test('sends OSC 20 layout:?', () async {
        await service.queryLayout();
        verify(
          () => mockSession.writeRaw('\x1b]20;layout:?\x1b\\\\'),
        ).called(1);
      });
    });

    group('throws when session is null', () {
      test('closeSplit', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.closeSplit(), throwsA(isA<Exception>()));
      });

      test('nextWindow', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.nextWindow(), throwsA(isA<Exception>()));
      });

      test('focusWindow', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.focusWindow('w'), throwsA(isA<Exception>()));
      });

      test('resizeWindow', () async {
        final nullService = KittyLayoutService();
        expect(
          () => nullService.resizeWindow(80, 24),
          throwsA(isA<Exception>()),
        );
      });

      test('queryLayout', () async {
        final nullService = KittyLayoutService();
        expect(() => nullService.queryLayout(), throwsA(isA<Exception>()));
      });
    });

    group('handleLayoutResponse', () {
      test('parses grid response', () {
        service.handleLayoutResponse('20;layout=grid');
        expect(service.currentLayout.type, LayoutType.grid);
      });

      test('parses stack response', () {
        service.handleLayoutResponse('20;layout=stack');
        expect(service.currentLayout.type, LayoutType.stack);
      });

      test('parses horizontal response', () {
        service.handleLayoutResponse('20;layout=horizontal');
        expect(service.currentLayout.type, LayoutType.horizontal);
      });

      test('parses vertical response', () {
        service.handleLayoutResponse('20;layout=vertical');
        expect(service.currentLayout.type, LayoutType.vertical);
      });

      test('ignores response without 20; prefix', () {
        service.handleLayoutResponse('garbage');
        expect(service.currentLayout.type, LayoutType.grid);
      });

      test('ignores malformed response without error', () {
        expect(() => service.handleLayoutResponse('20;;;'), returnsNormally);
      });
    });
  });
}
