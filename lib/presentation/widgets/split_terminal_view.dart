import 'package:flutter/material.dart';

enum SplitDirection { horizontal, vertical }

class SplitTerminalView extends StatefulWidget {
  final String sessionId1;
  final String sessionId2;
  final SplitDirection direction;

  const SplitTerminalView({
    super.key,
    required this.sessionId1,
    required this.sessionId2,
    this.direction = SplitDirection.vertical,
  });

  @override
  State<SplitTerminalView> createState() => _SplitTerminalViewState();
}

class _SplitTerminalViewState extends State<SplitTerminalView> {
  double _splitPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = widget.direction == SplitDirection.horizontal;
        final totalSize = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final firstSize = totalSize * _splitPosition;

        if (isHorizontal) {
          // Horizontal split: left and right
          return Row(
            children: [
              SizedBox(
                width: firstSize,
                height: constraints.maxHeight,
                child: _TerminalContainer(sessionId: widget.sessionId1),
              ),
              GestureDetector(
                onHorizontalDragUpdate: (details) => setState(() {
                  _splitPosition =
                      (_splitPosition + details.delta.dx / totalSize).clamp(
                        0.1,
                        0.9,
                      );
                }),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 8,
                    height: constraints.maxHeight,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              Expanded(child: _TerminalContainer(sessionId: widget.sessionId2)),
            ],
          );
        } else {
          // Vertical split: top and bottom
          return Column(
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: firstSize,
                child: _TerminalContainer(sessionId: widget.sessionId1),
              ),
              GestureDetector(
                onVerticalDragUpdate: (details) => setState(() {
                  _splitPosition =
                      (_splitPosition + details.delta.dy / totalSize).clamp(
                        0.1,
                        0.9,
                      );
                }),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: Container(
                    width: constraints.maxWidth,
                    height: 8,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              Expanded(child: _TerminalContainer(sessionId: widget.sessionId2)),
            ],
          );
        }
      },
    );
  }
}

class _TerminalContainer extends StatelessWidget {
  final String sessionId;

  const _TerminalContainer({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    // Placeholder - integrate TerminalViewWidget in future
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Terminal: $sessionId',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
