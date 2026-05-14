import 'dart:async';

import 'terminal_service.dart';

/// 窗口布局类型
enum LayoutType {
  grid, // 网格布局
  stack, // 堆叠布局
  horizontal, // 水平布局
  vertical, // 垂直布局
  split, // 分屏布局
}

/// 窗口信息
class WindowInfo {
  final String id;
  final String? title;
  final int? width;
  final int? height;
  final int? x;
  final int? y;
  final bool isActive;

  const WindowInfo({
    required this.id,
    this.title,
    this.width,
    this.height,
    this.x,
    this.y,
    this.isActive = false,
  });
}

/// 布局配置
class LayoutConfig {
  final LayoutType type;
  final int? width;
  final int? height;
  final int? x;
  final int? y;
  final double? fraction; // 布局占比

  const LayoutConfig({
    required this.type,
    this.width,
    this.height,
    this.x,
    this.y,
    this.fraction,
  });
}

/// 布局服务
///
/// 实现终端窗口布局管理功能
class KittyLayoutService {
  final TerminalSession? _session;

  // 当前布局
  LayoutConfig _currentLayout = const LayoutConfig(type: LayoutType.grid);

  // 窗口列表
  final List<WindowInfo> _windows = [];

  KittyLayoutService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前布局
  LayoutConfig get currentLayout => _currentLayout;

  /// 获取窗口列表
  List<WindowInfo> get windows => List.unmodifiable(_windows);

  /// 设置网格布局
  ///
  /// [width] - 列数
  /// [height] - 行数
  Future<void> setGridLayout(int width, int height) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; layout=grid:width:height
    final cmd = '\x1b]20;layout=grid:$width:$height\x1b\\\\';
    _session.writeRaw(cmd);

    _currentLayout = LayoutConfig(
      type: LayoutType.grid,
      width: width,
      height: height,
    );
  }

  /// 设置堆叠布局
  Future<void> setStackLayout() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; layout=stack
    final cmd = '\x1b]20;layout=stack\x1b\\\\';
    _session.writeRaw(cmd);

    _currentLayout = const LayoutConfig(type: LayoutType.stack);
  }

  /// 设置水平布局
  ///
  /// [fraction] - 占比 (0.0-1.0)
  Future<void> setHorizontalLayout({double? fraction}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; layout=horizontal:fraction
    String cmd = '\x1b]20;layout=horizontal';
    if (fraction != null) {
      cmd += ':${fraction.toStringAsFixed(2)}';
    }
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);

    _currentLayout = LayoutConfig(
      type: LayoutType.horizontal,
      fraction: fraction,
    );
  }

  /// 设置垂直布局
  ///
  /// [fraction] - 占比 (0.0-1.0)
  Future<void> setVerticalLayout({double? fraction}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; layout=vertical:fraction
    String cmd = '\x1b]20;layout=vertical';
    if (fraction != null) {
      cmd += ':${fraction.toStringAsFixed(2)}';
    }
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);

    _currentLayout = LayoutConfig(
      type: LayoutType.vertical,
      fraction: fraction,
    );
  }

  /// 创建分屏
  ///
  /// [direction] - 方向 (h: 水平, v: 垂直)
  /// [size] - 分割大小 (像素或百分比)
  Future<void> createSplit(String direction, {int? size}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; split:direction:size
    String cmd = '\x1b]20;split:$direction';
    if (size != null) {
      cmd += ':$size';
    }
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);

    _currentLayout = const LayoutConfig(type: LayoutType.split);
  }

  /// 关闭当前分屏
  Future<void> closeSplit() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; split:close
    final cmd = '\x1b]20;split:close\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 切换到下一个窗口
  Future<void> nextWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:next
    final cmd = '\x1b]20;window:next\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 切换到上一个窗口
  Future<void> previousWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:prev
    final cmd = '\x1b]20;window:prev\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 聚焦指定窗口
  ///
  /// [windowId] - 窗口 ID
  Future<void> focusWindow(String windowId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:focus:id
    final cmd = '\x1b]20;window:focus:$windowId\x1b\\\\';
    _session.writeRaw(cmd);

    // 更新本地状态
    for (var i = 0; i < _windows.length; i++) {
      _windows[i] = WindowInfo(
        id: _windows[i].id,
        title: _windows[i].title,
        width: _windows[i].width,
        height: _windows[i].height,
        x: _windows[i].x,
        y: _windows[i].y,
        isActive: _windows[i].id == windowId,
      );
    }
  }

  /// 调整窗口大小
  ///
  /// [width] - 新宽度
  /// [height] - 新高度
  Future<void> resizeWindow(int width, int height) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:resize:width:height
    final cmd = '\x1b]20;window:resize:$width:$height\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 移动窗口位置
  ///
  /// [x] - X 坐标
  /// [y] - Y 坐标
  Future<void> moveWindow(int x, int y) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:move:x:y
    final cmd = '\x1b]20;window:move:$x:$y\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 最大化当前窗口
  Future<void> maximizeWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:maximize
    final cmd = '\x1b]20;window:maximize\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 还原窗口
  Future<void> restoreWindow() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; window:restore
    final cmd = '\x1b]20;window:restore\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询窗口列表
  Future<void> queryWindows() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; windows:?
    final cmd = '\x1b]20;windows:?\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询当前布局
  Future<void> queryLayout() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 20 ; layout:?
    final cmd = '\x1b]20;layout:?\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理布局响应
  void handleLayoutResponse(String response) {
    try {
      // 解析 OSC 20 响应
      if (response.startsWith('20;')) {
        final parts = response.substring(3).split(';');

        if (parts.isNotEmpty && parts[0].startsWith('layout=')) {
          // 布局响应
          final layout = parts[0].substring(7);
          switch (layout) {
            case 'grid':
              _currentLayout = const LayoutConfig(type: LayoutType.grid);
              break;
            case 'stack':
              _currentLayout = const LayoutConfig(type: LayoutType.stack);
              break;
            case 'horizontal':
              _currentLayout = const LayoutConfig(type: LayoutType.horizontal);
              break;
            case 'vertical':
              _currentLayout = const LayoutConfig(type: LayoutType.vertical);
              break;
          }
        } else if (parts.isNotEmpty && parts[0].startsWith('window:')) {
          // 窗口响应
          // 解析窗口列表
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }
}
