import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kterm/kterm.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

import '../providers_riverpod/app_config_provider_riverpod.dart';
import '../providers_riverpod/connection_provider_riverpod.dart';
import '../providers_riverpod/terminal_provider_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/models/terminal_config.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/kitty_file_transfer_service.dart';
import 'error_dialog.dart';
import 'error_detail_dialog.dart';
import 'terminal_theme_builder.dart';
import 'graphics_overlay.dart';
import 'terminal_status_bar.dart';

/// 终端视图组件
class TerminalViewWidget extends ConsumerStatefulWidget {
  final String sessionId;

  const TerminalViewWidget({super.key, required this.sessionId});

  @override
  ConsumerState<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends ConsumerState<TerminalViewWidget> {
  StreamSubscription<({String title, String body})>? _notificationSubscription;
  String? _subscribedSessionId;

  void _subscribeToNotifications(TerminalSession session) {
    if (_subscribedSessionId == session.id) return;
    _notificationSubscription?.cancel();
    _subscribedSessionId = session.id;
    _notificationSubscription = session.notificationStream.listen((
      notification,
    ) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notification.title}\n${notification.body}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _handleFileDrop(List<XFile> files) async {
    if (files.isEmpty) return;

    // 获取 TerminalSession
    final terminalNotifier = ref.read(terminalProvider.notifier);
    final session = terminalNotifier.getSession(widget.sessionId);

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先连接到服务器')));
      }
      return;
    }

    // 创建文件传输服务
    final transferService = KittyFileTransferService(session: session);

    // 上传每个文件
    for (final file in files) {
      try {
        await transferService.sendFile(
          localPath: file.path,
          remoteFileName: file.name,
          onProgress: (progress) {
            // 可以在这里显示进度
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${file.name} 上传成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${file.name} 上传失败: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 TerminalProvider 获取 session
    final activeSession = ref.watch(terminalProvider).activeSession;

    if (activeSession == null) {
      return const Center(child: Text('请选择一个连接'));
    }

    // Subscribe to notification stream for the active session
    _subscribeToNotifications(activeSession);

    // 监听 TerminalConfig
    final config = ref.watch(terminalConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return _TerminalDropTarget(
          onDrop: _handleFileDrop,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: _TerminalViewWithSelection(
              terminal: activeSession.terminal,
              controller: activeSession.controller,
              config: config,
            ),
          ),
        );
      },
    );
  }
}

/// 拖放区域组件 - 管理自己的拖动状态
/// 避免拖动事件导致整个终端树重建
class _TerminalDropTarget extends StatefulWidget {
  final Widget child;
  final void Function(List<XFile> files) onDrop;

  const _TerminalDropTarget({required this.child, required this.onDrop});

  @override
  State<_TerminalDropTarget> createState() => _TerminalDropTargetState();
}

class _TerminalDropTargetState extends State<_TerminalDropTarget> {
  bool _isDragging = false;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) {
        if (!mounted) return;
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (!mounted) return;
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        if (!mounted) return;
        setState(() => _isDragging = false);
        widget.onDrop(details.files);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Positioned.fill(
              key: _overlayKey,
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '释放以上传文件到服务器',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 带选择复制功能的 TerminalView 包装器
class _TerminalViewWithSelection extends StatefulWidget {
  final Terminal terminal;
  final TerminalController controller;
  final TerminalConfig config;

  const _TerminalViewWithSelection({
    required this.terminal,
    required this.controller,
    required this.config,
  });

  @override
  State<_TerminalViewWithSelection> createState() =>
      _TerminalViewWithSelectionState();
}

class _TerminalViewWithSelectionState
    extends State<_TerminalViewWithSelection> {
  String? _lastSelection;

  // 字体度量缓存 - 避免每帧重建 Paragraph
  String? _cachedFontFamily;
  double? _cachedFontSize;
  double? _cachedLineHeight;
  double _cachedCellWidth = 10; // fallback 默认值
  double _cachedCellHeight = 18;

  @override
  void initState() {
    super.initState();
    // 监听选择变化，自动复制到剪贴板
    widget.controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final selection = widget.controller.selection;
    if (selection != null) {
      final selectedText = widget.terminal.buffer.getText(selection);
      // 只有当选中文本发生变化时才复制到剪贴板
      if (selectedText != _lastSelection && selectedText.isNotEmpty) {
        _lastSelection = selectedText;
        Clipboard.setData(ClipboardData(text: selectedText));
      }
    } else {
      _lastSelection = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final graphicsManager = widget.terminal.graphicsManager;

    // 使用与 kterm TerminalPainter._measureCharSize() 完全相同的计算方式
    // 这样 GraphicsOverlayWidget 中的图片位置与终端字符单元格精确对齐
    final fontFamily = widget.config.fontFamily.isEmpty
        ? 'Menlo'
        : widget.config.fontFamily;

    // 缓存字体度量，避免每帧重建 ui.Paragraph
    if (_cachedFontFamily != fontFamily ||
        _cachedFontSize != widget.config.fontSize ||
        _cachedLineHeight != widget.config.lineHeight) {
      _cachedFontFamily = fontFamily;
      _cachedFontSize = widget.config.fontSize;
      _cachedLineHeight = widget.config.lineHeight;

      final textStyle = TextStyle(
        fontSize: widget.config.fontSize,
        fontFamily: fontFamily,
        height: widget.config.lineHeight,
      );

      // 使用 10 个 'm' 字符测量，与 kterm 内部逻辑一致
      const measureChars = 'mmmmmmmmmm';
      final fontWidth = _measureCharWidth(textStyle, measureChars.length);
      final fontHeight = _measureCharHeight(textStyle);

      // kterm 内部使用 maxIntrinsicWidth / 10 来计算 cellWidth
      _cachedCellWidth = fontWidth / measureChars.length;
      _cachedCellHeight = fontHeight;
    }
    final cellWidth = _cachedCellWidth;
    final cellHeight = _cachedCellHeight;

    return Stack(
      children: [
        RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TerminalView(
              widget.terminal,
              key: ValueKey(
                'terminal_${widget.config.fontSize}_${widget.config.fontFamily}',
              ),
              controller: widget.controller,
              autofocus: true,
              showSearchBar: true,
              keyboardType: TextInputType.text,
              textStyle: TerminalStyle(
                fontSize: widget.config.fontSize,
                fontFamily: fontFamily,
                height: widget.config.lineHeight,
              ),
              theme: terminalThemeFromConfig(widget.config),
            ),
          ),
        ),
        GraphicsOverlayWidget(
          graphicsManager: graphicsManager,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          scrollOffset: 0,
        ),
      ],
    );
  }

  /// 测量字符宽度（与 kterm TerminalPainter._measureCharSize 相同逻辑）
  double _measureCharWidth(TextStyle style, int charCount) {
    final paragraph = _buildParagraph(style, 'm' * charCount);
    final width = paragraph.maxIntrinsicWidth;
    paragraph.dispose();
    return width;
  }

  /// 测量字符高度（与 kterm TerminalPainter._measureCharSize 相同逻辑）
  double _measureCharHeight(TextStyle style) {
    final paragraph = _buildParagraph(style, 'm');
    final height = paragraph.height;
    paragraph.dispose();
    return height;
  }

  ui.Paragraph _buildParagraph(TextStyle style, String text) {
    final builder = ui.ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(
      style.getTextStyle(),
    );
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    return paragraph;
  }
}

/// 终端标签页视图
class TerminalTabsView extends ConsumerWidget {
  const TerminalTabsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentState = ref.watch(terminalProvider);
    final sessions = currentState.sessions;
    final activeSessionId = currentState.activeSessionId;
    final connections = ref.watch(connectionProvider).connections;
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal,
              size: 64,
              color: LinearColors.textPrimary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Text(
              '点击左侧连接以打开终端',
              style: theme.textTheme.titleMedium?.copyWith(
                color: LinearColors.textTertiary,
              ),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Container(
              decoration: BoxDecoration(
                color: LinearColors.fillSurface,
                borderRadius: BorderRadius.circular(LinearRadius.standard),
                border: Border.all(color: LinearColors.borderSolid),
              ),
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(terminalProvider.notifier)
                        .createLocalTerminal();
                  } catch (e, stackTrace) {
                    if (context.mounted) {
                      showErrorDialog(
                        context,
                        title: '创建终端失败',
                        error: e,
                        stackTrace: stackTrace,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('创建本地终端'),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 标签页栏
        Container(
          height: 48,
          decoration: const BoxDecoration(color: LinearColors.panel),
          child: Row(
            children: [
              // 标签列表
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = session.id == activeSessionId;

                    return _TerminalTab(
                      session: session,
                      isActive: isActive,
                      onTap: () => ref
                          .read(terminalProvider.notifier)
                          .switchToSession(session.id),
                      onClose: () => ref
                          .read(terminalProvider.notifier)
                          .closeSession(session.id),
                    );
                  },
                ),
              ),
              // 下拉菜单按钮
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.spacing8,
                    vertical: LinearSpacing.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: LinearColors.fillSurface,
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    border: Border.all(color: LinearColors.borderSolid),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 20,
                    color: LinearColors.accentInteractive,
                  ),
                ),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[
                    PopupMenuItem(
                      value: 'local_terminal',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.computer,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Text('本地终端'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ];
                  if (connections.isEmpty) {
                    items.add(
                      PopupMenuItem(
                        value: 'no_connections',
                        enabled: false,
                        child: Text(
                          '暂无保存的连接',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  } else {
                    items.addAll(_buildConnectionItems(context, connections));
                  }
                  return items;
                },
                onSelected: (value) async {
                  if (value == 'no_connections') {
                    return;
                  }
                  if (value == 'local_terminal') {
                    try {
                      await ref
                          .read(terminalProvider.notifier)
                          .createLocalTerminal();
                    } catch (e, stackTrace) {
                      if (context.mounted) {
                        showErrorDialog(
                          context,
                          title: '创建终端失败',
                          error: e,
                          stackTrace: stackTrace,
                        );
                      }
                    }
                    return;
                  }
                  final connection = connections.firstWhere(
                    (c) => c.id == value,
                  );
                  final terminalNotifier = ref.read(terminalProvider.notifier);
                  final currentState = ref.read(terminalProvider);
                  final existingSession = currentState.sessions
                      .where((s) => s.id == connection.id)
                      .firstOrNull;

                  if (existingSession != null) {
                    terminalNotifier.switchToSession(connection.id);
                  } else {
                    try {
                      await terminalNotifier.createSession(connection);
                    } catch (e) {
                      if (context.mounted) {
                        showDialog<void>(
                          context: context,
                          builder: (context) => ErrorDetailDialog(
                            connection: connection,
                            errorMessage: e.toString(),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
        // 终端内容
        Expanded(
          child: activeSessionId != null
              ? TerminalViewWidget(sessionId: activeSessionId)
              : const SizedBox.shrink(),
        ),
        // 状态栏
        if (activeSessionId != null)
          Builder(
            builder: (context) {
              final session = sessions.firstWhere(
                (s) => s.id == activeSessionId,
                orElse: () => sessions.first,
              );
              return TerminalStatusBar(
                session: session,
                onReconnect: () async {
                  if (!context.mounted) return;
                  const snackBar = SnackBar(
                    content: Text('正在重连...'),
                    duration: Duration(seconds: 2),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);

                  try {
                    await ref
                        .read(terminalProvider.notifier)
                        .reconnectSession(session.id);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('重连失败: $e')));
                  }
                },
              );
            },
          ),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildConnectionItems(
    BuildContext context,
    List<SshConnection> connections,
  ) {
    return connections.map((connection) {
      return PopupMenuItem(
        value: connection.id,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vpn_key,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(connection.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _TerminalTab extends StatefulWidget {
  final TerminalSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TerminalTab({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<_TerminalTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: LinearDuration.fast,
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing4,
            vertical: LinearSpacing.spacing8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing12,
            vertical: LinearSpacing.spacing4,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? LinearColors.surface
                : (_isHovered ? LinearColors.fillSurface : Colors.transparent),
            borderRadius: BorderRadius.circular(LinearRadius.card),
            border: widget.isActive
                ? const Border(
                    bottom: BorderSide(
                      color: LinearColors.accentInteractive,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  widget.session.name,
                  style: TextStyle(
                    color: widget.isActive
                        ? LinearColors.textPrimary
                        : LinearColors.textTertiary,
                    fontWeight: widget.isActive
                        ? const FontWeight(510)
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: LinearSpacing.spacing8),
              AnimatedOpacity(
                opacity: _isHovered || widget.isActive ? 1.0 : 0.0,
                duration: LinearDuration.fast,
                child: InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(LinearRadius.micro),
                  child: const Padding(
                    padding: EdgeInsets.all(LinearSpacing.spacing4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: LinearColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 错误详情对话框
// ErrorDetailDialog extracted to error_detail_dialog.dart
