import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';
import '../../core/constants/app_constants.dart';

/// 同步平台类型
enum SyncPlatform {
  githubRepo; // GitHub 仓库

  /// 从旧版 Gist 值向后兼容
  static SyncPlatform fromName(String name) {
    return switch (name) {
      'githubRepo' || 'gist' || 'giteeGist' => SyncPlatform.githubRepo,
      _ => SyncPlatform.githubRepo,
    };
  }
}

/// 同步状态
enum SyncStatusEnum { idle, syncing, success, error }

/// 同步配置
class SyncConfig {
  final SyncPlatform platform;
  final String? accessToken;
  final String? repoOwner; // GitHub 仓库所有者
  final String? repoName; // GitHub 仓库名
  final String? filePath; // 配置文件路径（默认使用 defaultConfigFilePath）
  final String? branch; // 分支（默认 main）
  final bool autoSync;
  final int syncIntervalMinutes;

  SyncConfig({
    required this.platform,
    this.accessToken,
    this.repoOwner,
    this.repoName,
    this.filePath,
    this.branch,
    this.autoSync = false,
    this.syncIntervalMinutes = AppConstants.defaultSyncIntervalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'accessToken': accessToken,
    'repoOwner': repoOwner,
    'repoName': repoName,
    'filePath': filePath,
    'branch': branch,
    'autoSync': autoSync,
    'syncIntervalMinutes': syncIntervalMinutes,
  };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    platform: SyncPlatform.fromName(
      json['platform'] as String? ?? 'githubRepo',
    ),
    accessToken: json['accessToken'] as String?,
    repoOwner: json['repoOwner'] as String?,
    repoName: json['repoName'] as String?,
    filePath: json['filePath'] as String?,
    branch: json['branch'] as String?,
    autoSync: (json['autoSync'] as bool?) ?? false,
    syncIntervalMinutes:
        (json['syncIntervalMinutes'] as int?) ??
        AppConstants.defaultSyncIntervalMinutes,
  );
}

/// 配置同步服务
class SyncService with ChangeNotifier {
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
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final configJson = prefs.getString(AppConstants.syncSettingsKey);
    if (configJson != null) {
      _config = SyncConfig.fromJson(
        jsonDecode(configJson) as Map<String, dynamic>,
      );
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
    notifyListeners();
  }

  /// 获取同步配置
  SyncConfig? getConfig() => _config;

  /// 获取同步状态
  SyncStatusEnum get status => _status;

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 上传配置到远程仓库
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
      await _uploadToGitHubRepo(content);

      _lastSyncTime = DateTime.now();
      _status = SyncStatusEnum.success;
    } catch (e) {
      _status = SyncStatusEnum.error;
      rethrow;
    }
  }

  /// 从远程仓库下载配置
  /// [skipConflictCheck] 是否跳过冲突检测（用于测试连接时）
  Future<void> downloadConfig({bool skipConflictCheck = false}) async {
    if (_config == null || _config!.accessToken == null) {
      throw Exception('同步配置未设置或未授权');
    }

    _status = SyncStatusEnum.syncing;

    try {
      final content = await _downloadFromGitHubRepo();

      final jsonData = jsonDecode(content) as Map<String, dynamic>;

      // 解析连接配置
      final connectionsJson = jsonData['connections'] as List;
      final connections = connectionsJson
          .map((json) => SshConnection.fromJson(json as Map<String, dynamic>))
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

  /// 上传内容到 GitHub 仓库（GitHub Contents API）
  Future<void> _uploadToGitHubRepo(String content) async {
    final owner = _config!.repoOwner;
    final repo = _config!.repoName;
    final path = _config!.filePath ?? AppConstants.defaultConfigFilePath;
    final branch = _config!.branch ?? AppConstants.defaultBranch;

    if (owner == null || repo == null) {
      throw Exception('请设置 GitHub 仓库信息（owner/repo）');
    }

    final token = _config!.accessToken;
    final contentBase64 = base64Encode(utf8.encode(content));

    final url = 'https://api.github.com/repos/$owner/$repo/contents/$path';

    // 先尝试获取现有文件以获取 SHA（用于更新）
    String? existingSha;
    try {
      final getResponse = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'ref': branch},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );
      if (getResponse.data is Map<String, dynamic>) {
        existingSha = getResponse.data!['sha'] as String?;
      }
    } catch (_) {
      // 文件不存在，从头创建
    }

    final putData = <String, dynamic>{
      'message': 'Update SSH connections config',
      'content': contentBase64,
      'branch': branch,
    };
    if (existingSha != null) {
      putData['sha'] = existingSha;
    }

    await _dio.put<Map<String, dynamic>>(
      url,
      data: putData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
  }

  /// 从 GitHub 仓库下载内容（GitHub Contents API）
  Future<String> _downloadFromGitHubRepo() async {
    final owner = _config!.repoOwner;
    final repo = _config!.repoName;
    final path = _config!.filePath ?? AppConstants.defaultConfigFilePath;
    final branch = _config!.branch ?? AppConstants.defaultBranch;

    if (owner == null || repo == null) {
      throw Exception('请设置 GitHub 仓库信息（owner/repo）');
    }

    final token = _config!.accessToken;
    final url = 'https://api.github.com/repos/$owner/$repo/contents/$path';

    final response = await _dio.get<Map<String, dynamic>>(
      url,
      queryParameters: {'ref': branch},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('仓库中未找到文件: $path');
    }

    final encodedContent = data['content'] as String?;
    if (encodedContent == null) {
      throw Exception('文件内容为空');
    }

    // GitHub API 返回的 content 是 base64 编码（含换行符）
    final cleaned = encodedContent.replaceAll(RegExp(r'\s'), '');
    return utf8.decode(base64Decode(cleaned));
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

/// 同步冲突异常
class SyncConflictException implements Exception {
  final List<SyncConflict> conflicts;

  SyncConflictException(this.conflicts);

  @override
  String toString() => '发现 ${conflicts.length} 个配置冲突';
}

/// 同步冲突
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
