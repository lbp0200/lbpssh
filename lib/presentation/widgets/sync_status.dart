import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/services/sync_service.dart';
import '../providers/sync_provider.dart';

/// 同步状态显示组件
class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, provider, child) {
        final status = provider.status;
        final lastSyncTime = provider.lastSyncTime;

        IconData icon;
        Color color;
        String text;

        switch (status) {
          case SyncStatusEnum.idle:
            icon = Icons.sync;
            color = Colors.grey;
            text = '未同步';
            break;
          case SyncStatusEnum.syncing:
            icon = Icons.sync;
            color = Colors.blue;
            text = '同步中...';
            break;
          case SyncStatusEnum.success:
            icon = Icons.check_circle;
            color = Colors.green;
            text = '同步成功';
            break;
          case SyncStatusEnum.error:
            icon = Icons.error;
            color = Colors.red;
            text = '同步失败';
            break;
        }

        return Row(
          key: const Key('sync_status_container'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == SyncStatusEnum.syncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, key: const Key('sync_status_icon'), size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              key: const Key('sync_status_text'),
              style: TextStyle(fontSize: 12, color: color),
            ),
            if (lastSyncTime != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatTime(lastSyncTime),
                key: const Key('sync_status_time'),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }
}
