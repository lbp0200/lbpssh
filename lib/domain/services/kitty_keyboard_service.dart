import 'dart:async';

import 'terminal_service.dart';

/// 键盘事件类型
enum KeyboardEventType {
  keyPress,      // 按键按下
  keyRelease,    // 按键释放
  textInput,     // 文本输入
  modifier,      // 修饰键变化
}

/// 修饰键
class ModifierKeys {
  final bool shift;
  final bool alt;
  final bool ctrl;
  final bool super_; // Windows/Linux: Meta, macOS: Cmd

  const ModifierKeys({
    this.shift = false,
    this.alt = false,
    this.ctrl = false,
    this.super_ = false,
  });

  bool get isEmpty => !shift && !alt && !ctrl && !super_;
}

/// 键盘事件
class KeyboardEvent {
  final KeyboardEventType type;
  final String? key;           // 键名 (如 "a", "Enter", "F1")
  final int? keyCode;          // 键码
  final String? text;          // 文本输入
  final ModifierKeys modifiers;

  const KeyboardEvent({
    required this.type,
    this.key,
    this.keyCode,
    this.text,
    this.modifiers = const ModifierKeys(),
  });
}

/// 键盘事件回调
typedef KeyboardEventCallback = void Function(KeyboardEvent event);

/// 键盘协议服务
///
/// 通过 OSC 1, 2, 200, 201 控制序列实现键盘事件处理
class KittyKeyboardService {
  final TerminalSession? _session;

  // 回调
  KeyboardEventCallback? onKeyPress;
  KeyboardEventCallback? onKeyRelease;
  KeyboardEventCallback? onTextInput;
  KeyboardEventCallback? onModifierChange;

  KittyKeyboardService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 发送文本到终端
  ///
  /// [text] - 要发送的文本
  Future<void> sendText(String text) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 直接写入文本
    _session.writeRaw(text);
  }

  /// 发送按键
  ///
  /// [key] - 键名
  /// [modifiers] - 修饰键
  Future<void> sendKey(String key, {ModifierKeys modifiers = const ModifierKeys()}) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 构建按键序列
    String sequence = '';

    // 添加修饰键前缀
    if (modifiers.ctrl) sequence += '\x1b^';
    if (modifiers.alt) sequence += '\x1b';
    if (modifiers.shift) sequence += '\x1b';

    // 添加键名
    sequence += key;

    _session.writeRaw(sequence);
  }

  /// 发送功能键
  ///
  /// [functionNumber] - 功能键编号 (1-12)
  Future<void> sendFunctionKey(int functionNumber) async {
    if (functionNumber < 1 || functionNumber > 12) {
      throw Exception('功能键编号必须在 1-12 之间');
    }

    String key;
    switch (functionNumber) {
      case 1:
        key = 'Q'; // F1: \eOQ
        break;
      case 2:
        key = 'R'; // F2: \eOR
        break;
      case 3:
        key = 'S'; // F3: \eOS
        break;
      case 4:
        key = 'P'; // F4: \eOP
        break;
      case 5:
        key = '[15~'; // F5
        break;
      case 6:
        key = '[16~'; // F6
        break;
      case 7:
        key = '[17~'; // F7
        break;
      case 8:
        key = '[18~'; // F8
        break;
      case 9:
        key = '[20~'; // F9
        break;
      case 10:
        key = '[21~'; // F10
        break;
      case 11:
        key = '[22~'; // F11
        break;
      case 12:
        key = '[24~'; // F12
        break;
      default:
        throw Exception('功能键编号必须在 1-12 之间');
    }

    if (functionNumber <= 4) {
      // F1-F4: SS3 (\x1bO) + letter
      await sendKey('\x1bO$key');
    } else {
      // F5-F12: CSI (\x1b[) + sequence (key already includes '[', e.g. '[15~')
      await sendKey('\x1b$key');
    }
  }

  /// 发送光标键
  ///
  /// [direction] - 方向 (up, down, left, right)
  Future<void> sendCursorKey(String direction) async {
    String key;
    switch (direction.toLowerCase()) {
      case 'up':
        key = 'A';
        break;
      case 'down':
        key = 'B';
        break;
      case 'right':
        key = 'C';
        break;
      case 'left':
        key = 'D';
        break;
      default:
        throw Exception('无效的方向: $direction');
    }

    // 光标键使用 ESC [ 序列
    _session?.writeRaw('\x1b[$key');
  }

  /// 发送 Home/End
  ///
  /// [key] - Home 或 End
  Future<void> sendHomeEnd(String key) async {
    String seq;
    switch (key.toLowerCase()) {
      case 'home':
        seq = '[1~';
        break;
      case 'end':
        seq = '[4~';
        break;
      default:
        throw Exception('无效的键: $key');
    }

    _session?.writeRaw('\x1b$seq');
  }

  /// 发送 Page Up/Down
  ///
  /// [direction] - up 或 down
  Future<void> sendPageUpDown(String direction) async {
    String seq;
    switch (direction.toLowerCase()) {
      case 'up':
        seq = '[5~';
        break;
      case 'down':
        seq = '[6~';
        break;
      default:
        throw Exception('无效的方向: $direction');
    }

    _session?.writeRaw('\x1b$seq');
  }

  /// 发送 Insert
  Future<void> sendInsert() async {
    _session?.writeRaw('\x1b[2~');
  }

  /// 发送 Delete
  Future<void> sendDelete() async {
    _session?.writeRaw('\x1b[3~');
  }

  /// 发送 Tab
  Future<void> sendTab({bool shift = false}) async {
    if (shift) {
      _session?.writeRaw('\x1b[Z');
    } else {
      _session?.writeRaw('\t');
    }
  }

  /// 发送 Enter
  Future<void> sendEnter() async {
    _session?.writeRaw('\r');
  }

  /// 发送 Escape
  Future<void> sendEscape() async {
    _session?.writeRaw('\x1b');
  }

  /// 发送退格键
  Future<void> sendBackspace() async {
    _session?.writeRaw('\x7f');
  }

  /// 设置修饰键状态
  ///
  /// [modifiers] - 修饰键状态
  Future<void> setModifierKeys(ModifierKeys modifiers) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 200 ; modifier_state
    String state = '';
    if (modifiers.shift) state += 'shift+';
    if (modifiers.alt) state += 'alt+';
    if (modifiers.ctrl) state += 'ctrl+';
    if (modifiers.super_) state += 'super+';

    if (state.isNotEmpty && state.endsWith('+')) {
      state = state.substring(0, state.length - 1);
    }

    final cmd = '\x1b]200;$state\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 查询修饰键状态
  Future<void> queryModifierKeys() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // OSC 200 ; ?
    final cmd = '\x1b]200;?\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 处理键盘响应
  ///
  /// 由外部调用，解析终端返回的键盘响应
  void handleKeyboardResponse(String response) {
    try {
      // 解析 OSC 200/201 响应
      if (response.startsWith('200;')) {
        // 修饰键状态响应
        final state = response.substring(4);
        final modifiers = _parseModifiers(state);

        onModifierChange?.call(KeyboardEvent(
          type: KeyboardEventType.modifier,
          modifiers: modifiers,
        ));
      } else if (response.startsWith('201;')) {
        // 文本输入响应
        final text = response.substring(4);
        onTextInput?.call(KeyboardEvent(
          type: KeyboardEventType.textInput,
          text: text,
        ));
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// 解析修饰键状态
  ModifierKeys _parseModifiers(String state) {
    return ModifierKeys(
      shift: state.contains('shift'),
      alt: state.contains('alt'),
      ctrl: state.contains('ctrl'),
      super_: state.contains('super'),
    );
  }
}
