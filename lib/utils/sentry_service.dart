import 'package:sentry/sentry.dart';

class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _isInitialized = false;

  Future<void> init({required String dsn}) async {
    if (_isInitialized || dsn.isEmpty) return;
    await Sentry.init((options) {
      options.dsn = dsn;
      options.environment = 'production';
    });
    _isInitialized = true;
  }

  Future<void> captureException(Object e, {StackTrace? stackTrace}) async {
    if (!_isInitialized) return;
    await Sentry.captureException(e, stackTrace: stackTrace);
  }
}
