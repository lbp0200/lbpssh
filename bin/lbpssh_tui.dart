import 'dart:async';
import 'dart:io';

import 'package:utopia_tui/utopia_tui.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/tui/tui_router.dart';
import 'package:lbp_ssh/tui/tui_state.dart';
import 'package:lbp_ssh/tui/key_parser.dart';

var _configFile = File('');
var _repo = ConnectionRepository();
var _state = TuiState();
var _running = true;
StreamSubscription<List<int>>? _stdSub;
SshConnection? _sshRequest;

void main(List<String> args) async {
  _configFile = _resolveConfigFile();
  if (!await _configFile.exists()) {
    await _configFile.create(recursive: true);
    await _configFile.writeAsString('[]');
  }
  _repo = ConnectionRepository(configFile: _configFile);
  await _repo.init();
  _state = TuiState(connections: _repo.getAllConnections());

  while (_running) {
    await _runTui();
    if (_sshRequest != null) {
      final conn = _sshRequest!;
      _sshRequest = null;
      await _runSsh(conn);
      _state.connections = _repo.getAllConnections();
    }
  }
}

final _term = TuiTerminal();

Future<void> _runTui() async {
  _term.write('\x1b[?1049h');
  _term.clearScreen();
  _term.hideCursor();

  stdin.echoMode = false;
  stdin.lineMode = false;

  var lastFrame = <String>[];
  _running = true;

  final completer = Completer<void>();

  _render(lastFrame);

  await _stdSub?.cancel();
  _stdSub = stdin.listen((bytes) {
    final keys = _parseKeys(bytes);
    for (final k in keys) {
      if (k == 'ctrl_c') {
        _running = false;
        completer.complete();
        return;
      }
      _handleKey(k);
      _render(lastFrame);
    }
  });

  await completer.future;
  await _stdSub?.cancel();
  _term.write('\x1b[0m');
  _term.showCursor();
  _term.write('\x1b[?1049l');
  try { stdin.lineMode = true; stdin.echoMode = true; } catch (_) {}
}

void _render(List<String> lastFrame) {
  final ctx = TuiContext(_term);
  ctx.clear();
  paintCurrentScreen(_state, ctx);

  final frame = ctx.snapshotStyled();
  for (var r = 0; r < frame.length; r++) {
    final prev = r < lastFrame.length ? lastFrame[r] : null;
    if (prev != frame[r]) {
      _term.setCursor(r, 0);
      _term.write(frame[r]);
    }
  }
  lastFrame
    ..clear()
    ..addAll(frame);
}

void _handleKey(String key) {
  if (_state.screen == 'list') {
    _handleListKey(key);
  } else if (_state.screen == 'form') {
    _handleFormKey(key);
  }
}

void _handleListKey(String key) {
  switch (key) {
    case 'down':
    case 'j':
      if (_state.sel < _state.connections.length - 1) _state.sel++;
      break;
    case 'up':
    case 'k':
      if (_state.sel > 0) _state.sel--;
      break;
    case 'enter':
      if (_state.connections.isNotEmpty) {
        _sshRequest = _state.connections[_state.sel];
        _running = false;
      }
      break;
    case 'a':
      _state = TuiState(
        connections: _state.connections,
        screen: 'form',
        sel: _state.sel,
        editConn: null,
      );
      break;
    case 'e':
      if (_state.connections.isNotEmpty) {
        _state = TuiState(
          connections: _state.connections,
          screen: 'form',
          sel: _state.sel,
          editConn: _state.connections[_state.sel],
        );
      }
      break;
    case 'd':
      if (_state.connections.isNotEmpty) {
        final conn = _state.connections[_state.sel];
        _repo.deleteConnection(conn.id);
        final updated = _repo.getAllConnections();
        _state.sel = _state.sel >= updated.length ? updated.length - 1 : _state.sel;
        if (_state.sel < 0) _state.sel = 0;
        _state.connections = updated;
      }
      break;
  }
}

void _handleFormKey(String key) {
  if (key == 'esc') {
    _state = TuiState(connections: _state.connections, sel: _state.sel);
  }
}

Future<void> _runSsh(SshConnection conn) async {
  stdout.writeln('\nConnecting to ${conn.username}@${conn.host}:${conn.port}...');
  stdout.writeln('Type "exit" or press Ctrl+D to return.\n');

  try {
    final result = await Process.run(
      'ssh',
      ['-p', conn.port.toString(), '${conn.username}@${conn.host}'],
      runInShell: true,
    );
    if (result.exitCode != 0 && result.stderr.toString().isNotEmpty) {
      stderr.writeln(result.stderr);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  } catch (e) {
    stderr.writeln('SSH failed: $e');
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

File _resolveConfigFile() {
  final home = Platform.environment['HOME'] ?? '.';
  final configDir = Platform.environment['LBPSSH_CONFIG_DIR'] ?? '$home/.lbpSSH';
  return File('$configDir/ssh_connections.json');
}

List<String> _parseKeys(List<int> bytes) => parseKeys(bytes);
