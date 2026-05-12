import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/default_terminal_config.dart';
import '../../data/models/ssh_config.dart';
import '../../data/models/terminal_config.dart';
import '../../utils/color_utils.dart';
import 'service_providers.dart';

/// Terminal configuration provider
final terminalConfigProvider =
    NotifierProvider<TerminalConfigNotifier, TerminalConfig>(
      TerminalConfigNotifier.new,
    );

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

/// Default terminal configuration provider
final defaultTerminalConfigProvider =
    NotifierProvider<DefaultTerminalConfigNotifier, DefaultTerminalConfig>(
      DefaultTerminalConfigNotifier.new,
    );

class DefaultTerminalConfigNotifier extends Notifier<DefaultTerminalConfig> {
  @override
  DefaultTerminalConfig build() {
    final service = ref.watch(appConfigServiceProvider);
    return service.defaultTerminal;
  }
}

/// SSH configuration provider
final sshConfigProvider = NotifierProvider<SshConfigNotifier, SshConfig>(
  SshConfigNotifier.new,
);

class SshConfigNotifier extends Notifier<SshConfig> {
  @override
  SshConfig build() {
    final service = ref.watch(appConfigServiceProvider);
    return service.ssh;
  }

  Future<void> updateConfig(SshConfig config) async {
    final service = ref.read(appConfigServiceProvider);
    await service.saveSshConfig(config);
    ColorUtils.clearCache();
    state = config;
  }
}
