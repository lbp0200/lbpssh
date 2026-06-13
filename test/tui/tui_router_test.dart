import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/tui/tui_state.dart';
import 'package:lbp_ssh/tui/tui_router.dart';
import 'package:utopia_tui/utopia_tui.dart';

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

SshConnection _conn({String name = 'test', String host = '192.168.1.1'}) {
  return SshConnection(
    id: 'test-id',
    name: name,
    host: host,
    username: 'root',
    authType: AuthType.password,
  );
}

void main() {
  group('paintCurrentScreen', () {
    test(
      'Given screen is list, When paintCurrentScreen called, Then renders connection list',
      () {
        final ctx = _ctx();
        final state = TuiState(connections: [_conn(name: 'server-1')]);

        paintCurrentScreen(state, ctx);

        final lines = ctx.surface.toPlainLines();
        // The connection name appears in the rendered output
        final joined = lines.join('\n');
        expect(joined, contains('server-1'));
      },
    );

    test(
      'Given screen is form, When paintCurrentScreen called, Then renders connection form',
      () {
        final ctx = _ctx();
        final conn = _conn(name: 'edit-me');
        final state = TuiState(
          screen: 'form',
          editConn: conn,
          formValues: {'name': 'edit-me'},
        );

        paintCurrentScreen(state, ctx);

        final lines = ctx.surface.toPlainLines();
        final joined = lines.join('\n');
        expect(joined, contains('edit-me'));
      },
    );

    test(
      'Given unknown screen, When paintCurrentScreen called, Then renders nothing',
      () {
        final ctx = _ctx();
        final state = TuiState(connections: [_conn()], screen: 'unknown');

        paintCurrentScreen(state, ctx);

        final lines = ctx.surface.toPlainLines();
        // Unknown screen leaves canvas blank (all spaces)
        expect(lines.every((l) => l.trim().isEmpty), isTrue);
      },
    );
  });
}
