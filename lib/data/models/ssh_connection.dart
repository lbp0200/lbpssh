import 'package:json_annotation/json_annotation.dart';

part 'ssh_connection.g.dart';

/// SSH 连接配置模型
@JsonSerializable()
class SshConnection {
  /// 连接唯一标识
  final String id;

  /// 连接名称
  final String name;

  /// 主机地址
  final String host;

  /// 端口号
  final int port;

  /// 用户名
  final String username;

  /// 认证方式
  final AuthType authType;

  /// 密码（明文存储）
  final String? password;

  /// SSH 密钥路径
  final String? privateKeyPath;

  /// SSH 私钥内容（直接存储密钥内容）
  final String? privateKeyContent;

  /// 密钥密码（明文存储）
  final String? keyPassphrase;

  /// 跳板机配置
  final JumpHostConfig? jumpHost;

  /// SOCKS5 代理配置
  final Socks5ProxyConfig? socks5Proxy;

  /// SSH Config 主机名（用于 sshConfig 认证方式）
  final String? sshConfigHost;

  /// 备注
  final String? notes;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 版本号（用于同步冲突检测）
  final int version;

  /// 连接超时时间（毫秒）
  final int connectTimeout;

  /// Keepalive 间隔时间（毫秒），默认 30000（30秒）
  final int keepaliveInterval;

  SshConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.password,
    this.privateKeyPath,
    this.privateKeyContent,
    this.keyPassphrase,
    this.jumpHost,
    this.socks5Proxy,
    this.sshConfigHost,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.connectTimeout = 30000,
    this.keepaliveInterval = 30000,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 从 JSON 创建
  factory SshConnection.fromJson(Map<String, dynamic> json) =>
      _$SshConnectionFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$SshConnectionToJson(this);

  /// 创建副本
  SshConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    String? privateKeyPath,
    String? privateKeyContent,
    String? keyPassphrase,
    JumpHostConfig? jumpHost,
    Socks5ProxyConfig? socks5Proxy,
    String? sshConfigHost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    int? connectTimeout,
    int? keepaliveInterval,
  }) {
    return SshConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      privateKeyContent: privateKeyContent ?? this.privateKeyContent,
      keyPassphrase: keyPassphrase ?? this.keyPassphrase,
      jumpHost: jumpHost ?? this.jumpHost,
      socks5Proxy: socks5Proxy ?? this.socks5Proxy,
      sshConfigHost: sshConfigHost ?? this.sshConfigHost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      keepaliveInterval: keepaliveInterval ?? this.keepaliveInterval,
    );
  }
}

/// 认证方式枚举
enum AuthType {
  @JsonValue('password')
  password,

  @JsonValue('key')
  key,

  @JsonValue('keyWithPassword')
  keyWithPassword,

  @JsonValue('sshConfig')
  sshConfig,
}

/// 跳板机配置
@JsonSerializable()
class JumpHostConfig {
  /// 跳板机主机
  final String host;

  /// 跳板机端口
  final int port;

  /// 跳板机用户名
  final String username;

  /// 跳板机认证方式
  final AuthType authType;

  /// 跳板机密码（明文存储）
  final String? password;

  /// 跳板机密钥路径
  final String? privateKeyPath;

  JumpHostConfig({
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.password,
    this.privateKeyPath,
  });

  factory JumpHostConfig.fromJson(Map<String, dynamic> json) =>
      _$JumpHostConfigFromJson(json);

  Map<String, dynamic> toJson() => _$JumpHostConfigToJson(this);

  /// 创建副本
  JumpHostConfig copyWith({
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    String? privateKeyPath,
  }) {
    return JumpHostConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
    );
  }
}

/// SOCKS5 代理配置
@JsonSerializable()
class Socks5ProxyConfig {
  /// 代理主机地址
  final String host;

  /// 代理端口
  final int port;

  /// 代理用户名（可选）
  final String? username;

  /// 代理密码（可选）
  final String? password;

  Socks5ProxyConfig({
    required this.host,
    this.port = 1080,
    this.username,
    this.password,
  });

  factory Socks5ProxyConfig.fromJson(Map<String, dynamic> json) =>
      _$Socks5ProxyConfigFromJson(json);

  Map<String, dynamic> toJson() => _$Socks5ProxyConfigToJson(this);

  /// 创建副本
  Socks5ProxyConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return Socks5ProxyConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

/// SSH Config 文件中的主机配置条目
class SshConfigEntry {
  /// 主机名（Host 别名）
  final String hostName;

  /// 实际主机地址
  final String? actualHost;

  /// 端口
  final int? port;

  /// 用户名
  final String? user;

  /// 身份文件
  final List<String>? identityFiles;

  /// 是否启用密钥认证
  final bool? identityOnly;

  /// 代理命令
  final String? proxyCommand;

  /// 连接超时
  final int? connectTimeout;

  SshConfigEntry({
    required this.hostName,
    this.actualHost,
    this.port,
    this.user,
    this.identityFiles,
    this.identityOnly,
    this.proxyCommand,
    this.connectTimeout,
  });

  /// 解析 SSH config 文件
  static List<SshConfigEntry> parse(String content) {
    final entries = <SshConfigEntry>[];
    String? currentHost;
    final currentConfig = <String, List<String>>{};

    for (final line in content.split('\n')) {
      final trimmed = line.trim();

      // 跳过空行和注释
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      // 解析键值对
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final key = parts[0].toLowerCase();
        final value = parts.sublist(1).join(' ');

        if (key == 'host') {
          // 保存之前的条目
          if (currentHost != null) {
            entries.add(_createEntry(currentHost, currentConfig));
          }
          currentHost = value;
          currentConfig.clear();
        } else if (currentHost != null) {
          currentConfig[key] ??= [];
          currentConfig[key]!.add(value);
        }
      }
    }

    // 保存最后一个条目
    if (currentHost != null) {
      entries.add(_createEntry(currentHost, currentConfig));
    }

    return entries;
  }

  static SshConfigEntry _createEntry(
    String host,
    Map<String, List<String>> config,
  ) {
    return SshConfigEntry(
      hostName: host,
      actualHost: config['hostname']?.firstOrNull,
      port: int.tryParse(config['port']?.firstOrNull ?? ''),
      user: config['user']?.firstOrNull,
      identityFiles: config['identityfile'],
      identityOnly: config['identityonly']?.firstOrNull?.toLowerCase() == 'yes',
      proxyCommand: config['proxycommand']?.firstOrNull,
      connectTimeout: int.tryParse(config['connecttimeout']?.firstOrNull ?? ''),
    );
  }

  /// 获取实际连接地址
  String getConnectHost() => actualHost ?? hostName;
}
