import 'package:utopia_tui/utopia_tui.dart';
import '../tui_state.dart';
import '../widgets/status_bar.dart';

void paintConnectionForm(TuiState state, TuiContext ctx) {
  final w = ctx.width;
  final h = ctx.height;

  final title = state.editConn != null ? ' 编辑连接 ' : ' 添加连接 ';
  ctx.surface.putText(
    (w - title.length) ~/ 2,
    0,
    title,
    style: const TuiStyle(bold: true),
  );
  ctx.surface.putText(0, 1, '─' * w);

  ctx.surface.putText(2, 3, '名称:  ${state.editConn?.name ?? '(新建)'}');
  ctx.surface.putText(2, 5, '主机:  ${state.editConn?.host ?? ''}');
  ctx.surface.putText(2, 7, '端口:  ${state.editConn?.port ?? 22}');
  ctx.surface.putText(2, 9, '用户:  ${state.editConn?.username ?? ''}');

  paintTuiStatusBar(ctx, leftText: ' Esc:返回 ', rightText: '', row: h - 2);
}
