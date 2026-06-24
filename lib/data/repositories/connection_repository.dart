import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/ssh_connection.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/encryption.dart';

/// 连接配置仓库
class ConnectionRepository {
  static const String _fileName = 'ssh_connections.json';
  static const String _keyFileName = 'encryption.key';
  File? _configFile;
  Map<String, SshConnection> _connectionsCache = {};
  Uint8List? _encryptionKey;

  /// 敏感字段列表（序列化时需要加密/解密）
  static const _sensitiveFields = [
    'password',
    'privateKeyContent',
    'keyPassphrase',
  ];

  /// Creates a repository with a custom config file path.
  /// Primarily intended for testing.
  ConnectionRepository({File? configFile}) : _configFile = configFile;

  /// 初始化仓库
  Future<void> init() async {
    if (_configFile != null) {
      await _initEncryptionKey();
      await _loadCache();
      return;
    }
    final dir = await getApplicationSupportDirectory();
    final configDir = Directory('${dir.path}/${AppConstants.configDirName}');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    _configFile = File('${configDir.path}/$_fileName');

    if (!await _configFile!.exists()) {
      await _configFile!.writeAsString('[]');
    }

    await _initEncryptionKey();
    await _loadCache();
  }

  /// 初始化加密密钥
  Future<void> _initEncryptionKey() async {
    final dir = _configFile!.parent;
    final keyFile = File('${dir.path}/$_keyFileName');
    if (await keyFile.exists()) {
      final stored = await keyFile.readAsString();
      _encryptionKey = base64Decode(stored.trim());
    } else {
      _encryptionKey = EncryptionUtil.randomBytes(32);
      await keyFile.writeAsString(base64Encode(_encryptionKey!));
    }
  }

  /// 加密敏感字段
  void _encryptFields(Map<String, dynamic> map) {
    for (final field in _sensitiveFields) {
      final value = map[field];
      if (value is String && value.isNotEmpty) {
        map[field] = EncryptionUtil.encryptField(value, _encryptionKey!);
      }
    }

    // 嵌套跳板机
    final jumpHost = map['jumpHost'];
    if (jumpHost is Map<String, dynamic>) {
      final pw = jumpHost['password'];
      if (pw is String && pw.isNotEmpty) {
        jumpHost['password'] = EncryptionUtil.encryptField(pw, _encryptionKey!);
      }
    }

    // 嵌套 SOCKS5 代理
    final socks5 = map['socks5Proxy'];
    if (socks5 is Map<String, dynamic>) {
      final pw = socks5['password'];
      if (pw is String && pw.isNotEmpty) {
        socks5['password'] = EncryptionUtil.encryptField(pw, _encryptionKey!);
      }
    }
  }

  /// 解密敏感字段
  void _decryptFields(Map<String, dynamic> map) {
    for (final field in _sensitiveFields) {
      final value = map[field];
      if (value is String && value.isNotEmpty) {
        map[field] = EncryptionUtil.decryptField(value, _encryptionKey!);
      }
    }

    // 嵌套跳板机
    final jumpHost = map['jumpHost'];
    if (jumpHost is Map<String, dynamic>) {
      final pw = jumpHost['password'];
      if (pw is String && pw.isNotEmpty) {
        jumpHost['password'] = EncryptionUtil.decryptField(pw, _encryptionKey!);
      }
    }

    // 嵌套 SOCKS5 代理
    final socks5 = map['socks5Proxy'];
    if (socks5 is Map<String, dynamic>) {
      final pw = socks5['password'];
      if (pw is String && pw.isNotEmpty) {
        socks5['password'] = EncryptionUtil.decryptField(pw, _encryptionKey!);
      }
    }
  }

  /// 从文件加载数据到缓存
  Future<void> _loadCache() async {
    try {
      final content = await _configFile!.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      _connectionsCache = {
        for (var json in jsonList)
          (json['id'] as String): _deserializeConnection(
            json as Map<String, dynamic>,
          ),
      };
    } catch (e) {
      _connectionsCache = {};
      await _configFile!.writeAsString('[]');
    }
  }

  /// 反序列化（含解密）
  SshConnection _deserializeConnection(Map<String, dynamic> map) {
    _decryptFields(map);
    return SshConnection.fromJson(map);
  }

  /// 保存缓存到文件
  Future<void> _saveCache() async {
    final jsonList = _connectionsCache.values
        .map((conn) => conn.toJson())
        .toList();
    for (final map in jsonList) {
      _encryptFields(map);
    }
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
