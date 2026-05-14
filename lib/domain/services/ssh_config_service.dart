import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/models/ssh_connection.dart';

/// SSH Config 文件服务
class SshConfigService {
  /// 获取默认 SSH config 文件路径
  static String getDefaultConfigPath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(home, '.ssh', 'config');
  }

  /// 读取并解析 SSH config 文件
  static List<SshConfigEntry> readConfigFile({String? filePath}) {
    final configPath = filePath ?? getDefaultConfigPath();
    final configFile = File(configPath);

    if (!configFile.existsSync()) {
      return [];
    }

    try {
      final content = configFile.readAsStringSync();
      return SshConfigEntry.parse(content);
    } catch (e) {
      return [];
    }
  }

  /// 查找匹配的主机配置
  static SshConfigEntry? findHostEntry(String hostPattern, {String? filePath}) {
    final entries = readConfigFile(filePath: filePath);

    // 支持通配符匹配
    final regex = _globToRegex(hostPattern);

    for (final entry in entries) {
      if (regex.hasMatch(entry.hostName)) {
        return entry;
      }
    }

    // 精确匹配
    for (final entry in entries) {
      if (entry.hostName == hostPattern) {
        return entry;
      }
    }

    return null;
  }

  /// 将 glob 模式转换为正则表达式
  static RegExp _globToRegex(String pattern) {
    final regexPattern = pattern.replaceAll('*', '.*').replaceAll('?', '.');
    return RegExp('^$regexPattern\$');
  }

  /// 检查 SSH config 文件是否存在
  static bool configFileExists({String? filePath}) {
    final configPath = filePath ?? getDefaultConfigPath();
    return File(configPath).existsSync();
  }
}
