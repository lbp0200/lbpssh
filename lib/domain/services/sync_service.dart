import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';

// =============================================================================
// SyncConfig
// =============================================================================

class SyncConfig {
  final String? accessToken;
  final String? gistId; // GitHub Gist ID，首次上传时自动创建
  final String gistFilename; // Gist 中的文件名
  final bool autoSync;
  final int syncIntervalMinutes;

  SyncConfig({
    this.accessToken,
    this.gistId,
    this.gistFilename = AppConstants.defaultGistFilename,
    this.autoSync = false,
    this.syncIntervalMinutes = AppConstants.defaultSyncIntervalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'gistId': gistId,
    'gistFilename': gistFilename,
    'autoSync': autoSync,
    'syncIntervalMinutes': syncIntervalMinutes,
  };

  /// 向后兼容旧的 repo 格式字段
  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    accessToken: json['accessToken'] as String?,
    gistId: json['gistId'] as String?,
    gistFilename:
        (json['gistFilename'] as String?) ?? AppConstants.defaultGistFilename,
    autoSync: (json['autoSync'] as bool?) ?? false,
    syncIntervalMinutes:
        (json['syncIntervalMinutes'] as int?) ??
        AppConstants.defaultSyncIntervalMinutes,
  );
}

// =============================================================================
// SyncStatusEnum
// =============================================================================

enum SyncStatusEnum { idle, syncing, success, error }

// =============================================================================
// SyncService
// =============================================================================

class SyncService {
  final ConnectionRepository _repository;
  final Dio _dio;
  final SharedPreferences? _prefs;
  SyncConfig? _config;
  SyncStatusEnum _status = SyncStatusEnum.idle;
  DateTime? _lastSyncTime;

  SyncService(this._repository, {Dio? dio, SharedPreferences? prefs})
    : _dio = dio ?? Dio(),
      _prefs = prefs {
    _loadConfig();
  }

