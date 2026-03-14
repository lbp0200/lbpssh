import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/app_config_service.dart';
import '../../data/models/terminal_config.dart';

/// AppConfigService singleton provider
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService.getInstance();
});

/// Terminal configuration provider
final terminalConfigProvider =
    NotifierProvider<TerminalConfigNotifier, TerminalConfig>(
        TerminalConfigNotifier.new);

class TerminalConfigNotifier extends Notifier<TerminalConfig> {
  @override
  TerminalConfig build() {
    final service = ref.watch(appConfigServiceProvider);
    return service.terminal;
  }

  Future<void> updateConfig(TerminalConfig config) async {
    final service = ref.read(appConfigServiceProvider);
    await service.saveTerminalConfig(config);
    state = config;
  }

  Future<void> updateFontSize(double size) async {
    final newConfig = state.copyWith(fontSize: size);
    await updateConfig(newConfig);
  }
}
