import 'package:utopia_tui/utopia_tui.dart';
import '../../data/models/ssh_connection.dart';
import '../tui_state.dart';
import '../widgets/status_bar.dart';

void paintConnectionList(TuiState state, TuiContext ctx) {
  final w = ctx.width;
  final h = ctx.height;

  _title(ctx, w);

  final headerRow = state.isSearching ? 4 : 3;
  final dataStartRow = headerRow + 2;
  final maxRows = h - dataStartRow - 2;

  if (state.isSearching) {
    _searchBar(ctx, state);
  }

  _header(ctx, headerRow, w);
  _rows(state, ctx, dataStartRow, maxRows);
  _hints(ctx, h, w);
  paintTuiStatusBar(
    ctx,
    leftText:
        ' ${state.filteredConnections.length}/${state.connections.length} connections',
    rightText: 'lbpSSH TUI',
    row: h - 2,
  );
}

void _title(TuiContext ctx, int w) {
  const t = ' lbpSSH TUI ';
  ctx.surface.putText(
    (w - t.length) ~/ 2,
    0,
    t,
    style: const TuiStyle(bold: true),
  );
  ctx.surface.putText(0, 1, '─' * w);
}

void _header(TuiContext ctx, int row, int w) {
  const s = TuiStyle(bold: true, fg: 250, bg: 236);
  ctx.surface.putText(0, row, '#   ', style: s);
  ctx.surface.putText(4, row, '名称  ', style: s);
  ctx.surface.putText(26, row, '主机  ', style: s);
  ctx.surface.putText(46, row, '端口  ', style: s);
  ctx.surface.putText(54, row, '认证  ', style: s);
  ctx.surface.putText(62, row, '用户  ', style: s);
  ctx.surface.putText(0, row + 1, '─' * w);
}

void _searchBar(TuiContext ctx, TuiState state) {
  ctx.surface.putText(0, 2, ' ' * ctx.width);
  final display = '/${state.searchQuery}';
  ctx.surface.putText(0, 2, ' 搜索: ', style: const TuiStyle(fg: 246));
  ctx.surface.putText(5, 2, display, style: const TuiStyle(fg: 39));
  ctx.surface.putText(
    5 + display.length,
    2,
    '█',
    style: const TuiStyle(fg: 39),
  );
}

void _rows(TuiState state, TuiContext ctx, int startRow, int maxRows) {
  final conns = state.filteredConnections;

  if (conns.isEmpty) {
    ctx.surface.putText(
      2,
      startRow,
      state.searchQuery.isNotEmpty ? '(无匹配)' : '(暂无连接 - 按 a 添加)',
    );
    return;
  }

  final offset = state.sel >= maxRows ? state.sel - maxRows + 1 : 0;

  for (var i = 0; i < maxRows && i + offset < conns.length; i++) {
    final idx = i + offset;
    final conn = conns[idx];
    final sel = idx == state.sel;
    final fg = sel ? 16 : 250;
    final bg = sel ? 39 : 0;

    ctx.surface.putText(
      0,
      startRow + i,
      ' ' * ctx.width,
      style: TuiStyle(bg: bg),
    );
    _cell(ctx, startRow + i, 0, '${idx + 1}'.padRight(4), fg, bg);
    _cell(ctx, startRow + i, 4, conn.name.padRight(20), fg, bg);
    _cell(ctx, startRow + i, 26, conn.host.padRight(18), fg, bg);
    _cell(ctx, startRow + i, 46, conn.port.toString().padRight(6), fg, bg);
    _cell(ctx, startRow + i, 54, _auth(conn.authType).padRight(6), fg, bg);
    _cell(ctx, startRow + i, 62, conn.username.padRight(14), fg, bg);
  }
}

void _cell(TuiContext ctx, int row, int col, String text, int fg, int bg) {
  ctx.surface.putText(
    col,
    row,
    text,
    style: TuiStyle(fg: fg, bg: bg),
  );
}

String _auth(AuthType a) => switch (a) {
  AuthType.password => 'pwd',
  AuthType.key => 'key',
  AuthType.keyWithPassword => 'k+p',
  AuthType.sshConfig => 'cfg',
};

void _hints(TuiContext ctx, int h, int w) {
  final r = h - 1;
  ctx.surface.putText(0, r, ' ' * w, style: const TuiStyle(bg: 236));
  ctx.surface.putText(
    0,
    r,
    ' [/]搜索  [a]添加  [e]编辑  [d]删除  [Enter]连接  [Ctrl+C]退出',
    style: const TuiStyle(fg: 246, bg: 236),
  );
}
