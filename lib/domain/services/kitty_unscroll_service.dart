import 'dart:async';

import 'terminal_service.dart';

/// 滚动方向
enum ScrollDirection {
  up,
  down,
  pageUp,
  pageDown,
  home,
  end,
}

/// 滚动模式
enum ScrollMode {
  smooth,    // 平滑滚动
  jump,      // 跳跃滚动
}

/// 滚动回调
typedef ScrollCallback = void Function(ScrollDirection direction, int? amount);

/// Unscroll 服务
///
/// 实现终端滚动控制功能
class KittyUnscrollService {
  final TerminalSession? _session;

  // 回调
  ScrollCallback? onScroll;

  KittyUnscrollService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 向上滚动
  ///
  /// [lines] - 滚动行数
  Future<void> scrollUp({int lines = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI lines S - 向上滚动
    final cmd = '\x1b[${lines}S';
    _session.writeRaw(cmd);
  }

  /// 向下滚动
  ///
  /// [lines] - 滚动行数
  Future<void> scrollDown({int lines = 1}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI lines T - 向下滚动
    final cmd = '\x1b[${lines}T';
    _session.writeRaw(cmd);
  }

  /// 向上翻页
  Future<void> pageUp() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 获取终端行数并向上滚动
    // 这里简化处理，实际可能需要先查询终端尺寸
    _session.writeRaw('\x1b[5~');
  }

  /// 向下翻页
  Future<void> pageDown() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw('\x1b[6~');
  }

  /// 滚动到顶部
  Future<void> scrollToTop() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI H - 光标移动到首页
    _session.writeRaw('\x1b[H');
  }

  /// 滚动到底部
  Future<void> scrollToBottom() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 发送 End 键
    _session.writeRaw('\x1b[F');
  }

  /// 滚动到指定行
  ///
  /// [line] - 行号
  Future<void> scrollToLine(int line) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI line H - 移动到指定行
    final cmd = '\x1b[${line}H';
    _session.writeRaw(cmd);
  }

  /// 保存滚动位置
  Future<void> saveScrollPosition() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // ESC 7 - 保存光标位置 (包含滚动位置)
    _session.writeRaw('\x1b7');
  }

  /// 恢复滚动位置
  Future<void> restoreScrollPosition() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // ESC 8 - 恢复光标位置
    _session.writeRaw('\x1b8');
  }

  /// 设置滚动区域
  ///
  /// [startLine] - 起始行
  /// [endLine] - 结束行
  Future<void> setScrollRegion(int startLine, int endLine) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI startLine ; endLine r - 设置滚动区域
    final cmd = '\x1b[$startLine;${endLine}r';
    _session.writeRaw(cmd);
  }

  /// 重置滚动区域
  Future<void> resetScrollRegion() async {
    await setScrollRegion(1, 0); // 0 表示终端最大行
  }

  /// 启用平滑滚动
  Future<void> enableSmoothScroll() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 2026 ; smooth=1
    final cmd = '\x1b]2026;smooth=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 禁用平滑滚动
  Future<void> disableSmoothScroll() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 2026 ; smooth=0
    final cmd = '\x1b]2026;smooth=0\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询滚动位置
  Future<void> queryScrollPosition() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 2026 ; ?
    final cmd = '\x1b]2026;?\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理滚动响应
  void handleScrollResponse(String response) {
    try {
      if (response.startsWith('2026;')) {
        final parts = response.substring(5).split(';');
        if (parts.isNotEmpty && parts[0] == 'scroll') {
          // 解析滚动位置
          for (final part in parts) {
            if (part.startsWith('position=')) {
              // TODO: 使用 position 值触发滚动回调
              // final position = int.tryParse(part.substring(9));
              // 触发回调
              if (onScroll != null) {
                // 这里只是示例，实际需要根据响应内容判断方向
              }
            }
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }
}
