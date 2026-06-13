import 'package:utopia_tui/utopia_tui.dart';
import '../../data/models/ssh_connection.dart';
import '../tui_state.dart';
import '../widgets/status_bar.dart';

const _fields = [
  'name',
  'host',
  'port',
  'username',
  'authType',
  'password',
  'privateKeyPath',
  'keyPassphrase',
];

String _fieldLabel(String key) => switch (key) {
  'name' => '名称',
  'host' => '主机',
  'port' => '端口',
  'username' => '用户',
  'authType' => '认证',
  'password' => '密码',
  'privateKeyPath' => '密钥路径',
  'keyPassphrase' => '密钥密码',
  _ => key,
};

String _fieldValue(TuiState state, String key) {
  if (key == 'authType') {
    return switch (state.formAuthType) {
      AuthType.password => '密码',
      AuthType.key => '密钥',
      AuthType.keyWithPassword => '密钥+密码',
      AuthType.sshConfig => 'SSH配置',
    };
  }
  final v = key == 'port'
      ? state.formValue(key, fallback: '22')
      : state.formValue(key);
  return (key == 'password' && v.isNotEmpty) ? '*' * v.length : v;
}

bool _fieldVisible(TuiState state, String key) => switch (key) {
  'password' =>
    state.formAuthType == AuthType.password ||
        state.formAuthType == AuthType.keyWithPassword,
  'privateKeyPath' =>
    state.formAuthType == AuthType.key ||
        state.formAuthType == AuthType.keyWithPassword,
  'keyPassphrase' => state.formAuthType == AuthType.keyWithPassword,
  _ => true,
};

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

  var row = 3;
  final visibleFields = _fields.where((f) => _fieldVisible(state, f)).toList();

  for (var i = 0; i < visibleFields.length; i++) {
    final key = visibleFields[i];
    final sel = i == state.formFieldIndex;
    final label = _fieldLabel(key);
    final value = _fieldValue(state, key);
    final fg = sel ? 16 : 250;
    final bg = sel ? 39 : 0;

    final indicator = sel ? ' ▸' : '  ';
    final line = '$indicator$label: $value';

    ctx.surface.putText(0, row, ' ' * w, style: TuiStyle(bg: bg));
    ctx.surface.putText(
      0,
      row,
      line,
      style: TuiStyle(fg: fg, bg: bg, bold: sel),
    );
    row += 2;
  }

  paintTuiStatusBar(
    ctx,
    leftText: ' Tab:切换  Enter:保存  Esc:取消 ',
    rightText: '',
    row: h - 2,
  );
}
