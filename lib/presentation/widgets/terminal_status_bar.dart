import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/terminal_service.dart';
import '../../domain/services/ssh_service.dart';

/// 终端状态栏组件
/// 显示连接状态、延迟、连接时长和服务器信息
class TerminalStatusBar extends StatefulWidget {
  final TerminalSession session;
  final VoidCallback? onReconnect;

  const TerminalStatusBar({
    super.key,
    required this.session,
    this.onReconnect,
  });

  @override
  State<TerminalStatusBar> createState() => _TerminalStatusBarState();
}

class _TerminalStatusBarState extends State<TerminalStatusBar> {
  Timer? _durationTimer;
  Duration _connectionDuration = Duration.zero;
  final String _latency = '--';

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
    // 初始化时同步当前状态
    _syncInitialState();
  }

  void _syncInitialState() {
    if (widget.session.connectionStartTime != null) {
      _connectionDuration = DateTime.now()
          .difference(widget.session.connectionStartTime!);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.session.connectionStartTime != null && mounted) {
        setState(() {
          _connectionDuration = DateTime.now()
              .difference(widget.session.connectionStartTime!);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.session.connectionState ==
        SshConnectionState.connected;
    final isConnecting = widget.session.connectionState ==
        SshConnectionState.connecting;
    final isDisconnected = widget.session.connectionState ==
        SshConnectionState.disconnected ||
        widget.session.connectionState == SshConnectionState.error;

    // 颜色方案 - Linear 风格
    final indicatorColor = isConnecting
        ? LinearColors.warning
        : isConnected
            ? LinearColors.success
            : isDisconnected
                ? LinearColors.error
                : LinearColors.accent; // 本地终端

    final statusText = widget.session.isLocal
        ? 'Local'
        : isConnecting
            ? 'Connecting...'
            : isConnected
                ? 'Connected'
                : 'Disconnected';

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: LinearColors.panel.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: LinearColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.spacing8),
      child: Row(
        children: [
          // 状态指示器
          Container(
            width: LinearSpacing.spacing8,
            height: LinearSpacing.spacing8,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: LinearSpacing.spacing4 + 2),
          Text(
            statusText,
            style: const TextStyle(
              color: LinearColors.textPrimary,
              fontSize: 12,
            ),
          ),
          // 延迟（仅 SSH 连接显示）
          if (!widget.session.isLocal && isConnected) ...[
            const SizedBox(width: LinearSpacing.spacing8),
            Text(
              '• $_latency',
              style: const TextStyle(
                color: LinearColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
          // 连接时长
          if (isConnected || isDisconnected) ...[
            const SizedBox(width: LinearSpacing.spacing8),
            Text(
              '• ${_formatDuration(_connectionDuration)}',
              style: const TextStyle(
                color: LinearColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
          // 服务器信息
          if (widget.session.serverInfo != null) ...[
            const SizedBox(width: LinearSpacing.spacing8),
            Text(
              '• ${widget.session.serverInfo}',
              style: const TextStyle(
                color: LinearColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          // 重连按钮（仅 SSH 断开时显示）
          if (isDisconnected && !widget.session.isLocal && widget.onReconnect != null)
            TextButton.icon(
              onPressed: widget.onReconnect,
              icon: const Icon(Icons.refresh, size: 14, color: LinearColors.textTertiary),
              label: const Text('Reconnect', style: TextStyle(fontSize: 12, color: LinearColors.textTertiary)),
              style: TextButton.styleFrom(
                foregroundColor: LinearColors.textTertiary,
                padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.spacing8),
                minimumSize: Size.zero,
              ),
            ),
        ],
      ),
    );
  }
}
