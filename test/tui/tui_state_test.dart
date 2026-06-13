import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/tui/tui_state.dart';

SshConnection _conn({
  String name = 'test',
  String host = '192.168.1.1',
  String username = 'root',
}) {
  return SshConnection(
    id: 'test-id',
    name: name,
    host: host,
    username: username,
    authType: AuthType.password,
  );
}

void main() {
  group('TuiState', () {
    group('default values', () {
      test(
        'Given no arguments, When creating TuiState, Then uses default values',
        () {
          final state = TuiState();

          expect(state.connections, isEmpty);
          expect(state.screen, 'list');
          expect(state.sel, 0);
          expect(state.editConn, isNull);
          expect(state.searchQuery, '');
          expect(state.isSearching, isFalse);
        },
      );
    });

    group('filteredConnections', () {
      test(
        'Given empty searchQuery, When accessing filteredConnections, Then returns all connections',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'server-1'),
              _conn(name: 'server-2'),
            ],
          );

          expect(state.filteredConnections.length, 2);
        },
      );

      test(
        'Given searchQuery matching name, When accessing filteredConnections, Then returns matching connections',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'production-web', host: '10.0.0.1'),
              _conn(name: 'production-db', host: '10.0.0.2'),
              _conn(name: 'dev-server', host: '10.0.0.3'),
            ],
            searchQuery: 'prod',
          );

          expect(state.filteredConnections.length, 2);
          expect(
            state.filteredConnections.every((c) => c.name.startsWith('prod')),
            isTrue,
          );
        },
      );

      test(
        'Given searchQuery matching host, When accessing filteredConnections, Then returns matching connections',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'web', host: '192.168.1.10'),
              _conn(name: 'db', host: '10.0.0.2'),
              _conn(name: 'cache', host: '10.0.0.3'),
            ],
            searchQuery: '192.168',
          );

          expect(state.filteredConnections.length, 1);
          expect(state.filteredConnections.first.name, 'web');
        },
      );

      test(
        'Given searchQuery matching username, When accessing filteredConnections, Then returns matching connections',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'web', username: 'deploy'),
              _conn(name: 'db', username: 'admin'),
            ],
            searchQuery: 'deploy',
          );

          expect(state.filteredConnections.length, 1);
          expect(state.filteredConnections.first.name, 'web');
        },
      );

      test(
        'Given searchQuery matching nothing, When accessing filteredConnections, Then returns empty list',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'web', host: '10.0.0.1'),
              _conn(name: 'db', host: '10.0.0.2'),
            ],
            searchQuery: 'nonexistent',
          );

          expect(state.filteredConnections, isEmpty);
        },
      );

      test(
        'Given searchQuery, When accessing filteredConnections, Then search is case-insensitive',
        () {
          final state = TuiState(
            connections: [
              _conn(name: 'Production-Web'),
              _conn(name: 'production-db'),
            ],
            searchQuery: 'PRODUCTION',
          );

          expect(state.filteredConnections.length, 2);
        },
      );
    });

    group('screen navigation', () {
      test(
        'Given initial state, When changing screen to form, Then screen reflects change',
        () {
          final state = TuiState()..screen = 'form';

          expect(state.screen, 'form');
        },
      );

      test(
        'Given state with editConn, When setting editConn, Then editConn is stored',
        () {
          final conn = _conn(name: 'edit-me');
          final state = TuiState(editConn: conn);

          expect(state.editConn, isNotNull);
          expect(state.editConn!.name, 'edit-me');
        },
      );
    });

    group('form state', () {
      test(
        'Given new TuiState, When checking form defaults, Then fieldIndex is 0 and values are empty',
        () {
          final state = TuiState();

          expect(state.formFieldIndex, 0);
          expect(state.formValues, isEmpty);
          expect(state.formAuthType, AuthType.password);
        },
      );

      test(
        'Given formValues set, When calling formValue, Then returns correct value',
        () {
          final state = TuiState(formValues: {'name': 'my-server'});

          expect(state.formValue('name'), 'my-server');
          expect(state.formValue('host'), '');
          expect(state.formValue('port', fallback: '22'), '22');
        },
      );

      test(
        'Given formValues, When calling setFormValue, Then updates value',
        () {
          final state = TuiState(formValues: {'name': 'old'});
          state.setFormValue('name', 'new');

          expect(state.formValue('name'), 'new');
        },
      );

      test(
        'Given formValues setFormValue, When setting new key, Then adds to map',
        () {
          final state = TuiState();
          state.setFormValue('host', '10.0.0.1');

          expect(state.formValue('host'), '10.0.0.1');
        },
      );

      test(
        'Given complete formValues, When calling buildConnection, Then returns valid SshConnection',
        () {
          final state = TuiState(
            formValues: {
              'name': 'my-server',
              'host': '10.0.0.1',
              'port': '2222',
              'username': 'admin',
            },
          );

          final conn = state.buildConnection();
          expect(conn, isNotNull);
          expect(conn!.name, 'my-server');
          expect(conn.host, '10.0.0.1');
          expect(conn.port, 2222);
          expect(conn.username, 'admin');
          expect(conn.authType, AuthType.password);
        },
      );

      test(
        'Given incomplete formValues, When calling buildConnection, Then returns null',
        () {
          final state = TuiState(formValues: {'name': 'partial'});

          expect(state.buildConnection(), isNull);
        },
      );

      test(
        'Given editConn, When calling buildConnection, Then preserves original id',
        () {
          final conn = _conn(name: 'original');
          final state = TuiState(
            editConn: conn,
            formValues: {
              'name': 'renamed',
              'host': '10.0.0.1',
              'port': '22',
              'username': 'root',
            },
          );

          final result = state.buildConnection();
          expect(result, isNotNull);
          expect(result!.id, 'test-id');
          expect(result.name, 'renamed');
        },
      );

      test(
        'Given non-default authType, When building, Then preserves authType',
        () {
          final state = TuiState(
            formAuthType: AuthType.key,
            formValues: {
              'name': 'key-auth',
              'host': '10.0.0.1',
              'port': '22',
              'username': 'admin',
              'privateKeyPath': '/home/user/.ssh/id_rsa',
            },
          );

          final conn = state.buildConnection();
          expect(conn, isNotNull);
          expect(conn!.authType, AuthType.key);
          expect(conn.privateKeyPath, '/home/user/.ssh/id_rsa');
        },
      );

      test(
        'Given authType keyWithPassword, When building, Then includes passphrase',
        () {
          final state = TuiState(
            formAuthType: AuthType.keyWithPassword,
            formValues: {
              'name': 'k+p',
              'host': '10.0.0.1',
              'port': '22',
              'username': 'admin',
              'password': 'secret123',
              'privateKeyPath': '/home/user/.ssh/id_rsa',
              'keyPassphrase': 'mypass',
            },
          );

          final conn = state.buildConnection();
          expect(conn, isNotNull);
          expect(conn!.password, 'secret123');
          expect(conn.privateKeyPath, '/home/user/.ssh/id_rsa');
          expect(conn.keyPassphrase, 'mypass');
        },
      );
    });
  });
}
