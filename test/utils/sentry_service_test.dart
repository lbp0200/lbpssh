import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/sentry_service.dart';

void main() {
  group('SentryService', () {
    test('is a singleton', () {
      final instance1 = SentryService();
      final instance2 = SentryService();
      expect(instance1, same(instance2));
    });

    test('init with empty DSN does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      // Should complete without throwing
    });

    test('captureException before init does not throw', () async {
      final service = SentryService();
      await service.captureException(Exception('test error'));
      // Should complete without throwing
    });

    test('double init with empty DSN does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      await service.init(dsn: '');
      // Should complete without throwing
    });

    test('captureException on uninitialised service does not throw', () async {
      final service = SentryService();
      await service.init(dsn: '');
      await service.captureException(Exception('after empty init'));
      // Should complete without throwing
    });
  });
}
