import 'dart:async';

import 'terminal_service.dart';

/// 终端模式
enum TerminalMode {
  // ANSI 模式
  cursorKeys(0, 'Application Cursor Keys (DECCKM)'),
  column132(1, '132 Columns (DECCOLM)'),
  smoothScroll(4, 'Smooth Scroll (DECSCLM)'),
  reverseVideo(5, 'Reverse Video (DECSCNM)'),
  originMode(6, 'Origin Mode (DECOM)'),
  autoWrap(7, 'Auto Wrap (DECAWM)'),
  autoRepeat(8, 'Auto Repeat (DECARM)'),
  interlace(12, 'Interlace (DECINLM)'),
  printing(17, 'Print Form Feed (DECPFF)'),
  printerExtend(18, 'Extended Print (DECPEX)'),
  cursorVisible(25, 'Visible Cursor (DECTCEM)'),
  bracketedPaste(2004, 'Bracketed Paste Mode'),
  synchronizedOutput(2022, 'Synchronized Output'),
  sixelScrolling(8452, 'Sixel Scrolling'),
  iTerm2Mouse(1000, 'iTerm2 Mouse Tracking'),
  iTerm2Highlight(1002, 'iTerm2 Mouse Highlight'),
  iTerm2Any(1005, 'iTerm2 Mouse Any'),
  sgrMouse(1006, 'SGR Mouse'),
  urxvtMouse(1015, 'URxvt Mouse'),
  sixelMode(6070, 'Sixel Mode'),
  kittyGraphics(71, 'Kitty Graphics Protocol');

  final int value;
  final String description;

  const TerminalMode(this.value, this.description);
}

/// 终端模式状态
class TerminalModeState {
  final TerminalMode mode;
  final bool isSet;

  const TerminalModeState(this.mode, this.isSet);
}

/// 终端模式服务
///
/// 通过 SM (Set Mode) 和 RM (Reset Mode) 控制序列管理终端模式
class KittyTerminalModesService {
  final TerminalSession? _session;

  // 缓存模式状态
  final Map<TerminalMode, bool> _modeState = {};

