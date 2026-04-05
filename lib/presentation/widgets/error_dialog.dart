import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// 显示错误详情对话框
///
/// [title] 简要错误标题
/// [error] 错误对象
/// [stackTrace] 堆栈跟踪（可选）
/// [extraContext] 额外上下文信息（如连接名、主机等）
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  StackTrace? stackTrace,
  Map<String, String>? extraContext,
}) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  return showDialog(
    context: context,
    builder: (context) => ErrorDialog(
      title: title,
      error: error,
      stackTrace: stackTrace,
      extraContext: extraContext,
      appVersion: packageInfo.version,
    ),
  );
}

/// 错误详情对话框
class ErrorDialog extends StatefulWidget {
  final String title;
  final Object error;
  final StackTrace? stackTrace;
  final Map<String, String>? extraContext;
  final String appVersion;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.error,
    this.stackTrace,
    this.extraContext,
    required this.appVersion,
  });

  @override
  State<ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<ErrorDialog> {
  bool _copied = false;
  bool _errorExpanded = true;
  bool _stackExpanded = true;

  String get _errorString => widget.error.toString();
  String get _stackString => widget.stackTrace?.toString() ?? '';

  String _buildReport() {
    final buffer = StringBuffer();
    buffer.writeln('## 错误报告');
    buffer.writeln();
    buffer.writeln('**错误类型**: ${widget.error.runtimeType}');
    buffer.writeln('**错误信息**: ${widget.error}');
    buffer.writeln();

    if (_stackString.isNotEmpty) {
      buffer.writeln('**Stack Trace**:');
      buffer.writeln('```');
      buffer.writeln(_stackString);
      buffer.writeln('```');
      buffer.writeln();
    }

    if (widget.extraContext != null && widget.extraContext!.isNotEmpty) {
      buffer.writeln('**额外上下文**:');
      for (final entry in widget.extraContext!.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }

    buffer.writeln('**环境信息**:');
    buffer.writeln('- 操作系统: ${Platform.operatingSystem}');
    buffer.writeln('- 应用版本: ${widget.appVersion}');
    buffer.writeln('- 时间: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));
    if (mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错误报告已复制到剪贴板')),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  Future<void> _copyAndOpenIssues() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));

    final uri = Uri.parse('https://github.com/lbp0200/lbpssh/issues');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );

    return AlertDialog(
      backgroundColor: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.panel),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      title: Row(
        key: const Key('error_dialog_title'),
        children: [
          const Icon(Icons.error_outline, color: LinearColors.error),
          const SizedBox(width: LinearSpacing.spacing12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(color: LinearColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 错误信息
              _buildSection(
                title: '错误信息',
                expanded: _errorExpanded,
                onToggle: () => setState(() => _errorExpanded = !_errorExpanded),
                child: SelectableText(_errorString, style: errorTextStyle),
              ),

              // Stack Trace
              if (_stackString.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Stack Trace',
                  expanded: _stackExpanded,
                  onToggle: () => setState(() => _stackExpanded = !_stackExpanded),
                  child: SelectableText(_stackString, style: errorTextStyle),
                ),
              ],

              // 额外上下文
              if (widget.extraContext != null && widget.extraContext!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LinearColors.panel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.extraContext!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${entry.key}:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                entry.value,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0x05ffffff),
            borderRadius: BorderRadius.circular(LinearRadius.standard),
            border: Border.all(color: LinearColors.borderSolid),
          ),
          child: TextButton.icon(
            key: const Key('error_dialog_copy_button'),
            onPressed: _copyReport,
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('复制报告'),
          ),
        ),
        ElevatedButton(
          key: const Key('error_dialog_feedback_button'),
          onPressed: _copyAndOpenIssues,
          style: ElevatedButton.styleFrom(
            backgroundColor: LinearColors.accent,
            foregroundColor: Colors.white,
          ),
          child: Text(_copied ? '已复制，前往 Issues' : '反馈问题'),
        ),
        TextButton(
          key: const Key('error_dialog_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}
