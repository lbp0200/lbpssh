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

    test('shows "(新建)" for new connection name', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('(新建)')), isTrue);
    });

    test('shows Esc hint in status bar', () {
      final ctx = _ctx();
      final state = TuiState(connections: [], screen: 'form');

      paintConnectionForm(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[22], contains('Esc'));
    });
  });
}
