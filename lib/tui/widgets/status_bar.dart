import 'package:utopia_tui/utopia_tui.dart';

void paintTuiStatusBar(
  TuiContext ctx, {
  required String leftText,
  required String rightText,
  int row = 0,
}) {
  final w = ctx.width;
  ctx.surface.putText(0, row, ' ' * w, style: const TuiStyle(bg: 236));
  ctx.surface.putText(
    1,
    row,
    leftText,
    style: const TuiStyle(fg: 250, bg: 236),
  );
  ctx.surface.putText(
    w - rightText.length - 1,
    row,
    rightText,
    style: const TuiStyle(fg: 250, bg: 236),
  );
}
