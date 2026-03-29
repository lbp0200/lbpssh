import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kterm/kterm.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

import '../providers/app_config_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/terminal_provider.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/models/terminal_config.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/kitty_file_transfer_service.dart';
import '../../utils/color_utils.dart';
import 'error_dialog.dart';
import 'graphics_overlay.dart';
import 'terminal_status_bar.dart';

/// 终端视图组件
class TerminalViewWidget extends StatefulWidget {
  final String sessionId;

  const TerminalViewWidget({super.key, required this.sessionId});

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  StreamSubscription<({String title, String body})>? _notificationSubscription;
  String? _subscribedSessionId;
  bool _isDragging = false;

  void _subscribeToNotifications(TerminalSession session) {
    if (_subscribedSessionId == session.id) return;
    _notificationSubscription?.cancel();
    _subscribedSessionId = session.id;
    _notificationSubscription = session.notificationStream.listen((notification) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notification.title}\n${notification.body}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _handleFileDrop(List<XFile> files) async {
    if (files.isEmpty) return;

    // 获取 TerminalSession
    final terminalProvider = context.read<TerminalProvider>();
    final session = terminalProvider.getSession(widget.sessionId);

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先连接到服务器')),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} 上传成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} 上传失败: $e')),
          );
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
    // 先监听 TerminalProvider 获取 session
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, child) {
        final session = terminalProvider.activeSession;

        if (session == null) {
          return const Center(child: Text('请选择一个连接'));
        }

        // Subscribe to notification stream for the active session
        _subscribeToNotifications(session);

        // 再监听 AppConfigProvider 获取配置
        return Consumer<AppConfigProvider>(
          builder: (context, configProvider, child) {
            final config = configProvider.terminalConfig;

            return LayoutBuilder(
              builder: (context, constraints) {
                return DropTarget(
                  onDragEntered: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onDragExited: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onDragDone: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                    _handleFileDrop(details.files);
                  },
                  child: Stack(
                    children: [
                      SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: _TerminalViewWithSelection(
                          terminal: session.terminal,
                          controller: session.controller,
                          config: config,
                        ),
                      ),
                      // 拖拽提示覆盖层
                      if (_isDragging)
                        Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
  State<_TerminalViewWithSelection> createState() => _TerminalViewWithSelectionState();
}

class _TerminalViewWithSelectionState extends State<_TerminalViewWithSelection> {
  String? _lastSelection;

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
    final graphicsManager = widget.terminal.graphicsManager as dynamic;
    final cellWidth = widget.config.fontSize * 0.6;
    final cellHeight = widget.config.fontSize * widget.config.lineHeight;

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
              readOnly: false,
              showSearchBar: true,
              hardwareKeyboardOnly: false,
              keyboardType: TextInputType.text,
              textStyle: TerminalStyle(
                fontSize: widget.config.fontSize,
                fontFamily: widget.config.fontFamily.isEmpty ? 'Menlo' : widget.config.fontFamily,
                height: widget.config.lineHeight,
              ),
              theme: TerminalTheme(
                foreground: ColorUtils.parseColorCached(widget.config.foregroundColor),
                background: ColorUtils.parseColorCached(widget.config.backgroundColor),
                cursor: ColorUtils.parseColorCached(widget.config.cursorColor),
                selection: ColorUtils.parseColorCached(
                  widget.config.foregroundColor,
                ).withValues(alpha: 0.3),
                black: ColorUtils.parseColorCached('#000000'),
                red: ColorUtils.parseColorCached('#CD3131'),
                green: ColorUtils.parseColorCached('#0DBC79'),
                yellow: ColorUtils.parseColorCached('#E5E510'),
                blue: ColorUtils.parseColorCached('#2472C8'),
                magenta: ColorUtils.parseColorCached('#BC3FBC'),
                cyan: ColorUtils.parseColorCached('#11A8CD'),
                white: ColorUtils.parseColorCached('#E5E5E5'),
                brightBlack: ColorUtils.parseColorCached('#666666'),
                brightRed: ColorUtils.parseColorCached('#F14C4C'),
                brightGreen: ColorUtils.parseColorCached('#23D18B'),
                brightYellow: ColorUtils.parseColorCached('#F5F543'),
                brightBlue: ColorUtils.parseColorCached('#3B8EEA'),
                brightMagenta: ColorUtils.parseColorCached('#D670D6'),
                brightCyan: ColorUtils.parseColorCached('#29B8DB'),
                brightWhite: ColorUtils.parseColorCached('#E5E5E5'),
                searchHitBackground: ColorUtils.parseColorCached('#FFFF00').withValues(alpha: 0.3),
                searchHitBackgroundCurrent: ColorUtils.parseColorCached('#FFFF00').withValues(alpha: 0.5),
                searchHitForeground: ColorUtils.parseColorCached('#000000'),
              ),
            ),
          ),
        ),
        if (graphicsManager != null)
          GraphicsOverlayWidget(
            graphicsManager: graphicsManager,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            scrollOffset: 0,
          ),
      ],
    );
  }
}


