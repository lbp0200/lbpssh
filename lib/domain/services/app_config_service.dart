import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/terminal_config.dart';
import '../../data/models/default_terminal_config.dart';
import '../../data/models/ssh_config.dart';

class AppConfig {
  TerminalConfig terminal;
  DefaultTerminalConfig defaultTerminal;
  SshConfig ssh;

  AppConfig({
    TerminalConfig? terminal,
    DefaultTerminalConfig? defaultTerminal,
    SshConfig? ssh,
  }) : terminal = terminal ?? TerminalConfig.defaultConfig,
       defaultTerminal = defaultTerminal ?? DefaultTerminalConfig.defaultConfig,
       ssh = ssh ?? SshConfig.defaultConfig;

  Map<String, dynamic> toJson() => {
    'terminal': terminal.toJson(),
    'defaultTerminal': defaultTerminal.toJson(),
    'ssh': ssh.toJson(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    terminal: json['terminal'] != null
        ? TerminalConfig.fromJson(json['terminal'] as Map<String, dynamic>)
        : null,
    defaultTerminal: json['defaultTerminal'] != null
        ? DefaultTerminalConfig.fromJson(
            json['defaultTerminal'] as Map<String, dynamic>,
          )
        : null,
    ssh: json['ssh'] != null
        ? SshConfig.fromJson(json['ssh'] as Map<String, dynamic>)
        : null,
  );
}

class AppConfigService with ChangeNotifier {
  static AppConfigService? _instance;
  static bool _initialized = false;
  TerminalConfig _terminal = TerminalConfig.defaultConfig;
  DefaultTerminalConfig _defaultTerminal = DefaultTerminalConfig.defaultConfig;
  SshConfig _ssh = SshConfig.defaultConfig;

  AppConfigService._internal();

  /// 测试专用：重置服务单例状态
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
    _initialized = false;
  }

  factory AppConfigService.getInstance() {
    _instance ??= AppConfigService._internal();
    return _instance!;
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      _instance ??= AppConfigService._internal();
      await _loadFromPrefs();
      _initialized = true;
    }
  }

  TerminalConfig get terminal => _terminal;
  DefaultTerminalConfig get defaultTerminal => _defaultTerminal;
  SshConfig get ssh => _ssh;

  Future<void> saveTerminalConfig(TerminalConfig config) async {
    _terminal = config;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> saveDefaultTerminalConfig(DefaultTerminalConfig config) async {
    _defaultTerminal = config;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> saveSshConfig(SshConfig config) async {
    _ssh = config;
    await _saveToPrefs();
    notifyListeners();
  }

  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(AppConstants.appConfigKey);
    if (configJson != null) {
      try {
        final json = jsonDecode(configJson) as Map<String, dynamic>;
        final config = AppConfig.fromJson(json);
        _instance!._terminal = config.terminal;
        _instance!._defaultTerminal = config.defaultTerminal;
        _instance!._ssh = config.ssh;
      } catch (e) {
        // Use defaults if parsing fails
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig(
      terminal: _terminal,
      defaultTerminal: _defaultTerminal,
      ssh: _ssh,
    );
    await prefs.setString(
      AppConstants.appConfigKey,
      jsonEncode(config.toJson()),
    );
  }

  Future<void> resetToDefaults() async {
    _terminal = TerminalConfig.defaultConfig;
    _defaultTerminal = DefaultTerminalConfig.defaultConfig;
    _ssh = SshConfig.defaultConfig;
    await _saveToPrefs();
    notifyListeners();
  }

  String exportConfig() {
    final config = AppConfig(
      terminal: _terminal,
      defaultTerminal: _defaultTerminal,
      ssh: _ssh,
    );
    return jsonEncode(config.toJson());
  }

  Future<void> importConfig(String jsonString) async {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final config = AppConfig.fromJson(json);
    _terminal = config.terminal;
    _defaultTerminal = config.defaultTerminal;
    _ssh = config.ssh;
    await _saveToPrefs();
    notifyListeners();
  }
}
