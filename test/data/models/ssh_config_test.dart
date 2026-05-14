import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';

void main() {
  group('SshConfig', () {
    test('default config has expected keepalive interval', () {
      final config = SshConfig.defaultConfig;
      expect(config.keepaliveInterval, 30000);
    });

    test('fromJson parses valid JSON', () {
      final config = SshConfig.fromJson({'keepaliveInterval': 60000});
      expect(config.keepaliveInterval, 60000);
    });

    test('fromJson uses default when field missing', () {
      final config = SshConfig.fromJson({});
      expect(config.keepaliveInterval, 30000);
    });

    test('toJson serializes correctly', () {
      final config = SshConfig(keepaliveInterval: 45000);
      expect(config.toJson(), {'keepaliveInterval': 45000});
    });

    test('copyWith overrides keepaliveInterval', () {
      final config = SshConfig(keepaliveInterval: 30000);
      final copied = config.copyWith(keepaliveInterval: 60000);
      expect(copied.keepaliveInterval, 60000);
    });

    test('copyWith preserves value when argument is null', () {
      final config = SshConfig(keepaliveInterval: 30000);
      final copied = config.copyWith();
      expect(copied.keepaliveInterval, 30000);
    });
  });
}
