import 'dart:developer' as developer;

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  void logStep(String label) {
    developer.log('$label completed', name: 'Performance');
  }

  void trackEvent(String name, {Map<String, dynamic>? data}) {
    developer.log('$name: $data', name: 'Analytics');
  }
}