  /// 加载同步配置
  Future<void> _loadConfig() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final configJson = prefs.getString(AppConstants.syncSettingsKey);
      if (configJson != null) {
        _config = SyncConfig.fromJson(
          jsonDecode(configJson) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _config = null;
    }
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    _config = config;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.syncSettingsKey,
      jsonEncode(config.toJson()),
    );
  }

  /// 获取同步配置
  SyncConfig? getConfig() => _config;

  /// 获取同步状态
  SyncStatusEnum get status => _status;

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 上传配置到 GitHub Gist
  Future<void> uploadConfig() async {
    if (_config == null || _config!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

    _status = SyncStatusEnum.syncing;

    try {
      // 获取所有连接
      final connections = _repository.getAllConnections();

      // 转换为 JSON
      final jsonData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'connections': connections.map((c) => c.toJson()).toList(),
      };

      final content = jsonEncode(jsonData);
      if (_config!.gistId == null) {
        // 无 Gist ID → 创建新 Gist
        await _createGist(content);
      } else {
        // 已有 Gist ID → 更新已有 Gist
        await _updateGist(content);
      }

      _lastSyncTime = DateTime.now();
      _status = SyncStatusEnum.success;
    } catch (e) {
      _status = SyncStatusEnum.error;
      rethrow;
    }
  }

  /// 从 GitHub Gist 下载配置
  /// [skipConflictCheck] 是否跳过冲突检测（用于测试连接时）
  Future<void> downloadConfig({bool skipConflictCheck = false}) async {
    if (_config == null || _config!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

    _status = SyncStatusEnum.syncing;

    try {
      final content = await _downloadFromGist();

      final jsonData = jsonDecode(content) as Map<String, dynamic>;

      // 解析连接配置
      final connectionsJson = jsonData['connections'] as List? ?? [];
      final connections = connectionsJson
          .whereType<Map<String, dynamic>>()
          .map((json) => SshConnection.fromJson(json))
          .toList();

      // 检测冲突（除非明确跳过）
      if (!skipConflictCheck) {
        final localConnections = _repository.getAllConnections();
        final conflicts = _detectConflicts(localConnections, connections);

        if (conflicts.isNotEmpty) {
          // 有冲突，需要用户解决
          throw SyncConflictException(conflicts);
        }
      }

      // 保存配置
      await _repository.saveConnections(connections);

      _lastSyncTime = DateTime.now();
      _status = SyncStatusEnum.success;
    } catch (e) {
      _status = SyncStatusEnum.error;
      rethrow;
    }
  }

  /// 创建新 Gist（POST /gists）
  Future<void> _createGist(String content) async {
    final token = _config!.accessToken;
    final filename = _config!.gistFilename;

    final body = {
      'description': 'lbpSSH config sync',
      'public': false,
      'files': {
        filename: {'content': content},
      },
    };

    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.github.com/gists',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('创建 Gist 失败：空响应');
    }

    final gistId = data['id'] as String?;
    if (gistId == null) {
      throw Exception('创建 Gist 失败：未返回 ID');
    }

    // 保存 gistId 到配置
    final updatedConfig = SyncConfig(
      accessToken: token,
      gistId: gistId,
      gistFilename: filename,
      autoSync: _config!.autoSync,
      syncIntervalMinutes: _config!.syncIntervalMinutes,
    );
    await saveConfig(updatedConfig);
  }

  /// 更新已有 Gist（PATCH /gists/{gist_id}）
  Future<void> _updateGist(String content) async {
    final token = _config!.accessToken;
    final gistId = _config!.gistId!;
    final filename = _config!.gistFilename;

    final body = {
      'files': {
        filename: {'content': content},
      },
    };

    await _dio.patch<Map<String, dynamic>>(
      'https://api.github.com/gists/$gistId',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
  }

  /// 从 Gist 下载内容（GET /gists/{gist_id}）
  Future<String> _downloadFromGist() async {
    final token = _config!.accessToken;
    final gistId = _config!.gistId;
    final filename = _config!.gistFilename;

    if (gistId == null) {
      throw Exception('未设置 Gist ID，请先上传配置');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/gists/$gistId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Gist 不存在');
    }

    final files = data['files'] as Map<String, dynamic>?;
    if (files == null) {
      throw Exception('Gist 文件列表为空');
    }

    final file = files[filename] as Map<String, dynamic>?;
    if (file == null) {
      throw Exception('Gist 中未找到文件: $filename');
    }

    final fileContent = file['content'] as String?;
    if (fileContent == null || fileContent.isEmpty) {
      throw Exception('文件内容为空');
    }

    return fileContent;
  }

  /// 检测冲突
  List<SyncConflict> _detectConflicts(
    List<SshConnection> local,
    List<SshConnection> remote,
  ) {
    final conflicts = <SyncConflict>[];

    // 创建 ID 映射
    final remoteMap = {for (var c in remote) c.id: c};

    // 检查每个连接的冲突
    for (final localConn in local) {
      final remoteConn = remoteMap[localConn.id];
      if (remoteConn != null) {
        // 两个版本都存在，检查版本号
        if (localConn.version != remoteConn.version &&
            localConn.updatedAt.isAfter(remoteConn.updatedAt) &&
            remoteConn.updatedAt.isAfter(localConn.createdAt)) {
          // 有冲突
          conflicts.add(
            SyncConflict(
              connectionId: localConn.id,
              localConnection: localConn,
              remoteConnection: remoteConn,
            ),
          );
        }
      }
    }

    return conflicts;
  }
}

// =============================================================================
// SyncConflictException
// =============================================================================

class SyncConflictException implements Exception {
  final List<SyncConflict> conflicts;
  SyncConflictException(this.conflicts);

  @override
  String toString() => '发现 ${conflicts.length} 个同步冲突';
}

// =============================================================================
// SyncConflict
// =============================================================================

class SyncConflict {
  final String connectionId;
  final SshConnection localConnection;
  final SshConnection remoteConnection;

  SyncConflict({
    required this.connectionId,
    required this.localConnection,
    required this.remoteConnection,
  });
}
