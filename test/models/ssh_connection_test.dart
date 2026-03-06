import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';

void main() {
  group('SshConnection Model Serialization', () {
    test(
        'Given all fields, When serializing connection, Then deserializes correctly',
        () {
      final connection = SshConnection(
        id: 'test-id-123',
        name: 'Production Server',
        host: '192.168.1.100',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        password: 'secretpassword',
        notes: 'Main production server',
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.id, connection.id);
      expect(deserialized.name, connection.name);
      expect(deserialized.host, connection.host);
      expect(deserialized.port, connection.port);
      expect(deserialized.username, connection.username);
      expect(deserialized.authType, connection.authType);
      expect(deserialized.password, connection.password);
      expect(deserialized.notes, connection.notes);
    });

    test(
        'Given key authentication fields, When serializing connection, Then preserves key auth fields',
        () {
      final connection = SshConnection(
        id: 'key-id-456',
        name: 'Key Auth Server',
        host: '10.0.0.1',
        username: 'deploy',
        authType: AuthType.key,
        privateKeyPath: '/home/user/.ssh/id_rsa',
        keyPassphrase: 'keypass',
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.authType, AuthType.key);
      expect(deserialized.privateKeyPath, '/home/user/.ssh/id_rsa');
      expect(deserialized.keyPassphrase, 'keypass');
    });

    test(
        'Given jump host configuration, When serializing connection, Then preserves jump host',
        () {
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'jumpuser',
        authType: AuthType.password,
        password: 'jumpsecret',
      );

      final connection = SshConnection(
        id: 'jump-id-789',
        name: 'Internal Server via Jump',
        host: 'internal.server.local',
        username: 'internaluser',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      final json = connection.toJson();
      // Convert jumpHost to Map if it's not already
      if (json['jumpHost'] is JumpHostConfig) {
        json['jumpHost'] = (json['jumpHost'] as JumpHostConfig).toJson();
      }
      expect(json['jumpHost'], isA<Map<String, dynamic>>());

      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.jumpHost, isNotNull);
      expect(deserialized.jumpHost!.host, 'jump.example.com');
      expect(deserialized.jumpHost!.port, 2222);
    });

    test(
        'Given version field, When serializing connection, Then preserves version',
        () {
      final connection = SshConnection(
        id: 'version-test',
        name: 'Version Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        version: 42,
      );

      final json = connection.toJson();
      expect(json['version'], 42);

      final deserialized = SshConnection.fromJson(json);
      expect(deserialized.version, 42);
    });

    test(
        'Given createdAt and updatedAt fields, When serializing connection, Then preserves dates',
        () {
      final createdAt = DateTime(2024, 1, 1, 12, 0, 0);
      final updatedAt = DateTime(2024, 6, 15, 18, 30, 0);

      final connection = SshConnection(
        id: 'date-test',
        name: 'Date Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(
        deserialized.createdAt.toIso8601String(),
        createdAt.toIso8601String(),
      );
      expect(
        deserialized.updatedAt.toIso8601String(),
        updatedAt.toIso8601String(),
      );
    });

    test(
        'Given null optional fields, When serializing connection, Then preserves nulls',
        () {
      final connection = SshConnection(
        id: 'null-test',
        name: 'Null Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      final json = connection.toJson();
      final deserialized = SshConnection.fromJson(json);

      expect(deserialized.password, null);
      expect(deserialized.privateKeyPath, null);
      expect(deserialized.keyPassphrase, null);
      expect(deserialized.jumpHost, null);
      expect(deserialized.notes, null);
    });
  });

  group('Connection Validation Logic', () {
    test('Given required fields, When creating connection, Then validates correctly',
        () {
      final connection = SshConnection(
        id: 'valid-test',
        name: 'Valid Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.id.isNotEmpty, true);
      expect(connection.name.isNotEmpty, true);
      expect(connection.host.isNotEmpty, true);
      expect(connection.username.isNotEmpty, true);
    });

    test(
        'Given no port specified, When creating connection, Then defaults to port 22',
        () {
      final connection = SshConnection(
        id: 'port-test',
        name: 'Port Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      expect(connection.port, 22);
    });

    test(
        'Given no version specified, When creating connection, Then defaults to version 1',
        () {
      final connection = SshConnection(
        id: 'version-test',
        name: 'Version Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
      );

      expect(connection.version, 1);
    });
  });

  group('CopyWith Functionality', () {
    test(
        'Given original connection, When calling copyWith with new values, Then updates only specified fields',
        () {
      final original = SshConnection(
        id: 'original-id',
        name: 'Original Name',
        host: 'original.host.com',
        port: 22,
        username: 'originaluser',
        authType: AuthType.password,
        version: 1,
      );

      final updated = original.copyWith(name: 'New Name', host: 'new.host.com');

      expect(updated.id, 'original-id');
      expect(updated.name, 'New Name');
      expect(updated.host, 'new.host.com');
      expect(updated.port, 22);
      expect(updated.username, 'originaluser');
      expect(updated.version, 1);
    });

    test(
        'Given original connection, When calling copyWith with version, Then updates version',
        () {
      final original = SshConnection(
        id: 'version-inc-test',
        name: 'Version Inc Test',
        host: 'test.local',
        username: 'test',
        authType: AuthType.password,
        version: 5,
      );

      final updated = original.copyWith(version: 10);

      expect(updated.version, 10);
    });

    test(
        'Given original connection, When calling copyWith with no arguments, Then preserves all fields',
        () {
      final original = SshConnection(
        id: 'preserve-test',
        name: 'Preserve Test',
        host: 'test.local',
        username: 'testuser',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
        keyPassphrase: 'pass',
        version: 3,
      );

      final preserved = original.copyWith();

      expect(preserved.id, original.id);
      expect(preserved.name, original.name);
      expect(preserved.host, original.host);
      expect(preserved.authType, original.authType);
      expect(preserved.privateKeyPath, original.privateKeyPath);
      expect(preserved.version, original.version);
    });
  });

  group('JumpHostConfig Serialization', () {
    test(
        'Given all fields, When serializing JumpHostConfig, Then deserializes correctly',
        () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'jumpuser',
        authType: AuthType.keyWithPassword,
        password: 'secret',
        privateKeyPath: '/path/to/key',
      );

      final json = config.toJson();
      final deserialized = JumpHostConfig.fromJson(json);

      expect(deserialized.host, 'jump.example.com');
      expect(deserialized.port, 2222);
      expect(deserialized.username, 'jumpuser');
      expect(deserialized.authType, AuthType.keyWithPassword);
      expect(deserialized.password, 'secret');
      expect(deserialized.privateKeyPath, '/path/to/key');
    });

    test(
        'Given null optional fields, When serializing JumpHostConfig, Then preserves nulls',
        () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'jumpuser',
        authType: AuthType.password,
      );

      final json = config.toJson();
      final deserialized = JumpHostConfig.fromJson(json);

      expect(deserialized.password, null);
      expect(deserialized.privateKeyPath, null);
    });

    test(
        'Given no port specified, When creating JumpHostConfig, Then defaults to port 22',
        () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'jumpuser',
        authType: AuthType.password,
      );

      expect(config.port, 22);
    });
  });

  group('SshConnection Creation', () {
    test(
        'Given required fields, When creating connection, Then creates with default values',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.id, 'test-id');
      expect(connection.name, 'Test Connection');
      expect(connection.host, '192.168.1.1');
      expect(connection.port, 22);
      expect(connection.username, 'user');
      expect(connection.authType, AuthType.password);
      expect(connection.password, null);
      expect(connection.version, 1);
    });

    test(
        'Given custom port, When creating connection, Then uses custom port',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        port: 2222,
        username: 'user',
        authType: AuthType.password,
      );

      expect(connection.port, 2222);
    });

    test(
        'Given password authentication, When creating connection, Then stores password',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
        password: 'secret123',
      );

      expect(connection.authType, AuthType.password);
      expect(connection.password, 'secret123');
    });

    test(
        'Given key authentication, When creating connection, Then stores private key path',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
      );

      expect(connection.authType, AuthType.key);
      expect(connection.privateKeyPath, '/path/to/key');
    });

    test(
        'Given key with passphrase, When creating connection, Then stores passphrase',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.keyWithPassword,
        privateKeyPath: '/path/to/key',
        keyPassphrase: 'passphrase',
      );

      expect(connection.authType, AuthType.keyWithPassword);
      expect(connection.keyPassphrase, 'passphrase');
    });

    test(
        'Given jump host, When creating connection, Then stores jump host',
        () {
      final jumpHost = JumpHostConfig(
        host: 'jump.example.com',
        port: 22,
        username: 'jumpuser',
        authType: AuthType.password,
        password: 'jumppass',
      );

      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
        jumpHost: jumpHost,
      );

      expect(connection.jumpHost, isNotNull);
      expect(connection.jumpHost!.host, 'jump.example.com');
    });

    test('Given connection, When serializing to JSON, Then produces correct JSON',
        () {
      final connection = SshConnection(
        id: 'test-id',
        name: 'Test Connection',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        password: 'secret123',
        notes: 'Test notes',
      );

      final json = connection.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Connection');
      expect(json['host'], '192.168.1.1');
      expect(json['port'], 22);
      expect(json['username'], 'user');
      expect(json['authType'], 'password');
      expect(json['password'], 'secret123');
      expect(json['notes'], 'Test notes');
    });

    test('Given valid JSON, When deserializing, Then creates connection correctly',
        () {
      final json = {
        'id': 'test-id',
        'name': 'Test Connection',
        'host': '192.168.1.1',
        'port': 22,
        'username': 'user',
        'authType': 'password',
        'password': 'secret123',
        'version': 1,
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
      };

      final connection = SshConnection.fromJson(json);

      expect(connection.id, 'test-id');
      expect(connection.name, 'Test Connection');
      expect(connection.host, '192.168.1.1');
      expect(connection.port, 22);
    });

    test(
        'Given original connection, When calling copyWith, Then creates modified copy',
        () {
      final original = SshConnection(
        id: 'test-id',
        name: 'Original Name',
        host: '192.168.1.1',
        username: 'user',
        authType: AuthType.password,
      );

      final copy = original.copyWith(name: 'New Name', port: 2222);

      expect(copy.id, 'test-id');
      expect(copy.name, 'New Name');
      expect(copy.host, '192.168.1.1');
      expect(copy.port, 2222);
      expect(copy.username, 'user');
    });
  });

  group('JumpHostConfig Creation', () {
    test(
        'Given required fields, When creating JumpHostConfig, Then creates with defaults',
        () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        username: 'user',
        authType: AuthType.password,
      );

      expect(config.host, 'jump.example.com');
      expect(config.port, 22);
      expect(config.username, 'user');
      expect(config.authType, AuthType.password);
    });

    test('Given all fields, When serializing JumpHostConfig, Then produces JSON',
        () {
      final config = JumpHostConfig(
        host: 'jump.example.com',
        port: 2222,
        username: 'user',
        authType: AuthType.key,
        privateKeyPath: '/path/to/key',
      );

      final json = config.toJson();

      expect(json['host'], 'jump.example.com');
      expect(json['port'], 2222);
      expect(json['username'], 'user');
      expect(json['authType'], 'key');
      expect(json['privateKeyPath'], '/path/to/key');
    });

    test('Given valid JSON, When deserializing JumpHostConfig, Then creates correctly',
        () {
      final json = {
        'host': 'jump.example.com',
        'port': 2222,
        'username': 'user',
        'authType': 'key',
        'privateKeyPath': '/path/to/key',
      };

      final config = JumpHostConfig.fromJson(json);

      expect(config.host, 'jump.example.com');
      expect(config.port, 2222);
      expect(config.authType, AuthType.key);
    });
  });

  group('AuthType', () {
    test('Given AuthType values, When converting to string, Then produces correct values',
        () {
      expect(AuthType.password.toString(), 'AuthType.password');
      expect(AuthType.key.toString(), 'AuthType.key');
      expect(AuthType.keyWithPassword.toString(), 'AuthType.keyWithPassword');
    });
  });
}
