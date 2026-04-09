import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';

/// Creates a connection with required fields for testing.
SshConnection createTestConnection({
  String? id,
  String? name,
  String? host,
  int? port,
  String? username,
  AuthType? authType,
}) {
  return SshConnection(
    id: id ?? 'test-id',
    name: name ?? 'Test Server',
    host: host ?? '192.168.1.1',
    port: port ?? 22,
    username: username ?? 'user',
    authType: authType ?? AuthType.password,
  );
}

void main() {
  group('ConnectionRepository', () {
    late ConnectionRepository repo;
    late File _configFile;

    setUp(() async {
      // Create a fresh temp file per test.
      final tempDir = await Directory.systemTemp.createTemp('lbp_ssh_repo_test_');
      _configFile = File('${tempDir.path}/ssh_connections.json');
      await _configFile.writeAsString('[]');

      repo = ConnectionRepository(configFile: _configFile);
      await repo.init();
    });

    tearDown(() async {
      await repo.close();
      final dir = _configFile.parent;
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('getAllConnections returns cached connections', () async {
      final connection =
          createTestConnection(id: 'conn-1', name: 'Server 1');
      await repo.saveConnection(connection);

      final result = repo.getAllConnections();

      expect(result.length, 1);
      expect(result.first.id, 'conn-1');
      expect(result.first.name, 'Server 1');
    });

    test('getConnectionById returns correct connection', () async {
      final connection =
          createTestConnection(id: 'conn-2', name: 'Server 2');
      await repo.saveConnection(connection);

      final result = repo.getConnectionById('conn-2');

      expect(result, isNotNull);
      expect(result!.id, 'conn-2');
      expect(result.name, 'Server 2');
    });

    test('getConnectionById returns null for unknown ID', () {
      final result = repo.getConnectionById('non-existent-id');
      expect(result, isNull);
    });

    test('deleteConnection removes from cache', () async {
      final connection =
          createTestConnection(id: 'conn-3', name: 'Server 3');
      await repo.saveConnection(connection);
      expect(repo.getConnectionById('conn-3'), isNotNull);

      await repo.deleteConnection('conn-3');

      expect(repo.getConnectionById('conn-3'), isNull);
    });

    test('saveConnections replaces all connections', () async {
      final list = [
        createTestConnection(id: 'conn-a', name: 'A'),
        createTestConnection(id: 'conn-b', name: 'B'),
      ];

      await repo.saveConnections(list);

      final result = repo.getAllConnections();
      expect(result.length, 2);
      expect(result.map((c) => c.id).toSet(), {'conn-a', 'conn-b'});
    });

    test('clearAll empties repository', () async {
      await repo.saveConnection(createTestConnection(id: 'x', name: 'X'));
      await repo.saveConnection(createTestConnection(id: 'y', name: 'Y'));
      expect(repo.getAllConnections().length, 2);

      await repo.clearAll();

      expect(repo.getAllConnections(), isEmpty);
    });

    test('close succeeds without throwing', () async {
      await repo.close();
    });
  });
}
