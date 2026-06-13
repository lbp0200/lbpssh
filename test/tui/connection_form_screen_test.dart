import 'package:flutter_test/flutter_test.dart';
import 'package:utopia_tui/utopia_tui.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/tui/tui_state.dart';
import 'package:lbp_ssh/tui/screens/connection_form_screen.dart';

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
  group('ConnectionFormScreen', () {
    test('displays title for new connection', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[0], contains('添加连接'));
    });

    test('displays title for editing connection', () {
      final ctx = _ctx();
      final conn = SshConnection(
        id: 'test',
        name: 'My Server',
        host: '10.0.0.1',
        username: 'admin',
        authType: AuthType.password,
      );
      final state = TuiState(
        connections: [conn],
        screen: 'form',
        editConn: conn,
        formValues: {
          'name': 'My Server',
          'host': '10.0.0.1',
          'port': '22',
          'username': 'admin',
        },
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[0], contains('编辑连接'));
    });

    test('shows connection name when editing', () {
      final ctx = _ctx();
      final conn = SshConnection(
        id: 'test',
        name: '生产服务器',
        host: '10.0.0.1',
        port: 2222,
        username: 'root',
        authType: AuthType.password,
      );
      final state = TuiState(
        connections: [conn],
        screen: 'form',
        editConn: conn,
        formValues: {
          'name': '生产服务器',
          'host': '10.0.0.1',
          'port': '2222',
          'username': 'root',
        },
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('生产服务器')), isTrue);
      expect(lines.any((l) => l.contains('10.0.0.1')), isTrue);
      expect(lines.any((l) => l.contains('2222')), isTrue);
      expect(lines.any((l) => l.contains('root')), isTrue);
    });

    test('shows default port 22 for new connection', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('22')), isTrue);
    });

    test('shows empty name field for new connection', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('名称')), isTrue);
    });

    test('has Tab/Enter/Esc hints in status bar', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[22], contains('Tab'));
      expect(lines[22], contains('Enter'));
      expect(lines[22], contains('Esc'));
    });

    test('masks password with asterisks', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [],
        screen: 'form',
        formValues: {'password': 'secret123'},
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('*********')), isTrue);
      expect(lines.any((l) => l.contains('secret123')), isFalse);
    });

    test('hides key fields for password auth type', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('密钥路径')), isFalse);
      expect(lines.any((l) => l.contains('密钥密码')), isFalse);
    });

    test('shows key path for key auth type', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [],
        screen: 'form',
        formAuthType: AuthType.key,
        formValues: {'privateKeyPath': '/home/user/.ssh/id_rsa'},
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('密钥路径')), isTrue);
      expect(lines.any((l) => l.contains('id_rsa')), isTrue);
    });

    test('shows key+passphrase fields for keyWithPassword auth', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [],
        screen: 'form',
        formAuthType: AuthType.keyWithPassword,
        formValues: {
          'privateKeyPath': '/home/user/.ssh/id_rsa',
          'keyPassphrase': 'mypass',
        },
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('密钥路径')), isTrue);
      expect(lines.any((l) => l.contains('密钥密码')), isTrue);
    });

    test('highlights first field by default', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[3], contains('▸'));
    });

    test('shows auth type display text for each mode', () {
      for (final entry in [
        (AuthType.password, '密码'),
        (AuthType.key, '密钥'),
        (AuthType.keyWithPassword, '密钥+密码'),
        (AuthType.sshConfig, 'SSH配置'),
      ]) {
        final ctx = _ctx();
        final state = TuiState(
          connections: [],
          screen: 'form',
          formAuthType: entry.$1,
        );

        paintConnectionForm(state, ctx);

        final lines = ctx.surface.toPlainLines();
        expect(lines.any((l) => l.contains(entry.$2)), isTrue);
      }
    });

    test('shows sshConfig auth type as readonly with minimal fields', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [],
        screen: 'form',
        formAuthType: AuthType.sshConfig,
      );

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('SSH配置')), isTrue);
      expect(lines.any((l) => l.contains('密码')), isFalse);
      expect(lines.any((l) => l.contains('密钥路径')), isFalse);
      expect(lines.any((l) => l.contains('密钥密码')), isFalse);
    });
  });
}
