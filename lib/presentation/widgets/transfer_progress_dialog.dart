import 'package:flutter/material.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';

/// 传输进度对话框
class TransferProgressDialog extends StatefulWidget {
  final String fileName;
  final int totalBytes;
  final Stream<TransferProgress> progressStream;
  final VoidCallback onCancel;

  const TransferProgressDialog({
    super.key,
    required this.fileName,
    required this.totalBytes,
    required this.progressStream,
    required this.onCancel,
  });

  @override
  State<TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<TransferProgressDialog> {
  double _percent = 0;
  int _transferred = 0;
  int _bytesPerSecond = 0;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _percent = progress.percent;
          _transferred = progress.transferredBytes;
          _bytesPerSecond = progress.bytesPerSecond;
        });
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.panel),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      title: const Row(
        children: [
          Icon(Icons.upload_file, color: LinearColors.accentInteractive),
          SizedBox(width: LinearSpacing.spacing12),
          Text(
            '上传文件',
            style: TextStyle(
              color: LinearColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件: ${widget.fileName}',
            style: const TextStyle(color: LinearColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: LinearSpacing.spacing16),
          ClipRRect(
            borderRadius: BorderRadius.circular(LinearRadius.small),
            child: LinearProgressIndicator(
              value: _percent / 100,
              backgroundColor: LinearColors.borderSolid,
              valueColor: const AlwaysStoppedAnimation<Color>(LinearColors.accentInteractive),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: LinearSpacing.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_percent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: LinearColors.accentInteractive,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_formatSize(_transferred)} / ${_formatSize(widget.totalBytes)}',
                style: const TextStyle(color: LinearColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          if (_bytesPerSecond > 0) ...[
            const SizedBox(height: LinearSpacing.spacing4),
            Text(
              '速度: ${_formatSize(_bytesPerSecond)}/s',
              style: const TextStyle(color: LinearColors.textQuaternary, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            '取消',
            style: TextStyle(color: LinearColors.textTertiary),
          ),
        ),
      ],
    );
  }
}
