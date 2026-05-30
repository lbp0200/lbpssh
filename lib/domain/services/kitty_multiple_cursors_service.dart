import 'dart:async';

import 'terminal_service.dart';

/// 光标操作类型
enum CursorOperation {
  insert, // 插入光标
  select, // 选择光标
  move, // 移动光标
  delete, // 删除光标
  clear, // 清除所有光标
}

/// 虚拟光标
class VirtualCursor {
  final String id;
  final int x;
  final int y;
  final bool selected;

  const VirtualCursor({
    required this.id,
    required this.x,
    required this.y,
    this.selected = false,
  });
}

/// 多光标服务
///
/// 实现终端多光标编辑功能
class KittyMultipleCursorsService {
  final TerminalSession? _session;

  // 当前光标列表
  final List<VirtualCursor> _cursors = [];
  int _cursorCounter = 0;

  KittyMultipleCursorsService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 获取当前光标列表
  List<VirtualCursor> get cursors => List.unmodifiable(_cursors);

  /// 插入一个新光标
  ///
  /// [x] - X 坐标
  /// [y] - Y 坐标
  /// [select] - 是否选择模式
  Future<String> insertCursor(int x, int y, {bool select = false}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cursorId = 'c${++_cursorCounter}';

    // OSC 6 > ; cursor ; id=xxx ; x=x ; y=y ; s=select
    String cmd = '\x1b[6>cursor;id=$cursorId;x=$x;y=$y';
    if (select) cmd += ';s=1';
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);

    _cursors.add(VirtualCursor(id: cursorId, x: x, y: y, selected: select));

    return cursorId;
  }

  /// 移动光标
  ///
  /// [cursorId] - 光标 ID
  /// [x] - 新 X 坐标
  /// [y] - 新 Y 坐标
  Future<void> moveCursor(String cursorId, int x, int y) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; x=x ; y=y
    final cmd = '\x1b[6>cursor;id=$cursorId;x=$x;y=$y\x1b\\\\';
    _session.writeRaw(cmd);

    // 更新本地状态
    final index = _cursors.indexWhere((c) => c.id == cursorId);
    if (index >= 0) {
      _cursors[index] = VirtualCursor(
        id: cursorId,
        x: x,
        y: y,
        selected: _cursors[index].selected,
      );
    }
  }

  /// 选择光标区域
  ///
  /// [cursorId] - 光标 ID
  /// [select] - 是否选择
  Future<void> selectCursor(String cursorId, bool select) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; s=select
    final cmd = '\x1b[6>cursor;id=$cursorId;s=${select ? "1" : "0"}\x1b\\\\';
    _session.writeRaw(cmd);

    // 更新本地状态
    final index = _cursors.indexWhere((c) => c.id == cursorId);
    if (index >= 0) {
      _cursors[index] = VirtualCursor(
        id: cursorId,
        x: _cursors[index].x,
        y: _cursors[index].y,
        selected: select,
      );
    }
  }

  /// 删除光标
  ///
  /// [cursorId] - 光标 ID
  Future<void> deleteCursor(String cursorId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; d=1
    final cmd = '\x1b[6>cursor;id=$cursorId;d=1\x1b\\\\';
    _session.writeRaw(cmd);

    _cursors.removeWhere((c) => c.id == cursorId);
  }

  /// 清除所有光标
  Future<void> clearAllCursors() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; d=*
    const cmd = '\x1b[6>cursor;d=*\x1b\\\\';
    _session.writeRaw(cmd);

    _cursors.clear();
  }

  /// 获取光标位置
  ///
  /// [cursorId] - 光标 ID
  VirtualCursor? getCursor(String cursorId) {
    try {
      return _cursors.firstWhere((c) => c.id == cursorId);
    } catch (_) {
      return null;
    }
  }

  /// 激活光标
  ///
  /// [cursorId] - 光标 ID
  Future<void> activateCursor(String cursorId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; a=1
    final cmd = '\x1b[6>cursor;id=$cursorId;a=1\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 停用光标
  ///
  /// [cursorId] - 光标 ID
  Future<void> deactivateCursor(String cursorId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; a=0
    final cmd = '\x1b[6>cursor;id=$cursorId;a=0\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置光标形状
  ///
  /// [cursorId] - 光标 ID
  /// [shape] - 形状 (bar, block, underline)
  Future<void> setCursorShape(String cursorId, String shape) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 6 > ; cursor ; id=xxx ; shape=shape
    final cmd = '\x1b[6>cursor;id=$cursorId;shape=$shape\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 处理多光标响应
  void handleResponse(String response) {
    try {
      // 解析 OSC 6 > 响应
      if (response.startsWith('6>cursor;')) {
        final parts = response.substring(9).split(';');
        String? id;
        int? x;
        int? y;
        bool? selected;

        for (final part in parts) {
          final kv = part.split('=');
          if (kv.length != 2) continue;

          switch (kv[0]) {
            case 'id':
              id = kv[1];
              break;
            case 'x':
              x = int.tryParse(kv[1]);
              break;
            case 'y':
              y = int.tryParse(kv[1]);
              break;
            case 's':
              selected = kv[1] == '1';
              break;
          }
        }

        if (id != null && x != null && y != null) {
          final index = _cursors.indexWhere((c) => c.id == id);
          if (index >= 0) {
            _cursors[index] = VirtualCursor(
              id: id,
              x: x,
              y: y,
              selected: selected ?? _cursors[index].selected,
            );
          } else {
            _cursors.add(
              VirtualCursor(id: id, x: x, y: y, selected: selected ?? false),
            );
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }
}
