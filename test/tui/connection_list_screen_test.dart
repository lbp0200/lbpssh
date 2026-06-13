import 'package:flutter_test/flutter_test.dart';
import 'package:utopia_tui/utopia_tui.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/tui/tui_state.dart';
import 'package:lbp_ssh/tui/screens/connection_list_screen.dart';

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

SshConnection _conn({
  String name = 'test',
  String host = '192.168.1.1',
  int port = 22,
  String username = 'root',
  AuthType auth = AuthType.password,
}) {
  return SshConnection(
    id: 'test-id',
    name: name,
    host: host,
    port: port,
    username: username,
    authType: auth,
  );
}

void main() {
  group('ConnectionListScreen', () {
    test('displays title', () {
      final ctx = _ctx();
      final state = TuiState(connections: []);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[0], contains('lbpSSH TUI'));
    });

    test('shows empty message when no connections', () {
      final ctx = _ctx();
      final state = TuiState(connections: []);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('暂无连接')), isTrue);
    });

    test('shows connection count in status bar', () {
      final ctx = _ctx();
      final state = TuiState(connections: []);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[22], contains('0 connections'));
    });

    test('renders connection row with host and port', () {
      final ctx = _ctx();
      final conn = _conn(host: '10.0.0.5', port: 2222);
      final state = TuiState(connections: [conn]);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      final hasHost = lines.any((l) => l.contains('10.0.0.5'));
      final hasPort = lines.any((l) => l.contains('2222'));
      expect(hasHost, isTrue);
      expect(hasPort, isTrue);
    });

    test('renders connection name', () {
      final ctx = _ctx();
      final conn = _conn(name: '生产服务器');
      final state = TuiState(connections: [conn]);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('生产服务器')), isTrue);
    });

    test('renders multiple connections', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [
          _conn(name: 'server-1', host: '10.0.0.1'),
          _conn(name: 'server-2', host: '10.0.0.2'),
          _conn(name: 'server-3', host: '10.0.0.3'),
        ],
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('server-1')), isTrue);
      expect(lines.any((l) => l.contains('server-2')), isTrue);
      expect(lines.any((l) => l.contains('server-3')), isTrue);
    });

    test('renders auth type labels', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [
          _conn(name: 'pwd'),
          _conn(name: 'key', auth: AuthType.key),
          _conn(name: 'k+p', auth: AuthType.keyWithPassword),
          _conn(name: 'cfg', auth: AuthType.sshConfig),
        ],
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('pwd')), isTrue);
      expect(lines.any((l) => l.contains('key')), isTrue);
      expect(lines.any((l) => l.contains('k+p')), isTrue);
      expect(lines.any((l) => l.contains('cfg')), isTrue);
    });

    test('renders key hints bar', () {
      final ctx = _ctx();
      final state = TuiState(connections: []);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[23], contains('[a]'));
      expect(lines[23], contains('[e]'));
      expect(lines[23], contains('[d]'));
    });

    test('highlights selected row', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [
          _conn(name: 'selected-one'),
          _conn(name: 'other-one'),
        ],
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[5], contains('selected-one'));
      expect(lines[6], contains('other-one'));
    });

    test('handles many connections with scrolling', () {
      final ctx = _ctx(80, 12);
      final conns = List.generate(
        20,
        (i) => _conn(name: 'srv-$i', host: '10.0.0.$i'),
      );
      final state = TuiState(connections: conns, sel: 15);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('srv-15')), isTrue);
      expect(lines.any((l) => l.contains('srv-0')), isFalse);
    });

    test('renders header row', () {
      final ctx = _ctx();
      final state = TuiState(connections: []);

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[3], contains('名称'));
      expect(lines[3], contains('主机'));
      expect(lines[3], contains('端口'));
      expect(lines[3], contains('用户'));
    });

    test('shows filtered count when searching', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [
          _conn(name: 'prod-web', host: '10.0.0.1'),
          _conn(name: 'prod-db', host: '10.0.0.2'),
          _conn(name: 'dev', host: '10.0.0.3'),
        ],
        searchQuery: 'prod',
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[22], contains('2/3'));
    });

    test('shows search bar when isSearching', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [_conn()],
        isSearching: true,
        searchQuery: 'prod',
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines[2], contains('prod'));
    });

    test('shows no match when filter yields empty', () {
      final ctx = _ctx();
      final state = TuiState(
        connections: [_conn(name: 'server')],
        searchQuery: 'xyz',
      );

      paintConnectionList(state, ctx);

      final lines = ctx.surface.toPlainLines();
      expect(lines.any((l) => l.contains('无匹配')), isTrue);
    });
  });

  group('TuiState.filteredConnections', () {
    final conns = [
      _conn(name: 'production-web'),
      _conn(name: 'production-db'),
      _conn(name: 'dev-server'),
    ];

    test('filters by name', () {
      final state = TuiState(connections: conns, searchQuery: 'production');
      expect(state.filteredConnections.length, 2);
    });

    test('filters by host', () {
      final state = TuiState(
        connections: [
          _conn(name: 'web', host: '10.0.0.1'),
          _conn(name: 'db', host: '10.0.0.2'),
        ],
        searchQuery: '10.0.0',
      );
      expect(state.filteredConnections.length, 2);
    });

    test('filters by username', () {
      final state = TuiState(
        connections: [
          _conn(name: 'web', username: 'deploy'),
          _conn(name: 'db', username: 'admin'),
        ],
        searchQuery: 'deploy',
      );
      expect(state.filteredConnections.length, 1);
    });

    test('is case-insensitive', () {
      final state = TuiState(connections: conns, searchQuery: 'PRODUCTION');
      expect(state.filteredConnections.length, 2);
    });

    test('returns all when query is empty', () {
      final state = TuiState(connections: conns);
      expect(state.filteredConnections.length, 3);
    });

    test('returns empty when no match', () {
      final state = TuiState(connections: conns, searchQuery: 'nope');
      expect(state.filteredConnections.length, 0);
    });
  });
}
