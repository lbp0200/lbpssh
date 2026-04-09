import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/repositories/connection_repository.dart';
import '../../core/constants/app_constants.dart';

/// 同步平台类型
enum SyncPlatform {
  gist, // GitHub Gist
  giteeGist, // Gitee Gist
}

/// 同步状态
enum SyncStatusEnum { idle, syncing, success, error }

/// 同步配置
class SyncConfig {
  final SyncPlatform platform;
  final String? accessToken;
  final String? gistId; // Gist ID
  final String? gistFileName; // Gist 文件名（默认使用 defaultSyncFileName）
  final bool autoSync;
  final int syncIntervalMinutes;

  SyncConfig({
    required this.platform,
    this.accessToken,
    this.gistId,
    this.gistFileName,
    this.autoSync = false,
    this.syncIntervalMinutes = AppConstants.defaultSyncIntervalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'accessToken': accessToken,
    'gistId': gistId,
    'gistFileName': gistFileName,
    'autoSync': autoSync,
    'syncIntervalMinutes': syncIntervalMinutes,
  };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    platform: SyncPlatform.values.firstWhere(
      (e) => e.name == (json['platform'] as String? ?? 'gist'),
      orElse: () => SyncPlatform.gist,
    ),
    accessToken: json['accessToken'] as String?,
    gistId: json['gistId'] as String?,
    gistFileName: json['gistFileName'] as String?,
    autoSync: (json['autoSync'] as bool?) ?? false,
    syncIntervalMinutes:
        (json['syncIntervalMinutes'] as int?) ?? AppConstants.defaultSyncIntervalMinutes,
  );
}

/// 配置同步服务
class SyncService with ChangeNotifier {
  final ConnectionRepository _repository;
  final Dio _dio;
  SyncConfig? _config;
  SyncStatusEnum _status = SyncStatusEnum.idle;
  DateTime? _lastSyncTime;

  SyncService(this._repository, {Dio? dio}) : _dio = dio ?? Dio() {
    _loadConfig();
  }

  /// 加载同步配置
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(AppConstants.syncSettingsKey);
    if (configJson != null) {
      _config = SyncConfig.fromJson(jsonDecode(configJson) as Map<String, dynamic>);
    }
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
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
      final contentBase64 = base64Encode(utf8.encode(content));

      // 上传到 Gist
      if (_config!.platform == SyncPlatform.giteeGist) {
        await _uploadToGiteeGist(contentBase64);
      } else {
        await _uploadToGitHubGist(contentBase64);
      }

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
      String contentBase64;
      if (_config!.platform == SyncPlatform.giteeGist) {
        contentBase64 = await _downloadFromGiteeGist();
      } else {
        contentBase64 = await _downloadFromGitHubGist();
      }

      final content = utf8.decode(base64Decode(contentBase64));
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

  /// 上传到 GitHub Gist
  Future<void> _uploadToGitHubGist(String contentBase64) async {
    final fileName = _config!.gistFileName ?? AppConstants.defaultSyncFileName;
    final url = 'https://api.github.com/gists';

    if (_config!.gistId == null) {
      // 创建新的 Gist
      final data = {
        'description': 'SSH Connections Config',
        'public': false,
        'files': {
          fileName: {'content': utf8.decode(base64Decode(contentBase64))},
        },
      };

      final response = await _dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'token ${_config!.accessToken}',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      // 保存 Gist ID 到配置
      final newConfig = SyncConfig(
        platform: _config!.platform,
        accessToken: _config!.accessToken,
        gistId: response.data['id'] as String,
        gistFileName: fileName,
        autoSync: _config!.autoSync,
        syncIntervalMinutes: _config!.syncIntervalMinutes,
      );
      await saveConfig(newConfig);
    } else {
      // 更新现有的 Gist
      final url = 'https://api.github.com/gists/${_config!.gistId}';

      // 先获取现有 Gist 以获取文件 SHA
      final getResponse = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'token ${_config!.accessToken}',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      final files = getResponse.data['files'] as Map<String, dynamic>;
      final existingFile = files[fileName];
      String? fileSha;
      if (existingFile != null) {
        fileSha = existingFile['sha'] as String?;
      }

      final fileContent = <String, dynamic>{
        'content': utf8.decode(base64Decode(contentBase64)),
      };
      if (fileSha != null) {
        fileContent['sha'] = fileSha;
      }

      final data = {
        'description': 'SSH Connections Config',
        'files': {
          fileName: fileContent,
        },
      };

      await _dio.patch(
        url,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'token ${_config!.accessToken}',
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );
    }
  }

