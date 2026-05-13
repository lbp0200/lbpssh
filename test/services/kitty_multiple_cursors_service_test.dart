import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_multiple_cursors_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyMultipleCursorsService', () {
    late _MockTerminalSession mockSession;
    late KittyMultipleCursorsService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyMultipleCursorsService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyMultipleCursorsService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('VirtualCursor', () {
      test('stores cursor properties', () {
        const cursor = VirtualCursor(id: 'c1', x: 5, y: 10);
        expect(cursor.id, 'c1');
        expect(cursor.x, 5);
        expect(cursor.y, 10);
        expect(cursor.selected, isFalse);
      });

      test('accepts selected parameter', () {
        const cursor = VirtualCursor(id: 'c2', x: 0, y: 0, selected: true);
        expect(cursor.selected, isTrue);
      });
    });

    group('insertCursor', () {
      test('sends insert cursor command', () async {
        await service.insertCursor(5, 10);
        verify(() => mockSession.writeRaw(
          any(that: startsWith('\x1b[6>cursor;id=c')),
        )).called(1);
      });

      test('includes coordinates in command', () async {
        await service.insertCursor(5, 10);
        verify(() => mockSession.writeRaw(
          any(that: contains(';x=5;y=10')),
        )).called(1);
      });

      test('includes select flag when select is true', () async {
        await service.insertCursor(5, 10, select: true);
        verify(() => mockSession.writeRaw(
          any(that: contains(';s=1')),
        )).called(1);
      });

      test('omits select flag when select is false', () async {
        await service.insertCursor(5, 10);
        verify(() => mockSession.writeRaw(
          any(that: isNot(contains(';s=1'))),
        )).called(1);
      });

      test('returns a cursor id', () async {
        final id = await service.insertCursor(0, 0);
        expect(id, startsWith('c'));
      });

      test('adds cursor to local list', () async {
        final id = await service.insertCursor(5, 10);
        expect(service.cursors.length, 1);
        expect(service.cursors.first.id, id);
        expect(service.cursors.first.x, 5);
        expect(service.cursors.first.y, 10);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.insertCursor(0, 0),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('moveCursor', () {
      test('sends move cursor command', () async {
        await service.insertCursor(0, 0);
        final id = service.cursors.first.id;
        await service.moveCursor(id, 10, 20);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;x=10;y=20\x1b\\\\',
        )).called(1);
      });

      test('updates local cursor position', () async {
        final id = await service.insertCursor(0, 0);
        await service.moveCursor(id, 10, 20);
        final cursor = service.getCursor(id);
        expect(cursor!.x, 10);
        expect(cursor.y, 20);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.moveCursor('c1', 0, 0),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('selectCursor', () {
      test('sends select 1 command', () async {
        final id = await service.insertCursor(0, 0);
        await service.selectCursor(id, true);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;s=1\x1b\\\\',
        )).called(1);
      });

      test('sends select 0 command', () async {
        final id = await service.insertCursor(0, 0, select: true);
        await service.selectCursor(id, false);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;s=0\x1b\\\\',
        )).called(1);
      });

      test('updates local cursor selection state', () async {
        final id = await service.insertCursor(0, 0);
        await service.selectCursor(id, true);
        expect(service.getCursor(id)!.selected, isTrue);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.selectCursor('c1', true),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteCursor', () {
      test('sends delete cursor command', () async {
        final id = await service.insertCursor(0, 0);
        await service.deleteCursor(id);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;d=1\x1b\\\\',
        )).called(1);
      });

      test('removes cursor from local list', () async {
        final id1 = await service.insertCursor(0, 0);
        final id2 = await service.insertCursor(1, 1);
        await service.deleteCursor(id1);
        expect(service.cursors.length, 1);
        expect(service.cursors.first.id, id2);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.deleteCursor('c1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('clearAllCursors', () {
      test('sends clear all cursors command', () async {
        await service.clearAllCursors();
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;d=*\x1b\\\\',
        )).called(1);
      });

      test('clears local cursor list', () async {
        await service.insertCursor(0, 0);
        await service.insertCursor(1, 1);
        expect(service.cursors.length, 2);
        await service.clearAllCursors();
        expect(service.cursors, isEmpty);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.clearAllCursors(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getCursor', () {
      test('returns cursor by id', () async {
        final id = await service.insertCursor(5, 10);
        final cursor = service.getCursor(id);
        expect(cursor, isNotNull);
        expect(cursor!.x, 5);
        expect(cursor.y, 10);
      });

      test('returns null for unknown id', () {
        expect(service.getCursor('nonexistent'), isNull);
      });
    });

    group('activateCursor', () {
      test('sends activate cursor command', () async {
        final id = await service.insertCursor(0, 0);
        await service.activateCursor(id);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;a=1\x1b\\\\',
        )).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.activateCursor('c1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deactivateCursor', () {
      test('sends deactivate cursor command', () async {
        final id = await service.insertCursor(0, 0);
        await service.deactivateCursor(id);
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;a=0\x1b\\\\',
        )).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.deactivateCursor('c1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('setCursorShape', () {
      test('sends set shape command', () async {
        final id = await service.insertCursor(0, 0);
        await service.setCursorShape(id, 'bar');
        verify(() => mockSession.writeRaw(
          '\x1b[6>cursor;id=$id;shape=bar\x1b\\\\',
        )).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyMultipleCursorsService();
        expect(
          () => nullService.setCursorShape('c1', 'bar'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('handleResponse', () {
      test('adds new cursor from response', () {
        service.handleResponse('6>cursor;id=new1;x=3;y=7');
        expect(service.cursors.length, 1);
        expect(service.cursors.first.id, 'new1');
        expect(service.cursors.first.x, 3);
        expect(service.cursors.first.y, 7);
      });

      test('parses selection state from response', () async {
        final id = await service.insertCursor(0, 0);
        service.handleResponse('6>cursor;id=$id;x=5;y=5;s=1');
        expect(service.getCursor(id)!.selected, isTrue);
      });

      test('updates cursor coordinates from response', () async {
        final id = await service.insertCursor(0, 0);
        service.handleResponse('6>cursor;id=$id;x=20;y=30');
        final cursor = service.getCursor(id);
        expect(cursor!.x, 20);
        expect(cursor.y, 30);
      });

      test('ignores malformed response', () {
        expect(
          () => service.handleResponse('garbage'),
          returnsNormally,
        );
        expect(service.cursors, isEmpty);
      });

      test('ignores empty response', () {
        expect(
          () => service.handleResponse(''),
          returnsNormally,
        );
      });
    });

    group('cursors getter', () {
      test('returns unmodifiable list', () {
        expect(service.cursors, isA<List<VirtualCursor>>());
        expect(() => service.cursors.add(const VirtualCursor(id: '', x: 0, y: 0)),
          throwsA(isA<UnsupportedError>()));
      });
    });
  });
}
