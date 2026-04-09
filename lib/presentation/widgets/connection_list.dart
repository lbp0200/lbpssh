import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/ssh_connection.dart';
import '../../core/theme/app_theme.dart';
import '../providers/connection_provider.dart';
import '../screens/connection_form.dart';

class ConnectionList extends StatelessWidget {
  final void Function(SshConnection)? onConnectionTap;
  final void Function(SshConnection)? onSftpTap;
  final bool isCompact;

  const ConnectionList({
    super.key,
    this.onConnectionTap,
    this.onSftpTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              provider.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final connections = provider.filteredConnections;

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 56,
                  color: LinearColors.textPrimary.withValues(alpha: 0.2),
                ),
                const SizedBox(height: LinearSpacing.spacing16),
                Text(
                  '暂无连接配置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: LinearColors.textTertiary,
                  ),
                ),
                const SizedBox(height: LinearSpacing.spacing16),
                FilledButton.icon(
                  onPressed: () => _showConnectionForm(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加连接'),
                ),
              ],
            ),
          );
        }

        final bottomPadding = isCompact ? LinearSpacing.spacing8 : LinearSpacing.spacing24 + LinearSpacing.spacing16;
        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(top: LinearSpacing.spacing8, bottom: bottomPadding),
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                if (isCompact) {
                  return _CompactConnectionItem(
                    connection: connection,
                    onTap: () => onConnectionTap?.call(connection),
                    onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
                  );
                }
                return _ConnectionListItem(
                  connection: connection,
                  onTap: () => onConnectionTap?.call(connection),
                  onEdit: () => _showConnectionForm(context, connection),
                  onDelete: () => _deleteConnection(context, provider, connection),
                  onSftpTap: onSftpTap != null ? () => onSftpTap!(connection) : null,
                );
              },
            ),
            if (!isCompact)
              Positioned(
                bottom: LinearSpacing.spacing8,
                right: LinearSpacing.spacing8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x05ffffff),
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    border: Border.all(color: LinearColors.borderSolid),
                  ),
                  child: IconButton(
                    onPressed: () => _showConnectionForm(context, null),
                    tooltip: '添加连接',
                    icon: const Icon(Icons.add),
                    color: LinearColors.accentInteractive,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showConnectionForm(BuildContext context, SshConnection? connection) {
    Navigator.of(context).push(
      MaterialPageRoute<ConnectionFormScreen>(
        builder: (context) => ConnectionFormScreen(connection: connection),
      ),
    );
  }

  Future<void> _deleteConnection(
    BuildContext context,
    ConnectionProvider provider,
    SshConnection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: LinearColors.error),
            SizedBox(width: LinearSpacing.spacing8 + 2),
            Text('确认删除', style: TextStyle(color: LinearColors.textPrimary)),
          ],
        ),
        content: Text(
          '确定要删除连接 "${connection.name}" 吗？',
          style: const TextStyle(color: LinearColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: LinearColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接已删除')),
        );
      }
    }
  }
}

class _ConnectionListItem extends StatefulWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSftpTap;

  const _ConnectionListItem({
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onSftpTap,
  });

  @override
  State<_ConnectionListItem> createState() => _ConnectionListItemState();
}

class _ConnectionListItemState extends State<_ConnectionListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.spacing8,
        vertical: 3,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: LinearDuration.fast,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0x0Dffffff)
                : const Color(0x05ffffff),
            borderRadius: BorderRadius.circular(LinearRadius.card),
            border: Border.all(
              color: _isHovered
                  ? LinearColors.borderStandard
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadius.card),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(LinearRadius.card),
              hoverColor: LinearColors.accentInteractive.withValues(alpha: 0.08),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.spacing12,
                  vertical: LinearSpacing.spacing8 + 2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: LinearColors.accentInteractive.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                      ),
                      child: const Icon(
                        Icons.terminal,
                        color: LinearColors.accentInteractive,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: LinearSpacing.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.connection.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.connection.username}@${widget.connection.host}:${widget.connection.port}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: LinearColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSftpTap != null)
                      IconButton(
                        icon: Icon(
                          Icons.folder_copy_outlined,
                          size: 20,
                          color: LinearColors.textTertiary.withValues(alpha: 0.6),
                        ),
                        onPressed: widget.onSftpTap,
                        tooltip: 'SFTP',
                        visualDensity: VisualDensity.compact,
                      ),
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: LinearColors.textTertiary.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                size: 18,
                                color: LinearColors.textSecondary,
                              ),
                              SizedBox(width: LinearSpacing.spacing8 + 2),
                              Text('编辑', style: TextStyle(color: LinearColors.textPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: LinearColors.error),
                              SizedBox(width: LinearSpacing.spacing8 + 2),
                              Text('删除', style: TextStyle(color: LinearColors.error)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          widget.onEdit();
                        } else if (value == 'delete') {
                          widget.onDelete();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactConnectionItem extends StatelessWidget {
  final SshConnection connection;
  final VoidCallback onTap;
  final VoidCallback? onSftpTap;

  const _CompactConnectionItem({
    required this.connection,
    required this.onTap,
    this.onSftpTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '${connection.name}\n${connection.host}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(LinearRadius.standard),
            hoverColor: LinearColors.accentInteractive.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LinearSpacing.spacing8,
                horizontal: LinearSpacing.spacing8 + 2,
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LinearColors.accentInteractive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                    ),
                    child: const Icon(
                      Icons.terminal,
                      color: LinearColors.accentInteractive,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connection.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: LinearColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onSftpTap != null)
          Tooltip(
            message: 'SFTP',
            child: InkWell(
              onTap: onSftpTap,
              borderRadius: BorderRadius.circular(LinearRadius.micro),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Icon(
                  Icons.folder_copy_outlined,
                  size: 14,
                  color: LinearColors.textQuaternary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
