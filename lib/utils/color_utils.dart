import 'package:flutter/material.dart';

class ColorUtils {
  /// 解析颜色字符串 (#RRGGBB 或 #AARRGGBB)
  static Color parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white;
    }
  }

  /// 颜色缓存 - 避免重复解析
  static final Map<String, Color> _colorCache = {};

  /// 使用缓存解析颜色
  static Color parseColorCached(String colorHex) {
    return _colorCache.putIfAbsent(colorHex, () => parseColor(colorHex));
  }

  /// 清除缓存（当配置变化时调用）
  static void clearCache() {
    _colorCache.clear();
  }
}
