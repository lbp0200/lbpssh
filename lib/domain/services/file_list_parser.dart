import '../../data/models/file_item.dart';

/// 远程文件解析器
/// 解析 ls -la 输出
class FileListParser {
  /// 解析 ls -la 输出
  /// 示例: drwxr-xr-x  2 user user 4096 2024-01-15 10:30 dirname
  /// macOS 示例: drwxr-xr-x  10 user  staff  352  Dec 24 11:30 dirname
  static List<FileItem> parse(
    String output,
    String currentPath, {
    String osType = 'linux',
  }) {
    final lines = output.split('\n');
    final items = <FileItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseLine(trimmed, currentPath);
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  static FileItem? _parseLine(String line, String currentPath) {
    // 跳过 total 行
    if (line.startsWith('total ')) return null;

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 8) return null;

    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');

    // 跳过 . 和 ..
    final name = parts.length >= 9 ? parts.sublist(8).join(' ') : parts[7];
    if (name == '.' || name == '..') return null;

    // 解析大小
    final size = int.tryParse(parts[4]) ?? 0;

    // 解析日期时间
    // Linux --time-style=long-iso: 权限 链接数 用户 组 大小 年-月-日 时:分 文件名
    // macOS -laT: 权限 链接数 用户 组 大小 月 日 时:分 文件名
    DateTime? modified;
    try {
      if (parts[5].contains('-') && parts[6].contains(':')) {
        // Linux 格式: 2026-02-24 20:08
        final dateParts = parts[5].split('-');
        final timeParts = parts[6].split(':');
        if (dateParts.length == 3 && timeParts.length == 2) {
          modified = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      } else {
        // macOS 格式: Dec 24 20:08
        final monthNames = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12,
        };
        final month = monthNames[parts[5]];
        final day = int.tryParse(parts[6]);
        if (month != null &&
            day != null &&
            parts.length >= 8 &&
            parts[7].contains(':')) {
          final timeParts = parts[7].split(':');
          if (timeParts.length == 2) {
            final now = DateTime.now();
            modified = DateTime(
              now.year,
              month,
              day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
          }
        }
      }
    } catch (_) {
      // 忽略解析错误
    }

    // 构建完整路径
    final fullPath = currentPath == '/' ? '/$name' : '$currentPath/$name';

    return FileItem(
      name: name,
      path: fullPath,
      isDirectory: isDirectory,
      size: size,
      modified: modified,
      permissions: permissions,
    );
  }
}
