import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_connection.dart';

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

    final report =
        '''## 错误报告

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

    await Clipboard.setData(ClipboardData(text: report));

    setState(() {
      _copied = true;
    });

    final Uri issuesUrl = Uri.parse(
      'https://github.com/lbp0200/lbpSSH/issues/new',
    );
    if (await canLaunchUrl(issuesUrl)) {
      await launchUrl(issuesUrl, mode: LaunchMode.externalApplication);
    }

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  Future<void> _copyErrorOnly() async {
    await Clipboard.setData(ClipboardData(text: widget.errorMessage));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('错误信息已复制到剪贴板')));
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
            Container(
              padding: const EdgeInsets.all(LinearSpacing.spacing12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(LinearRadius.standard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('连接名称', widget.connection.name, theme),
                  _buildInfoRow(
                    '主机地址',
                    '${widget.connection.host}:${widget.connection.port}',
                    theme,
                  ),
                  _buildInfoRow('用户名', widget.connection.username, theme),
                  _buildInfoRow(
                    '认证方式',
                    _getAuthTypeName(widget.connection.authType),
                    theme,
                  ),
                  if (widget.connection.jumpHost != null)
                    _buildInfoRow(
                      '跳板机',
                      '${widget.connection.jumpHost!.host}:${widget.connection.jumpHost!.port}',
                      theme,
                    ),
                  if (widget.connection.socks5Proxy != null)
                    _buildInfoRow(
                      'SOCKS5 代理',
                      '${widget.connection.socks5Proxy!.host}:${widget.connection.socks5Proxy!.port}',
                      theme,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '错误信息',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LinearSpacing.spacing12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(LinearRadius.standard),
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
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionHint(String errorMessage, ThemeData theme) {
    final hint = _getSolutionHint(errorMessage);
    final isPtyError =
        errorMessage.toLowerCase().contains('pty') ||
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
          padding: const EdgeInsets.all(LinearSpacing.spacing12),
          decoration: BoxDecoration(
            color:
                (isPtyError
                        ? theme.colorScheme.errorContainer.withValues(
                            alpha: 0.1,
                          )
                        : theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ))
                    .withValues(alpha: 0.5),
            border: Border.all(
              color:
                  (isPtyError
                          ? theme.colorScheme.error.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.3))
                      .withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(LinearRadius.standard),
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
• 检查 /etc/ssh/sshd_config 中的 `PermitTTY` 设置''';
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
• 检查服务器防火墙规则
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