  /// 从 GitHub Gist 下载
  Future<String> _downloadFromGitHubGist() async {
    if (_config!.gistId == null) {
      throw Exception('Gist ID 未设置');
    }

    final fileName = _config!.gistFileName ?? AppConstants.defaultSyncFileName;
    final url = 'https://api.github.com/gists/${_config!.gistId}';

    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'Authorization': 'token ${_config!.accessToken}',
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    final files = response.data['files'] as Map<String, dynamic>;
    final file = files[fileName];
    if (file == null) {
      throw Exception('Gist 中未找到文件: $fileName');
    }

    // Gist API 返回的 content 已经是字符串，需要转换为 base64
    final content = file['content'] as String;
    return base64Encode(utf8.encode(content));
  }

  /// 上传到 Gitee Gist
  Future<void> _uploadToGiteeGist(String contentBase64) async {
    final fileName = _config!.gistFileName ?? AppConstants.defaultSyncFileName;
    final token = _config!.accessToken;
    final url = 'https://gitee.com/api/v5/gists?access_token=$token';

    // 检查 gistId 是否为空（包括 null 和空字符串）
    final gistId = _config!.gistId;
    final hasGistId = gistId != null && gistId.isNotEmpty;

    if (!hasGistId) {
      // 创建新的 Gist
      final data = {
        'description': 'SSH Connections Config',
        'public': false,
        'files': {
          fileName: {'content': utf8.decode(base64Decode(contentBase64))},
        },
      };

      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // 检查响应格式
      if (response.data is! Map<String, dynamic>) {
        throw Exception('Gitee API 响应格式错误: ${response.data.runtimeType}');
      }

      final responseData = response.data as Map<String, dynamic>;

      // 检查是否包含错误信息
      if (responseData.containsKey('message')) {
        throw Exception('Gitee API 错误: ${responseData['message']}');
      }

      // 保存 Gist ID 到配置
      final newConfig = SyncConfig(
        platform: _config!.platform,
        accessToken: _config!.accessToken,
        gistId: responseData['id'] as String?,
        gistFileName: fileName,
        autoSync: _config!.autoSync,
        syncIntervalMinutes: _config!.syncIntervalMinutes,
      );
      await saveConfig(newConfig);
    } else {
      // 更新现有的 Gist
      // 先获取现有 Gist 以获取文件 SHA
      final getUrl =
          'https://gitee.com/api/v5/gists/$gistId?access_token=$token';
      final getResponse = await _dio.get(getUrl);

      if (getResponse.data is! Map<String, dynamic>) {
        throw Exception('Gist ID 无效或 Token 权限不足');
      }

      final getData = getResponse.data as Map<String, dynamic>;
      final files = getData['files'] as Map<String, dynamic>?;
      final existingFile = files?[fileName];
      String? fileSha;
      if (existingFile != null && existingFile is Map) {
        fileSha = existingFile['sha'] as String?;
      }

      final fileContent = <String, dynamic>{
        'content': utf8.decode(base64Decode(contentBase64)),
      };
      if (fileSha != null) {
        fileContent['sha'] = fileSha;
      }

      final data = {
        'description': 'SSH Connections Config',
        'files': {
          fileName: fileContent,
        },
      };

      await _dio.post(
        url,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    }
  }

  /// 从 Gitee Gist 下载
  Future<String> _downloadFromGiteeGist() async {
    final gistId = _config!.gistId;
    if (gistId == null || gistId.isEmpty) {
      throw Exception('请先填写 Gist ID，或先上传配置创建新的 Gist');
    }

    final fileName = _config!.gistFileName ?? AppConstants.defaultSyncFileName;
    final token = _config!.accessToken;
    final url =
        'https://gitee.com/api/v5/gists/${_config!.gistId}?access_token=$token';

    final response = await _dio.get(url);

    // 如果返回的是 List，说明 Token 无效或 gistId 错误
    if (response.data is List) {
      throw Exception('Gist ID 无效或 Token 权限不足');
    }

    try {
      // 确保 response.data 是 Map
      Map<String, dynamic> responseData;
      if (response.data is Map) {
        responseData = response.data as Map<String, dynamic>;
      } else {
        throw Exception('Gitee Gist 返回数据格式错误: ${response.data.runtimeType}');
      }

      // 检查是否包含错误信息
      if (responseData.containsKey('message')) {
        throw Exception('Gitee API 错误: ${responseData['message']}');
      }

      final filesData = responseData['files'];

      if (filesData is! Map<String, dynamic>) {
        throw Exception('Gitee Gist files 格式错误');
      }

      // Gitee API 返回的文件结构是以文件名为 key
      dynamic file;
      if (filesData.containsKey(fileName)) {
        file = filesData[fileName];
      } else {
        // 尝试查找第一个文件
        final keys = filesData.keys.toList();
        if (keys.isNotEmpty) {
          file = filesData[keys.first];
        }
      }

      if (file is! Map<String, dynamic>) {
        throw Exception('Gist 中未找到文件: $fileName');
      }

      final content = file['content'] as String?;
      if (content == null) {
        throw Exception('文件内容为空');
      }

      return base64Encode(utf8.encode(content));
    } catch (e) {
      throw Exception('解析 Gitee Gist 失败: $e');
    }
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
