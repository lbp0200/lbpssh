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
          final state = TuiState(connections: [
            _conn(name: 'server-1'),
            _conn(name: 'server-2'),
          ]);

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
  });
}