/// 终端标签页视图
class TerminalTabsView extends StatelessWidget {
  const TerminalTabsView({super.key});

  Future<void> _createLocalTerminal(BuildContext context) async {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );
    try {
      await terminalProvider.createLocalTerminal();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建终端失败: $e')),
        );
      }
    }
  }

  Future<void> _handleConnectionTap(
    BuildContext context,
    SshConnection connection,
  ) async {
    final terminalProvider = Provider.of<TerminalProvider>(
      context,
      listen: false,
    );

    final existingSession =
        terminalProvider.sessions.where((s) => s.id == connection.id).firstOrNull;

    if (existingSession != null) {
      terminalProvider.switchToSession(connection.id);
    } else {
      try {
        // createSession now auto-connects
        await terminalProvider.createSession(connection);
      } catch (e) {
        if (context.mounted) {
          _showErrorDialog(context, connection, e.toString());
        }
      }
    }
  }

  /// 显示错误详情对话框
  void _showErrorDialog(
    BuildContext context,
    SshConnection connection,
    String errorMessage,
  ) {
    showDialog(
      context: context,
      builder: (context) => ErrorDetailDialog(
        connection: connection,
        errorMessage: errorMessage,
      ),
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
              child: Text(
                connection.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TerminalProvider, ConnectionProvider>(
      builder: (context, terminalProvider, connProvider, child) {
        final sessions = terminalProvider.sessions;
        final activeSessionId = terminalProvider.activeSessionId;
        final connections = connProvider.connections;

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.terminal,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '点击左侧连接以打开终端',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await terminalProvider.createLocalTerminal();
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
              ],
            ),
          );
        }

        return Column(
          children: [
            // 标签页栏
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
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
                          onTap: () => terminalProvider.switchToSession(session.id),
                          onClose: () => terminalProvider.closeSession(session.id),
                        );
                      },
                    ),
                  ),
                  // 下拉菜单按钮
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
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
                        items.add(PopupMenuItem(
                          value: 'no_connections',
                          enabled: false,
                          child: Text(
                            '暂无保存的连接',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ));
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
                        await _createLocalTerminal(context);
                        return;
                      }
                      final connection = connections.firstWhere((c) => c.id == value);
                      await _handleConnectionTap(context, connection);
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
                    onReconnect: () {
                      // TODO: 实现重连功能
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reconnecting...')),
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// 终端标签页
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
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter to select tab
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          // Escape or W with Ctrl to close
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              (event.logicalKey == LogicalKeyboardKey.keyW &&
                  HardwareKeyboard.instance.isControlPressed)) {
            widget.onClose();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: '终端标签页: ${widget.session.name}${widget.isActive ? ", 当前激活" : ""}',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                border: Border(
                  bottom: BorderSide(
                    color: widget.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      widget.session.name,
                      style: TextStyle(
                        fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: '关闭标签页 ${widget.session.name}',
                    button: true,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          // 阻止事件冒泡，避免触发父级的 onTap
                          widget.onClose();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 错误详情对话框
class ErrorDetailDialog extends StatefulWidget {
  final SshConnection connection;
  final String errorMessage;

  const ErrorDetailDialog({
    super.key,
    required this.connection,
    required this.errorMessage,
  });

  @override
  State<ErrorDetailDialog> createState() => _ErrorDetailDialogState();
}

class _ErrorDetailDialogState extends State<ErrorDetailDialog> {
  bool _copied = false;

  Future<void> _copyAndOpenIssues() async {
    final connection = widget.connection;
    final error = widget.errorMessage;

    // 构建错误报告内容
    final report = '''## 错误报告

**连接名称**: ${connection.name}
**主机**: ${connection.host}:${connection.port}
**用户名**: ${connection.username}
**认证方式**: ${connection.authType.name}
${connection.jumpHost != null ? '**跳板机**: ${connection.jumpHost!.host}:${connection.jumpHost!.port}' : ''}
${connection.socks5Proxy != null ? '**SOCKS5 代理**: ${connection.socks5Proxy!.host}:${connection.socks5Proxy!.port}' : ''}

**错误信息**:
```
$error
```

**复现步骤**:
1. 选择连接 "${connection.name}"
2. 点击连接
3. 出现上述错误

**环境信息**:
- 操作系统: ${Platform.operatingSystem}
- 应用版本: lbpSSH''';

    // 复制到剪贴板
    await Clipboard.setData(ClipboardData(text: report));

    setState(() {
      _copied = true;
    });

    // 打开 GitHub Issues 页面
    final Uri issuesUrl = Uri.parse(
      'https://github.com/lbpCode/lbpSSH/issues/new',
    );
    if (await canLaunchUrl(issuesUrl)) {
      await launchUrl(issuesUrl, mode: LaunchMode.externalApplication);
    }

    // 3秒后重置复制状态
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  Future<void> _copyErrorOnly() async {
    await Clipboard.setData(
      ClipboardData(text: widget.errorMessage),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错误信息已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          const Text('连接失败'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 连接信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('连接名称', widget.connection.name, theme),
                  _buildInfoRow('主机地址',
                      '${widget.connection.host}:${widget.connection.port}', theme),
                  _buildInfoRow('用户名', widget.connection.username, theme),
                  _buildInfoRow('认证方式',
                      _getAuthTypeName(widget.connection.authType), theme),
                  if (widget.connection.jumpHost != null)
                    _buildInfoRow('跳板机',
                        '${widget.connection.jumpHost!.host}:${widget.connection.jumpHost!.port}', theme),
                  if (widget.connection.socks5Proxy != null)
                    _buildInfoRow('SOCKS5 代理',
                        '${widget.connection.socks5Proxy!.host}:${widget.connection.socks5Proxy!.port}', theme),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 错误信息
            Text(
              '错误信息',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.errorMessage,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 解决方案提示
            _buildSolutionHint(widget.errorMessage, theme),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _copyErrorOnly,
          icon: const Icon(Icons.content_copy),
          label: const Text('复制错误'),
        ),
        ElevatedButton.icon(
          onPressed: _copyAndOpenIssues,
          icon: _copied
              ? const Icon(Icons.check)
              : const Icon(Icons.bug_report_outlined),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          label: Text(_copied ? '已复制，前往 Issues' : '反馈问题'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionHint(String errorMessage, ThemeData theme) {
    final hint = _getSolutionHint(errorMessage);
    final isPtyError = errorMessage.toLowerCase().contains('pty') ||
        errorMessage.toLowerCase().contains('tty');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isPtyError ? Icons.computer : Icons.lightbulb_outline,
              size: 18,
              color: isPtyError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isPtyError ? '可能原因与解决方法' : '排查建议',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPtyError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isPtyError
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.3))
                .withValues(alpha: 0.5),
            border: Border.all(
              color: (isPtyError
                      ? theme.colorScheme.error.withValues(alpha: 0.3)
                      : theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            hint,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  String _getAuthTypeName(AuthType authType) {
    switch (authType) {
      case AuthType.password:
        return '密码认证';
      case AuthType.key:
        return '密钥认证';
      case AuthType.keyWithPassword:
        return '密钥+密码认证';
      case AuthType.sshConfig:
        return 'SSH Config';
    }
  }

  /// 获取特定错误的解决方案建议
  String _getSolutionHint(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('failed to start pty') ||
        lowerError.contains('pty') ||
        lowerError.contains('tty')) {
      return '''**可能原因**:
• 服务器配置了 `PermitTTY no`
• 用户没有分配伪终端的权限
• 该账户可能仅允许 SFTP 访问（无 Shell 权限）

**解决方法**:
• 联系服务器管理员检查 SSH 配置
• 确认账户是否有 Shell 访问权限
• 检查 `/etc/ssh/sshd_config` 中的 `PermitTTY` 设置''';
    }

    if (lowerError.contains('authentication failed') ||
        lowerError.contains('authenticate') ||
        lowerError.contains('permission denied')) {
      return '''**可能原因**:
• 密码/密钥验证失败
• 密钥权限不正确（应设置为 600）
• 服务器未授权该用户登录

**解决方法**:
• 确认密码或私钥是否正确
• 检查私钥文件权限: `chmod 600 ~/.ssh/id_rsa`
• 确认公钥已添加到服务器的 `~/.ssh/authorized_keys`''';
    }

    if (lowerError.contains('connection refused') ||
        lowerError.contains('network is unreachable') ||
        lowerError.contains('no route to host')) {
      return '''**可能原因**:
• SSH 服务未运行或端口错误
• 防火墙阻止了连接
• 网络不可达

**解决方法**:
• 确认主机地址和端口是否正确
• 检查服务器防火墙规则 (端口 22)
• 确认 SSH 服务正在运行''';
    }

    if (lowerError.contains('host key verification') ||
        lowerError.contains('known_hosts') ||
        lowerError.contains('key')) {
      return '''**可能原因**:
• 主机密钥验证失败
• 主机地址已更换或被攻击

**解决方法**:
• 检查是否连接到了正确的服务器
• 如确认安全，可删除 `~/.ssh/known_hosts` 中对应条目''';
    }

    return '''**排查建议**:
• 确认主机地址、端口、用户名正确
• 检查网络连接和防火墙设置
• 确认账户有 SSH 访问权限''';
  }
}
