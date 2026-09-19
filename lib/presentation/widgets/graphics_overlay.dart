import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../utils/sentry_service.dart';

/// 终端图形叠加层组件
/// 显示由 kterm GraphicsManager 管理的图片
class GraphicsOverlayWidget extends StatefulWidget {
  final dynamic graphicsManager;
  final double cellWidth;
  final double cellHeight;
  final int scrollOffset;

  const GraphicsOverlayWidget({
    super.key,
    required this.graphicsManager,
    required this.cellWidth,
    required this.cellHeight,
    required this.scrollOffset,
  });

  @override
  State<GraphicsOverlayWidget> createState() => _GraphicsOverlayWidgetState();
}

class _GraphicsOverlayWidgetState extends State<GraphicsOverlayWidget> {
  bool _sentryReported = false;

  @override
  void initState() {
    super.initState();

    // 创建一个定期检查更新的定时器
    // 在实际实现中，应该让 GraphicsManager 提供一个回调或流
    // 这里使用 100ms 的间隔来检查更新
    _startPolling();
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      try {
        final placements = widget.graphicsManager.placements;
        if (placements is Map && placements.isNotEmpty) {
          setState(() {});
        }
      } catch (e, stackTrace) {
        // 忽略图形管理器访问异常；持续失败时最多上报一次，避免高频刷屏
        if (!_sentryReported) {
          _sentryReported = true;
          debugPrint('[GraphicsOverlay] graphics manager access failed: $e');
          unawaited(
            SentryService().captureException(e, stackTrace: stackTrace),
          );
        }
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      final widgets = _buildImageWidgets();
      if (widgets.isEmpty) return const SizedBox.shrink();
      return Stack(children: widgets);
    } catch (e) {
      // 渲染失败降级为空组件，避免崩溃；仅记录日志不上报
      debugPrint('[GraphicsOverlay] build failed: $e');
      return const SizedBox.shrink();
    }
  }

  List<Widget> _buildImageWidgets() {
    final widgets = <Widget>[];
    final placements = widget.graphicsManager.placements as Map<Object, Object>;

    for (final entry in placements.entries) {
      final placement = entry.value as Map<String, Object>;
      final image = widget.graphicsManager.getImage(
        placement['imageId'] as String,
      );
      if (image == null) continue;

      final x = (placement['x'] as num).toDouble() * widget.cellWidth;
      final y =
          ((placement['y'] as num).toDouble() - widget.scrollOffset) *
          widget.cellHeight;
      final width = (placement['width'] as num).toDouble() * widget.cellWidth;
      final height =
          (placement['height'] as num).toDouble() * widget.cellHeight;

      // 跳过不可见的图片
      if (x + width < 0 || y + height < 0) continue;

      widgets.add(
        Positioned(
          left: x,
          top: y,
          child: SizedBox(
            width: width,
            height: height,
            child: RawImage(image: image as ui.Image?, fit: BoxFit.contain),
          ),
        ),
      );
    }

    return widgets;
  }
}
