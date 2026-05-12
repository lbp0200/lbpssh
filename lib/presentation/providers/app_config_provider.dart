import 'package:flutter/foundation.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../../data/models/ssh_config.dart';
import '../../domain/services/app_config_service.dart';
import '../../utils/color_utils.dart';

class AppConfigProvider extends ChangeNotifier {
  final AppConfigService _configService;

  AppConfigProvider(this._configService);

  TerminalConfig get terminalConfig => _configService.terminal;
  DefaultTerminalConfig get defaultTerminalConfig =>
      _configService.defaultTerminal;
  SshConfig get sshConfig => _configService.ssh;

  Future<void> saveTerminalConfig(TerminalConfig config) async {
    await _configService.saveTerminalConfig(config);
    ColorUtils.clearCache();
    notifyListeners();
  }

  void updateFontSize(double size) {
    final newConfig = _configService.terminal.copyWith(fontSize: size);
    _configService.saveTerminalConfig(newConfig);
    notifyListeners();
  }

  Future<void> saveDefaultTerminalConfig(DefaultTerminalConfig config) async {
    await _configService.saveDefaultTerminalConfig(config);
    notifyListeners();
  }

  Future<void> saveSshConfig(SshConfig config) async {
    await _configService.saveSshConfig(config);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _configService.resetToDefaults();
    ColorUtils.clearCache();
    notifyListeners();
  }

  String exportConfig() {
    return _configService.exportConfig();
  }

  Future<void> importConfig(String jsonString) async {
    await _configService.importConfig(jsonString);
    ColorUtils.clearCache();
    notifyListeners();
  }
}
