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
  try {
    stdin.lineMode = true;
    stdin.echoMode = true;
  } catch (_) {}
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
  final conns = _state.filteredConnections;

  if (_state.isSearching) {
    if (key == 'esc') {
      _state.searchQuery = '';
      _state.isSearching = false;
      _state.sel = 0;
    } else if (key == 'backspace') {
      if (_state.searchQuery.isNotEmpty) {
        _state.searchQuery = _state.searchQuery.substring(
          0,
          _state.searchQuery.length - 1,
        );
      }
      _state.sel = 0;
    } else if (key.length == 1) {
      _state.searchQuery += key;
      _state.sel = 0;
    }
    return;
  }

  switch (key) {
    case 'down':
    case 'j':
      if (_state.sel < conns.length - 1) _state.sel++;
      break;
    case 'up':
    case 'k':
      if (_state.sel > 0) _state.sel--;
      break;
    case 'enter':
      if (conns.isNotEmpty) {
        _sshRequest = conns[_state.sel];
        _running = false;
      }
      break;
    case '/':
      _state.isSearching = true;
      _state.searchQuery = '';
      break;
    case 'a':
      _state = TuiState(
        connections: _state.connections,
        screen: 'form',
        sel: _state.sel,
      );
      break;
    case 'e':
      if (conns.isNotEmpty) {
        _state = TuiState(
          connections: _state.connections,
          screen: 'form',
          sel: _state.sel,
          editConn: conns[_state.sel],
        );
        _initFormFromEdit(conns[_state.sel]);
      }
      break;
    case 'd':
      if (conns.isNotEmpty) {
        _repo.deleteConnection(conns[_state.sel].id);
        final updated = _repo.getAllConnections();
        _state.connections = updated;
        _state.sel = _state.sel >= _state.filteredConnections.length
            ? _state.filteredConnections.length - 1
            : _state.sel;
        if (_state.sel < 0) _state.sel = 0;
      }
      break;
  }
}

const _formFields = [
  'name',
  'host',
  'port',
  'username',
  'authType',
  'password',
  'privateKeyPath',
  'keyPassphrase',
];

bool _formFieldVisible(String key) => switch (key) {
  'password' =>
    _state.formAuthType == AuthType.password ||
        _state.formAuthType == AuthType.keyWithPassword,
  'privateKeyPath' =>
    _state.formAuthType == AuthType.key ||
        _state.formAuthType == AuthType.keyWithPassword,
  'keyPassphrase' => _state.formAuthType == AuthType.keyWithPassword,
  _ => true,
};

List<String> _visibleFormFields() =>
    _formFields.where(_formFieldVisible).toList();

void _initFormFromEdit(SshConnection conn) {
  _state.formValues = {
    'name': conn.name,
    'host': conn.host,
    'port': conn.port.toString(),
    'username': conn.username,
    'password': conn.password ?? '',
    'privateKeyPath': conn.privateKeyPath ?? '',
    'keyPassphrase': conn.keyPassphrase ?? '',
  };
  _state.formAuthType = conn.authType;
  _state.formFieldIndex = 0;
}

void _handleFormKey(String key) {
  switch (key) {
    case 'tab':
      final fields = _visibleFormFields();
      _state.formFieldIndex = (_state.formFieldIndex + 1) % fields.length;
      break;
    case 'esc':
      _state = TuiState(connections: _state.connections, sel: _state.sel);
      break;
    case 'enter':
      final conn = _state.buildConnection();
      if (conn != null) {
        _repo.saveConnection(conn);
        _state = TuiState(
          connections: _repo.getAllConnections(),
          sel: _state.sel,
        );
      }
      break;
    case 'backspace':
      final fields = _visibleFormFields();
      if (_state.formFieldIndex < fields.length) {
        final k = fields[_state.formFieldIndex];
        if (k == 'authType') break;
        final v = _state.formValue(k);
        if (v.isNotEmpty) {
          _state.setFormValue(k, v.substring(0, v.length - 1));
        }
      }
      break;
    case ' ':
      final fields = _visibleFormFields();
      if (_state.formFieldIndex < fields.length &&
          fields[_state.formFieldIndex] == 'authType') {
        _state.formAuthType = switch (_state.formAuthType) {
          AuthType.password => AuthType.key,
          AuthType.key => AuthType.keyWithPassword,
          AuthType.keyWithPassword => AuthType.sshConfig,
          AuthType.sshConfig => AuthType.password,
        };
        _state.formFieldIndex = 0;
      } else if (_state.formFieldIndex < fields.length) {
        final k = fields[_state.formFieldIndex];
        _state.setFormValue(k, '${_state.formValue(k)} ');
      }
      break;
    default:
      if (key.length == 1) {
        final fields = _visibleFormFields();
        if (_state.formFieldIndex < fields.length) {
          final k = fields[_state.formFieldIndex];
          if (k == 'authType') break;
          _state.setFormValue(k, _state.formValue(k) + key);
        }
      }
  }
}

Future<void> _runSsh(SshConnection conn) async {
  stdout.writeln(
    '\nConnecting to ${conn.username}@${conn.host}:${conn.port}...',
  );
  stdout.writeln('Type "exit" or press Ctrl+D to return.\n');

  try {
    final result = await Process.run('ssh', [
      '-p',
      conn.port.toString(),
      '${conn.username}@${conn.host}',
    ], runInShell: true);
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
  final configDir =
      Platform.environment['LBPSSH_CONFIG_DIR'] ?? '$home/.lbpSSH';
  return File('$configDir/ssh_connections.json');
}

List<String> _parseKeys(List<int> bytes) => parseKeys(bytes);
