import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_config.dart';

void main() {
  group('SshConfig Model', () {
    // ==================== 构造函数测试 ====================
    test(
        'Given no arguments, When creating SshConfig, Then uses default keepaliveInterval of 30000',
        () {
      final config = SshConfig();

      expect(config.keepaliveInterval, 30000);
    });

    test(
        'Given custom keepaliveInterval, When creating SshConfig, Then uses custom value',
        () {
      final config = SshConfig(keepaliveInterval: 60000);

      expect(config.keepaliveInterval, 60000);
    });

    // ==================== 边界值测试 ====================
    test(
        'Given keepaliveInterval of 0, When creating SshConfig, Then allows zero value (keepalive disabled)',
        () {
      final config = SshConfig(keepaliveInterval: 0);

      expect(config.keepaliveInterval, 0);
    });

    test(
        'Given very small keepaliveInterval, When creating SshConfig, Then accepts 1ms value',
        () {
      final config = SshConfig(keepaliveInterval: 1);

      expect(config.keepaliveInterval, 1);
    });

    test(
        'Given very large keepaliveInterval, When creating SshConfig, Then accepts large value',
        () {
      final config = SshConfig(keepaliveInterval: 86400000); // 24 hours in ms

      expect(config.keepaliveInterval, 86400000);
    });

    test(
        'Given various keepaliveInterval values, When creating configs, Then stores correct values',
        () {
      final configs = [
        SshConfig(keepaliveInterval: 0),
        SshConfig(keepaliveInterval: 1000),
        SshConfig(keepaliveInterval: 30000),
        SshConfig(keepaliveInterval: 60000),
        SshConfig(keepaliveInterval: 300000),
      ];

      expect(configs[0].keepaliveInterval, 0);
      expect(configs[1].keepaliveInterval, 1000);
      expect(configs[2].keepaliveInterval, 30000);
      expect(configs[3].keepaliveInterval, 60000);
      expect(configs[4].keepaliveInterval, 300000);
    });

    // ==================== JSON 序列化测试 ====================
    test('Given SshConfig, When serializing to JSON, Then produces correct JSON',
        () {
      final config = SshConfig(keepaliveInterval: 45000);

      final json = config.toJson();

      expect(json['keepaliveInterval'], 45000);
    });

    test('Given valid JSON, When deserializing, Then creates SshConfig correctly',
        () {
      final json = {'keepaliveInterval': 15000};

      final config = SshConfig.fromJson(json);

      expect(config.keepaliveInterval, 15000);
    });

    test(
        'Given JSON with missing keepaliveInterval, When deserializing, Then uses default value',
        () {
      final json = <String, dynamic>{};

      final config = SshConfig.fromJson(json);

      expect(config.keepaliveInterval, 30000);
    });

    test(
        'Given JSON with null keepaliveInterval, When deserializing, Then uses default value',
        () {
      final json = {'keepaliveInterval': null};

      final config = SshConfig.fromJson(json);

      expect(config.keepaliveInterval, 30000);
    });

    test(
        'Given SshConfig, When serializing and deserializing, Then preserves keepaliveInterval',
        () {
      final original = SshConfig(keepaliveInterval: 20000);

      final json = original.toJson();
      final deserialized = SshConfig.fromJson(json);

      expect(deserialized.keepaliveInterval, original.keepaliveInterval);
    });

    test(
        'Given SshConfig, When converting to JSON and back, Then maintains equality',
        () {
      final original = SshConfig(keepaliveInterval: 42000);

      final json = original.toJson();
      final roundTrip = SshConfig.fromJson(json);

      expect(roundTrip.keepaliveInterval, original.keepaliveInterval);
    });

    test(
        'Given multiple round-trip conversions, When serializing and deserializing repeatedly, Then maintains data integrity',
        () {
      final original = SshConfig(keepaliveInterval: 55000);

      var current = original;
      for (var i = 0; i < 5; i++) {
        final json = current.toJson();
        current = SshConfig.fromJson(json);
      }

      expect(current.keepaliveInterval, original.keepaliveInterval);
    });

    // ==================== copyWith 方法测试 ====================
    test(
        'Given original config, When calling copyWith with new keepaliveInterval, Then updates only specified field',
        () {
      final original = SshConfig(keepaliveInterval: 30000);

      final modified = original.copyWith(keepaliveInterval: 60000);

      expect(modified.keepaliveInterval, 60000);
      expect(original.keepaliveInterval, 30000);
    });

    test(
        'Given original config, When calling copyWith with no arguments, Then preserves all fields',
        () {
      final original = SshConfig(keepaliveInterval: 25000);

      final copy = original.copyWith();

      expect(copy.keepaliveInterval, original.keepaliveInterval);
    });

    test(
        'Given multiple copyWith operations, When chaining modifications, Then applies all changes',
        () {
      final original = SshConfig(keepaliveInterval: 10000);
      final step1 = original.copyWith(keepaliveInterval: 20000);
      final step2 = step1.copyWith(keepaliveInterval: 30000);

      expect(original.keepaliveInterval, 10000);
      expect(step1.keepaliveInterval, 20000);
      expect(step2.keepaliveInterval, 30000);
    });

    test(
        'Given default config, When calling copyWith, Then creates independent copy',
        () {
      final defaultConfig = SshConfig.defaultConfig;
      final modified = defaultConfig.copyWith(keepaliveInterval: 50000);

      expect(defaultConfig.keepaliveInterval, 30000);
      expect(modified.keepaliveInterval, 50000);
    });

    test(
        'Given copyWith with same value, When creating new instance, Then creates new object with same value',
        () {
      final original = SshConfig(keepaliveInterval: 40000);
      final copy = original.copyWith(keepaliveInterval: 40000);

      expect(copy.keepaliveInterval, original.keepaliveInterval);
      expect(identical(copy, original), isFalse);
    });

    // ==================== defaultConfig 静态属性测试 ====================
    test('Given SshConfig, When accessing defaultConfig, Then returns default config',
        () {
      final defaultConfig = SshConfig.defaultConfig;

      expect(defaultConfig, isA<SshConfig>());
      expect(defaultConfig.keepaliveInterval, 30000);
    });

    test(
        'Given multiple accesses to defaultConfig, When called repeatedly, Then returns consistent values',
        () {
      final config1 = SshConfig.defaultConfig;
      final config2 = SshConfig.defaultConfig;

      expect(config1.keepaliveInterval, config2.keepaliveInterval);
      expect(config1.keepaliveInterval, 30000);
    });

    test(
        'Given defaultConfig, When modifying via copyWith, Then does not affect original defaultConfig',
        () {
      final defaultConfig = SshConfig.defaultConfig;
      final modified = defaultConfig.copyWith(keepaliveInterval: 99999);

      expect(SshConfig.defaultConfig.keepaliveInterval, 30000);
      expect(modified.keepaliveInterval, 99999);
    });

    // ==================== 对象相等性和 hashCode 测试 ====================
    test(
        'Given two configs with same keepaliveInterval, When comparing, Then they have same properties',
        () {
      final config1 = SshConfig(keepaliveInterval: 25000);
      final config2 = SshConfig(keepaliveInterval: 25000);

      expect(config1.keepaliveInterval, config2.keepaliveInterval);
    });

    test(
        'Given two configs with different keepaliveInterval, When comparing, Then they have different properties',
        () {
      final config1 = SshConfig(keepaliveInterval: 25000);
      final config2 = SshConfig(keepaliveInterval: 35000);

      expect(config1.keepaliveInterval, isNot(equals(config2.keepaliveInterval)));
    });

    // ==================== 极端场景测试 ====================
    test(
        'Given extreme keepaliveInterval values, When creating configs, Then handles edge cases correctly',
        () {
      final edgeCases = [
        SshConfig(keepaliveInterval: 0), // 禁用
        SshConfig(keepaliveInterval: 1), // 最小正值
        SshConfig(keepaliveInterval: 2147483647), // int 最大值
      ];

      expect(edgeCases[0].keepaliveInterval, 0);
      expect(edgeCases[1].keepaliveInterval, 1);
      expect(edgeCases[2].keepaliveInterval, 2147483647);
    });

    test(
        'Given typical use case values, When creating configs, Then handles common scenarios',
        () {
      final typicalValues = [
        SshConfig(keepaliveInterval: 10000), // 10 秒
        SshConfig(keepaliveInterval: 30000), // 30 秒（默认）
        SshConfig(keepaliveInterval: 60000), // 1 分钟
        SshConfig(keepaliveInterval: 300000), // 5 分钟
      ];

      expect(typicalValues[0].keepaliveInterval, 10000);
      expect(typicalValues[1].keepaliveInterval, 30000);
      expect(typicalValues[2].keepaliveInterval, 60000);
      expect(typicalValues[3].keepaliveInterval, 300000);
    });

    // ==================== JSON 完整性测试 ====================
    test(
        'Given complex JSON scenario, When serializing and deserializing, Then maintains data consistency',
        () {
      final original = SshConfig(keepaliveInterval: 12345);

      final json = original.toJson();
      
      // 验证 JSON 结构
      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('keepaliveInterval'), isTrue);
      expect(json['keepaliveInterval'], equals(12345));

      final deserialized = SshConfig.fromJson(json);
      expect(deserialized.keepaliveInterval, original.keepaliveInterval);
    });

    test(
        'Given JSON with extra unknown fields, When deserializing, Then ignores unknown fields',
        () {
      final json = {
        'keepaliveInterval': 20000,
        'unknownField': 'should be ignored',
        'anotherUnknown': 123,
      };

      final config = SshConfig.fromJson(json);

      expect(config.keepaliveInterval, 20000);
    });
  });
}
