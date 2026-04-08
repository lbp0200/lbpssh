import 'package:flutter/material.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
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
            color = LinearColors.textTertiary;
            text = '未同步';
            break;
          case SyncStatusEnum.syncing:
            icon = Icons.sync;
            color = LinearColors.accentInteractive;
            text = '同步中...';
            break;
          case SyncStatusEnum.success:
            icon = Icons.check_circle;
            color = LinearColors.success;
            text = '同步成功';
            break;
          case SyncStatusEnum.error:
            icon = Icons.error;
            color = LinearColors.error;
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(LinearColors.accentInteractive),
                ),
              )
            else
              Icon(icon, key: const Key('sync_status_icon'), size: 16, color: color),
            const SizedBox(width: LinearSpacing.spacing4),
            Text(
              text,
              key: const Key('sync_status_text'),
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
            if (lastSyncTime != null) ...[
              const SizedBox(width: LinearSpacing.spacing8),
              Text(
                _formatTime(lastSyncTime),
                key: const Key('sync_status_time'),
                style: const TextStyle(
                  fontSize: 10,
                  color: LinearColors.textQuaternary,
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
