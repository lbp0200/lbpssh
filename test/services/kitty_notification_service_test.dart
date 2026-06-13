import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_notification_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyNotificationService', () {
    late _MockTerminalSession mockSession;
    late KittyNotificationService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyNotificationService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyNotificationService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('showNotification', () {
      test('writes OSC 99 sequence when called', () {
        service.showNotification(id: 'n1', title: 'T', body: 'B');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes id, title, body in OSC sequence', () {
        service.showNotification(id: 'n1', title: 'Hello', body: 'World');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('includes progress when provided', () {
        service.showNotification(id: 'n1', title: 'T', body: 'B', progress: 50);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('omits p= when progress is null', () {
        service.showNotification(id: 'n1', title: 'T', body: 'B');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () {
        final nullService = KittyNotificationService();
        expect(
          () => nullService.showNotification(id: 'id', title: 't', body: 'b'),
          throwsA(isA<Exception>()),
        );
      });

      test('escapes semicolons in title', () {
        service.showNotification(id: 'n1', title: 'A;B', body: 'C');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('escapes colons in title', () {
        service.showNotification(id: 'n1', title: 'A:B', body: 'C');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('escapes backslashes in title', () {
        service.showNotification(id: 'n1', title: r'A\B', body: 'C');
        verify(() => mockSession.writeRaw(any())).called(1);
      });
    });

    group('updateProgress', () {
      test('writes OSC 99 sequence when called', () {
        service.updateProgress(id: 'n1', progress: 75);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () {
        final nullService = KittyNotificationService();
        expect(
          () => nullService.updateProgress(id: 'id', progress: 50),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('closeNotification', () {
      test('writes OSC 99 sequence when called', () {
        service.closeNotification('n1');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () {
        final nullService = KittyNotificationService();
        expect(
          () => nullService.closeNotification('id'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('queryNotification', () {
      test('writes OSC 99 sequence when called', () {
        service.queryNotification('n1');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('throws when session is null', () {
        final nullService = KittyNotificationService();
        expect(
          () => nullService.queryNotification('id'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('handleNotificationResponse', () {
      test('calls onClick for activate action', () {
        String? receivedId;
        service.onClick = (id) => receivedId = id;
        service.handleNotificationResponse('i=n1;p=activate');
        expect(receivedId, 'n1');
      });

      test('calls onClick for clicked action', () {
        String? receivedId;
        service.onClick = (id) => receivedId = id;
        service.handleNotificationResponse('i=n1;p=clicked');
        expect(receivedId, 'n1');
      });

      test('calls onClose for close action', () {
        String? receivedId;
        service.onClose = (id) => receivedId = id;
        service.handleNotificationResponse('i=n1;p=close');
        expect(receivedId, 'n1');
      });

      test('calls onProgress for progress action', () {
        int? receivedProgress;
        service.onProgress = (_, progress) => receivedProgress = progress;
        service.handleNotificationResponse('i=n1;p=progress;75');
        expect(receivedProgress, 75);
      });

      test('does nothing for unknown action', () {
        var called = false;
        service.onClick = (_) => called = true;
        service.onClose = (_) => called = true;
        service.onProgress = (_, _) => called = true;
        service.handleNotificationResponse('i=n1;p=unknown');
        expect(called, isFalse);
      });

      test('does not throw for unparseable response', () {
        expect(
          () => service.handleNotificationResponse('garbage'),
          returnsNormally,
        );
      });

      test('does not throw for empty response', () {
        expect(() => service.handleNotificationResponse(''), returnsNormally);
      });

      test('parses progress 0', () {
        int? receivedProgress;
        service.onProgress = (_, progress) => receivedProgress = progress;
        service.handleNotificationResponse('i=n1;p=progress;0');
        expect(receivedProgress, 0);
      });

      test('parses progress 100', () {
        int? receivedProgress;
        service.onProgress = (_, progress) => receivedProgress = progress;
        service.handleNotificationResponse('i=n1;p=progress;100');
        expect(receivedProgress, 100);
      });
    });

    group('OSC 99 sequence format', () {
      test('showNotification writes to session', () {
        service.showNotification(id: 'test-id', title: 'Test', body: 'Body');
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('updateProgress writes to session', () {
        service.updateProgress(id: 'id', progress: 50);
        verify(() => mockSession.writeRaw(any())).called(1);
      });

      test('closeNotification writes to session', () {
        service.closeNotification('id');
        verify(() => mockSession.writeRaw(any())).called(1);
      });
    });
  });
}
