import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/color_utils.dart';

void main() {
  group('ColorUtils Tests', () {
    test('should parse color correctly', () {
      final color = ColorUtils.parseColor('#FF5733');
      expect(color.toARGB32(), 0xFFFF5733);
    });

    test('should return white for invalid color', () {
      final color = ColorUtils.parseColor('invalid');
      expect(color, Colors.white);
    });

    test('should cache parsed colors', () {
      ColorUtils.clearCache();

      final color1 = ColorUtils.parseColorCached('#FF5733');
      final color2 = ColorUtils.parseColorCached('#FF5733');

      // 同一个对象
      expect(identical(color1, color2), isTrue);
    });

    test('should parse color efficiently', () {
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        ColorUtils.parseColor('#FF5733');
      }
      stopwatch.stop();

      // 1000 次解析应在 50ms 内完成（宽松阈值以适应 CI/慢速环境）
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('cached version should be faster', () {
      ColorUtils.clearCache();

      // 先解析一次填充缓存
      ColorUtils.parseColorCached('#FF5733');

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        ColorUtils.parseColorCached('#FF5733');
      }
      stopwatch.stop();

      // 缓存版本应该更快
      expect(stopwatch.elapsedMilliseconds, lessThan(1));
    });
  });
}
