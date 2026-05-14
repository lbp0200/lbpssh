import 'dart:async';

import 'terminal_service.dart';

/// 超链接服务
///
/// 通过 OSC 8 控制序列实现超链接
class KittyHyperlinkService {
  final TerminalSession? _session;

  KittyHyperlinkService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 打开超链接
  ///
  /// [uri] - 链接地址
  /// [id] - 可选的链接 ID
  Future<void> openHyperlink(String uri, {String? id}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 8 ; id=xxx ; uri
    String cmd = '\x1b]8;';
    if (id != null) {
      cmd += 'id=$id;';
    }
    cmd += uri;
    cmd += '\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 关闭超链接
  Future<void> closeHyperlink() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 8 ;
    final cmd = '\x1b]8;\x1b\\\\';
    _session.writeRaw(cmd);
  }
}

/// 鼠标指针形状服务
///
/// 通过 OSC 22 控制序列实现鼠标指针形状
class KittyPointerShapeService {
  final TerminalSession? _session;

  KittyPointerShapeService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置鼠标指针形状
  ///
  /// [shape] - 指针形状名称
  Future<void> setPointerShape(String shape) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 22 ; shape_name
    final cmd = '\x1b]22;$shape\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 重置鼠标指针形状为默认
  Future<void> resetPointerShape() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 22 ;
    final cmd = '\x1b]22;\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 常用指针形状
  static const Map<String, String> shapes = {
    'default': 'default',
    'pointer': 'pointer',
    'hand': 'hand',
    'text': 'text',
    'crosshair': 'crosshair',
    'resize-up': 'resize-up',
    'resize-down': 'resize-down',
    'resize-left': 'resize-left',
    'resize-right': 'resize-right',
    'resize-up-down': 'resize-up-down',
    'resize-left-right': 'resize-left-right',
    'not-allowed': 'not-allowed',
    'no-drop': 'no-drop',
    'grab': 'grab',
    'grabbing': 'grabbing',
    'col-resize': 'col-resize',
    'row-resize': 'row-resize',
  };
}

/// 颜色栈服务
///
/// 通过 OSC 4 和 OSC 21 控制序列实现颜色栈管理
class KittyColorStackService {
  final TerminalSession? _session;

