import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_connection.dart';
import '../providers_riverpod/connection_provider_riverpod.dart';
import 'connection_form.dart';

class ConnectionManagementPage extends ConsumerWidget {
  const ConnectionManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: LinearColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部操作栏
          Padding(
            padding: const EdgeInsets.all(LinearSpacing.spacing16),
            child: Row(
              children: [
                Text(
                  '已保存的连接',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: LinearColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<ConnectionFormScreen>(
                      builder: (context) =>
                          const ConnectionFormScreen(connection: null),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加连接'),
              ),
            ],
          ),
        ),
        const Divider(),
        // 连接列表
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final provider = ref.watch(connectionProvider);
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              final connections = provider.connections;

              if (connections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: LinearColors.textTertiary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: LinearSpacing.spacing16),
                      Text(
                        '暂无连接配置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: LinearColors.textTertiary,
                            ),
                      ),
                      const SizedBox(height: LinearSpacing.spacing8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<ConnectionFormScreen>(
                              builder: (context) =>
                                  const ConnectionFormScreen(connection: null),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加第一个连接'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.spacing16),
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final connection = connections[index];
                  return _ConnectionManagementItem(connection: connection);
                },
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}

class _ConnectionManagementItem extends ConsumerStatefulWidget {
  final SshConnection connection;

  const _ConnectionManagementItem({required this.connection});

  @override
  ConsumerState<_ConnectionManagementItem> createState() => _ConnectionManagementItemState();
}

class _ConnectionManagementItemState extends ConsumerState<_ConnectionManagementItem> {
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
                ? LinearColors.fillSurfaceHover
                : LinearColors.fillSurface,
            borderRadius: BorderRadius.circular(LinearRadius.card),
            border: Border.all(
              color: _isHovered
                  ? LinearColors.borderStandard
                  : LinearColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadius.card),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<ConnectionFormScreen>(
                    builder: (context) =>
                        ConnectionFormScreen(connection: widget.connection),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(LinearRadius.card),
              focusColor: LinearColors.accentInteractive.withValues(alpha: 0.12),
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
                              color: _isHovered
                                  ? LinearColors.textPrimary
                                  : LinearColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: LinearSpacing.spacing4 / 2),
                          Text(
                            '${widget.connection.username}@${widget.connection.host}:${widget.connection.port}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: _isHovered
                                  ? LinearColors.textSecondary
                                  : LinearColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
                              Icon(Icons.edit, size: 20, color: LinearColors.textPrimary),
                              SizedBox(width: LinearSpacing.spacing8),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: LinearColors.error),
                              SizedBox(width: LinearSpacing.spacing8),
                              Text('删除', style: TextStyle(color: LinearColors.error)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute<ConnectionFormScreen>(
                              builder: (context) =>
                                  ConnectionFormScreen(connection: widget.connection),
                            ),
                          );
                        } else if (value == 'delete') {
                          _showDeleteDialog(context);
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

  Future<void> _showDeleteDialog(
    BuildContext context,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除连接 "${widget.connection.name}" 吗？'),
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
      await ref.read(connectionProvider.notifier).deleteConnection(widget.connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接已删除')));
      }
    }
  }
}
