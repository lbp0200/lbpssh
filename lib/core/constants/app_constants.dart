/// 应用常量
class AppConstants {
  // 应用信息
  static const String appName = 'SSH Manager';
  static const String appVersion = '1.7.1';

  // 存储键名
  static const String syncSettingsKey = 'sync_settings';
  static const String appConfigKey = 'app_config';

  // 默认值
  static const int defaultSshPort = 22;
  static const int defaultSyncIntervalMinutes = 5;

  // 默认 Gist 文件名
  static const String defaultGistFilename = 'ssh_connections.json';

  // 文件路径
  static const String configDirName = 'lbpSSH';
}
