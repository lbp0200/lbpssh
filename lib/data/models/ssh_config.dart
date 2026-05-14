import 'package:json_annotation/json_annotation.dart';

part 'ssh_config.g.dart';

@JsonSerializable()
class SshConfig {
  /// Keepalive 间隔时间（毫秒），默认 30000（30秒）
  final int keepaliveInterval;

  SshConfig({this.keepaliveInterval = 30000});

  factory SshConfig.fromJson(Map<String, dynamic> json) =>
      _$SshConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SshConfigToJson(this);

  SshConfig copyWith({int? keepaliveInterval}) {
    return SshConfig(
      keepaliveInterval: keepaliveInterval ?? this.keepaliveInterval,
    );
  }

  static SshConfig get defaultConfig => SshConfig();
}
