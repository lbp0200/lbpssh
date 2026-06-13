import 'package:flutter_test/flutter_test.dart';
import 'package:utopia_tui/utopia_tui.dart';
import 'package:lbp_ssh/tui/widgets/status_bar.dart';

class _TestTerminal implements TuiTerminalInterface {
  @override
  int width = 80;
  @override
  int height = 24;
  final buffer = StringBuffer();

  @override
  void hideCursor() {}
  @override
  void showCursor() {}
  @override
  void clearScreen() {}
  @override
  void setCursor(int row, int col) {}
  @override
  void write(String text) => buffer.write(text);
  @override
  void resetRawMode() {}
}

TuiContext _ctx([int w = 80, int h = 24]) {
  return TuiContext(
    _TestTerminal()
      ..width = w
      ..height = h,
  );
}

void main() {
  group('paintTuiStatusBar', () {
    test(
      'Given left and right text, When painting status bar, Then renders both sides',
      () {
        final ctx = _ctx();
        paintTuiStatusBar(ctx, leftText: ' Esc:返回 ', rightText: ' v1.0 ');

        final lines = ctx.surface.toPlainLines();
        final joined = lines.join('\n');
        // Left text appears on the left side
        expect(joined, contains('Esc'));
        // Right text appears on the right side
        expect(joined, contains('v1.0'));
      },
    );

    test(
      'Given custom row, When painting status bar, Then renders at specified row',
      () {
        final ctx = _ctx();
        paintTuiStatusBar(ctx, leftText: ' Status ', rightText: '', row: 22);

        final lines = ctx.surface.toPlainLines();
        // Row 22 should have the status bar content
        expect(lines[22].trim(), isNotEmpty);
        expect(lines[22], contains('Status'));
        // Default row 0 should be blank
        expect(lines[0].trim(), isEmpty);
      },
    );

    test(
      'Given empty text, When painting status bar, Then renders background only',
      () {
        final ctx = _ctx();
        paintTuiStatusBar(ctx, leftText: '', rightText: '');

        final lines = ctx.surface.toPlainLines();
        // Background bar (row 0 with spaces and bg color)
        expect(lines[0].length, 80);
      },
    );

    test(
      'Given long rightText, When painting status bar, Then positioned at right edge',
      () {
        final ctx = _ctx();
        paintTuiStatusBar(ctx, leftText: 'Left', rightText: 'RightEdge');

        // RightEdge should be drawn, not clobbered by left text
        final lines = ctx.surface.toPlainLines();
        expect(lines[0], contains('RightEdge'));
      },
    );
  });
}
