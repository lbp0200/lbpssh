import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/ssh_connection.dart';
import '../../core/constants/app_constants.dart';

/// 连接配置仓库
class ConnectionRepository {
  static const String _fileName = 'ssh_connections.json';
  File? _configFile;
  Map<String, SshConnection> _connectionsCache = {};

  /// 初始化仓库
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    final configDir = Directory('${dir.path}/${AppConstants.configDirName}');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    _configFile = File('${configDir.path}/$_fileName');

    // 如果文件不存在，尝试从 Hive 迁移数据
    if (!await _configFile!.exists()) {
      final migrated = await _migrateFromHive();
      if (!migrated) {
        // 如果没有旧数据，创建空文件
        await _configFile!.writeAsString('[]');
      }
    }

    // 加载缓存
    await _loadCache();
  }

  /// 从 Hive 迁移数据到 JSON 文件（如果存在旧数据）
  Future<bool> _migrateFromHive() async {
    try {
      // 检查是否存在 Hive 数据目录
      final dir = await getApplicationSupportDirectory();
      final hiveDir = Directory('${dir.path}/hive');

      if (!await hiveDir.exists()) {
        return false; // 没有 Hive 数据
      }

      // 尝试读取 Hive Box 文件（Hive 使用二进制格式，这里简化处理）
      // 注意：由于已经移除了 Hive 依赖，这里只做文件存在性检查
      // 实际迁移需要在有 Hive 依赖的情况下进行，或者用户手动导出导入

      // 如果检测到 Hive 目录但 JSON 文件不存在，说明可能需要迁移
      // 但由于已移除 Hive 依赖，这里返回 false，让用户通过同步功能从 Gist 恢复
      return false;
    } catch (e) {
      // 迁移失败，返回 false
      return false;
    }
  }

  /// 从文件加载数据到缓存
  Future<void> _loadCache() async {
    try {
      final content = await _configFile!.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      _connectionsCache = {
        for (var json in jsonList)
          (json['id'] as String): SshConnection.fromJson(
            json as Map<String, dynamic>,
          ),
      };
    } catch (e) {
      // 如果文件格式错误，重置为空
      _connectionsCache = {};
      await _configFile!.writeAsString('[]');
    }
  }

  /// 保存缓存到文件
  Future<void> _saveCache() async {
    final jsonList = _connectionsCache.values
        .map((conn) => conn.toJson())
        .toList();
    await _configFile!.writeAsString(jsonEncode(jsonList));
  }

  /// 获取所有连接
  List<SshConnection> getAllConnections() {
    return _connectionsCache.values.toList();
  }

  /// 根据 ID 获取连接
  SshConnection? getConnectionById(String id) {
    return _connectionsCache[id];
  }

  /// 保存连接
  Future<void> saveConnection(SshConnection connection) async {
    final updated = connection.copyWith(
      updatedAt: DateTime.now(),
      version: connection.version + 1,
    );
    _connectionsCache[connection.id] = updated;
    await _saveCache();
  }

  /// 删除连接
  Future<void> deleteConnection(String id) async {
    _connectionsCache.remove(id);
    await _saveCache();
  }

  /// 批量保存连接（用于同步）
  Future<void> saveConnections(List<SshConnection> connections) async {
    for (final connection in connections) {
      _connectionsCache[connection.id] = connection;
    }
    await _saveCache();
  }

  /// 清空所有连接
  Future<void> clearAll() async {
    _connectionsCache.clear();
    await _saveCache();
  }

  /// 关闭仓库（JSON文件不需要关闭，但保留接口兼容性）
  Future<void> close() async {
    // JSON文件不需要关闭操作
  }
}
