import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/app_config_provider_riverpod.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';

class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late MockAppConfigService mockService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(TerminalConfig.defaultConfig);
  });

  setUp(() {
    mockService = MockAppConfigService();
    when(() => mockService.terminal).thenReturn(TerminalConfig.defaultConfig);
  });

  tearDown(() {
    container.dispose();
  });

  test('should load initial config', () {
    container = ProviderContainer(
      overrides: [
        appConfigServiceProvider.overrideWithValue(mockService),
      ],
    );

    final config = container.read(terminalConfigProvider);
    expect(config.fontSize, 17);
  });

  test('should update config', () async {
    container = ProviderContainer(
      overrides: [
        appConfigServiceProvider.overrideWithValue(mockService),
      ],
    );

    when(() => mockService.saveTerminalConfig(any())).thenAnswer((_) async {});

    final notifier = container.read(terminalConfigProvider.notifier);
    await notifier.updateFontSize(20);

    final config = container.read(terminalConfigProvider);
    expect(config.fontSize, 20);
    verify(() => mockService.saveTerminalConfig(any())).called(1);
  });
}