  KittyColorStackService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 推送颜色到栈
  ///
  /// [colorSpec] - 颜色规格 (如 "rgb:ff/00/00" 或 "#ff0000")
  /// [isForeground] - true 为前景色，false 为背景色
  Future<void> pushColor(String colorSpec, {bool isForeground = true}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 4 ; id=stack_id ; color_spec
    final cmd = '\x1b]4;${isForeground ? "0" : "1"};$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 弹出颜色从栈
  ///
  /// [isForeground] - true 为前景色，false 为背景色
  Future<void> popColor({bool isForeground = true}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 4 ; id=stack_id ; -
    final cmd = '\x1b]4;${isForeground ? "0" : "1"};-\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置默认颜色
  ///
  /// [colorSpec] - 颜色规格
  /// [isForeground] - true 为前景色，false 为背景色
  Future<void> setDefaultColor(
    String colorSpec, {
    bool isForeground = true,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 4 ; color_index ; color_spec
    final cmd = '\x1b]4;${isForeground ? "0" : "1"};$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 切换颜色到原始值
  ///
  /// [isForeground] - true 为前景色，false 为背景色
  Future<void> useOriginalColor({bool isForeground = true}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 21 ; P ; r = 原始
    final cmd = '\x1b]21;P;r=${isForeground ? "10" : "11"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 交换前景色和背景色
  Future<void> swapColors() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 21 ; P ; r = 104
    final cmd = '\x1b]21;P;r=104\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 重置颜色栈
  Future<void> resetColorStack() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 4 ; r
    final cmd = '\x1b]4;r\x1b\\\\';
    _session.writeRaw(cmd);
  }
}

/// 文本大小调整服务
///
/// 通过文本大小调整协议实现终端文本大小调整
class KittyTextSizeService {
  final TerminalSession? _session;

  KittyTextSizeService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置文本大小
  ///
  /// [size] - 字体大小 (磅)
  Future<void> setTextSize(int size) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC > ; size
    final cmd = '\x1b]>$size\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询文本大小
  Future<void> queryTextSize() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC > ;
    final cmd = '\x1b]>\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 增加文本大小
  Future<void> increaseTextSize() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC > ; +
    final cmd = '\x1b]>+\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 减少文本大小
  Future<void> decreaseTextSize() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC > ; -
    final cmd = '\x1b]>-\x1b\\\\';
    _session.writeRaw(cmd);
  }
}

/// 终端标记服务
///
/// 实现终端标记功能，用于标记和查找位置
class KittyMarksService {
  final TerminalSession? _session;

  KittyMarksService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置标记
  ///
  /// [name] - 标记名称
  /// [visible] - 是否可见
  Future<void> setMark(String name, {bool visible = true}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; M ; mark_name
    final cmd = '\x1b]133;M;$name${visible ? "" : ";i"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 跳转到标记
  ///
  /// [name] - 标记名称
  Future<void> gotoMark(String name) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; G ; mark_name
    final cmd = '\x1b]133;G;$name\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 清除标记
  ///
  /// [name] - 标记名称 (为空则清除所有)
  Future<void> clearMark({String? name}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; m ; mark_name
    final cmd = '\x1b]133;m;${name ?? "*"}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 查询标记
  ///
  /// [name] - 标记名称 (为空则查询所有)
  Future<void> queryMark({String? name}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 133 ; q ; mark_name
    final cmd = '\x1b]133;q;${name ?? "*"}\x1b\\\\';
    _session.writeRaw(cmd);
  }
}

/// 窗口标题服务
///
/// 通过 OSC 0, 1, 2, 21 控制序列实现窗口标题
class KittyWindowTitleService {
  final TerminalSession? _session;

  KittyWindowTitleService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置窗口标题
  ///
  /// [title] - 窗口标题
  Future<void> setTitle(String title) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 0 ; title
    final cmd = '\x1b]0;$title\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置图标名称
  ///
  /// [name] - 图标名称
  Future<void> setIconName(String name) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 1 ; name
    final cmd = '\x1b]1;$name\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 同时设置窗口标题和图标名称
  ///
  /// [title] - 窗口标题
  /// [iconName] - 图标名称
  Future<void> setTitleAndIcon(String title, {String? iconName}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 2 ; title
    final cmd = '\x1b]2;${iconName ?? title}\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 报告窗口标题
  Future<void> reportTitle() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 21 ; t
    final cmd = '\x1b]21;t\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置窗口色
  ///
  /// [colorSpec] - 颜色规格
  Future<void> setBackgroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 11 ; color_spec
    final cmd = '\x1b]11;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }
}

/// 提示符颜色服务
///
/// 通过 OSC 10, 110, 111, 112, 130 控制序列实现提示符颜色
class KittyPromptColorService {
  final TerminalSession? _session;

  KittyPromptColorService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置前景色 (OSC 10)
  Future<void> setForegroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]10;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置背景色 (OSC 11)
  Future<void> setBackgroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]11;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置光标颜色 (OSC 12)
  Future<void> setCursorColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]12;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置鼠标指针前景色 (OSC 13)
  Future<void> setPointerForegroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]13;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置鼠标指针背景色 (OSC 14)
  Future<void> setPointerBackgroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]14;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置 Vim 高亮颜色 (OSC 17)
  Future<void> setHighlightForegroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]17;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置终端背景色 (OSC 708)
  Future<void> setTerminalBackgroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]708;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置选择前景色 (OSC 132)
  Future<void> setSelectionForegroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]132;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }

  /// 设置选择背景色 (OSC 131)
  Future<void> setSelectionBackgroundColor(String colorSpec) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final cmd = '\x1b]131;$colorSpec\x1b\\\\';
    _session.writeRaw(cmd);
  }
}
