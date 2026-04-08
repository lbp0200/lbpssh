import 'dart:ui' as ui;
import 'package:flutter/material.dart';

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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        // 使用 setState 触发重建以检查新的图形
        setState(() {});
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _buildImageWidgets(),
    );
  }

  List<Widget> _buildImageWidgets() {
    final widgets = <Widget>[];
    final placements = widget.graphicsManager.placements as Map<Object, Object>;

    for (final entry in placements.entries) {
      final placement = entry.value as Map<String, Object>;
      final image = widget.graphicsManager.getImage(placement['imageId'] as String);
      if (image == null) continue;

      final x = (placement['x'] as num).toDouble() * widget.cellWidth;
      final y = ((placement['y'] as num).toDouble() - widget.scrollOffset) * widget.cellHeight;
      final width = (placement['width'] as num).toDouble() * widget.cellWidth;
      final height = (placement['height'] as num).toDouble() * widget.cellHeight;

      // 跳过不可见的图片
      if (x + width < 0 || y + height < 0) continue;

      widgets.add(
        Positioned(
          left: x,
          top: y,
          child: SizedBox(
            width: width,
            height: height,
            child: RawImage(
              image: image as ui.Image?,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