  KittyTerminalModesService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 设置模式
  ///
  /// [mode] - 要设置的终端模式
  Future<void> setMode(TerminalMode mode) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI ? Pm h - 设置模式 (DEC private mode)
    final cmd = '\x1b[?${mode.value}h';
    _session.writeRaw(cmd);
    _modeState[mode] = true;
  }

  /// 重置模式
  ///
  /// [mode] - 要重置的终端模式
  Future<void> resetMode(TerminalMode mode) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI ? Pm l - 重置模式 (DEC private mode)
    final cmd = '\x1b[?${mode.value}l';
    _session.writeRaw(cmd);
    _modeState[mode] = false;
  }

  /// 切换模式
  ///
  /// [mode] - 要切换的终端模式
  Future<void> toggleMode(TerminalMode mode) async {
    final current = _modeState[mode] ?? false;
    if (current) {
      await resetMode(mode);
    } else {
      await setMode(mode);
    }
  }

  /// 查询模式状态
  ///
  /// [mode] - 要查询的终端模式
  Future<void> queryMode(TerminalMode mode) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI ? Pm p - 查询模式状态 (DECRQM)
    final cmd = '\x1b[?${mode.value}p';
    _session.writeRaw(cmd);
  }

  /// 查询所有模式状态
  Future<void> queryAllModes() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 常见模式批量查询
    for (final mode in TerminalMode.values) {
      await queryMode(mode);
    }
  }

  /// 获取模式状态
  ///
  /// 如果本地有缓存则返回缓存值
  bool? getModeState(TerminalMode mode) => _modeState[mode];

  // === 常用模式快捷方法 ===

  /// 启用 Bracketed Paste 模式
  /// 粘贴文本时会被包裹在 ESC [200~ 和 ESC [201~ 之间
  Future<void> enableBracketedPaste() async {
    await setMode(TerminalMode.bracketedPaste);
  }

  /// 禁用 Bracketed Paste 模式
  Future<void> disableBracketedPaste() async {
    await resetMode(TerminalMode.bracketedPaste);
  }

  /// 启用 Kitty 图形协议
  Future<void> enableKittyGraphics() async {
    await setMode(TerminalMode.kittyGraphics);
  }

  /// 禁用 Kitty 图形协议
  Future<void> disableKittyGraphics() async {
    await resetMode(TerminalMode.kittyGraphics);
  }

  /// 启用鼠标追踪
  Future<void> enableMouseTracking({
    MouseTrackingMode mode = MouseTrackingMode.click,
  }) async {
    switch (mode) {
      case MouseTrackingMode.click:
        await setMode(TerminalMode.sgrMouse);
        break;
      case MouseTrackingMode.any:
        await setMode(TerminalMode.kittyGraphics);
        break;
      case MouseTrackingMode.highlight:
        await setMode(TerminalMode.iTerm2Highlight);
        break;
    }
  }

  /// 禁用鼠标追踪
  Future<void> disableMouseTracking() async {
    await resetMode(TerminalMode.iTerm2Mouse);
    await resetMode(TerminalMode.iTerm2Highlight);
    await resetMode(TerminalMode.iTerm2Any);
    await resetMode(TerminalMode.sgrMouse);
    await resetMode(TerminalMode.urxvtMouse);
  }

  /// 启用光标键应用模式
  /// 光标键发送 ESC O A/B/C/D 而不是 ESC [ A/B/C/D
  Future<void> enableApplicationCursorKeys() async {
    await setMode(TerminalMode.cursorKeys);
  }

  /// 禁用光标键应用模式
  /// 光标键发送 ESC [ A/B/C/D
  Future<void> disableApplicationCursorKeys() async {
    await resetMode(TerminalMode.cursorKeys);
  }

  /// 启用自动换行
  Future<void> enableAutoWrap() async {
    await setMode(TerminalMode.autoWrap);
  }

  /// 禁用自动换行
  Future<void> disableAutoWrap() async {
    await resetMode(TerminalMode.autoWrap);
  }

  /// 显示光标
  Future<void> showCursor() async {
    await setMode(TerminalMode.cursorVisible);
  }

  /// 隐藏光标
  Future<void> hideCursor() async {
    await resetMode(TerminalMode.cursorVisible);
  }

  /// 启用 132 列模式
  Future<void> enable132Columns() async {
    await setMode(TerminalMode.column132);
  }

  /// 禁用 132 列模式 (80 列)
  Future<void> disable132Columns() async {
    await resetMode(TerminalMode.column132);
  }

  /// 启用同步输出模式
  /// 终端会等待屏幕刷新完成再发送更多数据
  Future<void> enableSynchronizedOutput() async {
    await setMode(TerminalMode.synchronizedOutput);
  }

  /// 禁用同步输出模式
  Future<void> disableSynchronizedOutput() async {
    await resetMode(TerminalMode.synchronizedOutput);
  }

  /// 启用 Sixel 图形
  Future<void> enableSixel() async {
    await setMode(TerminalMode.sixelMode);
    await setMode(TerminalMode.sixelScrolling);
  }

  /// 禁用 Sixel 图形
  Future<void> disableSixel() async {
    await resetMode(TerminalMode.sixelMode);
    await resetMode(TerminalMode.sixelScrolling);
  }

  /// 重置所有模式到默认值
  Future<void> resetAllModes() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // CSI ! p - 软重置
    _session.writeRaw('\x1b[!p');
    _modeState.clear();
  }

  /// 硬重置终端
  Future<void> hardReset() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // RIS - Reset to Initial State
    _session.writeRaw('\x1b c');
    _session.writeRaw('\x1b]c\x1b\\\\');
    _modeState.clear();
  }

  /// 处理模式查询响应
  ///
  /// 响应格式: CSI ? Pm $y (DECRPM)
  /// Pm: 模式值
  /// $y: 状态 (0=undefined, 1=set, 2=reset)
  void handleModeResponse(String response) {
    try {
      final match = RegExp(r'\[(\?.*)\$(\w)').firstMatch(response);
      if (match == null) return;

      final modeStr = match.group(1) ?? '';
      final stateStr = match.group(2) ?? '';

      // 解析模式值
      final modeValue = int.tryParse(modeStr.replaceFirst('?', ''));
      if (modeValue == null) return;

      // 查找对应的模式
      TerminalMode? mode;
      for (final m in TerminalMode.values) {
        if (m.value == modeValue) {
          mode = m;
          break;
        }
      }

      if (mode == null) return;

      // 解析状态
      final isSet = stateStr == '1';
      _modeState[mode] = isSet;
    } catch (e) {
      // 忽略解析错误
    }
  }
}

/// 鼠标追踪模式
enum MouseTrackingMode {
  click, // 点击时发送事件
  highlight, // 高亮时发送事件
  any, // 任何移动都发送事件
}
