import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/connection_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

void main() {
  late MockConnectionRepository mockRepo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(SshConnection(
      id: 'test_id',
      name: 'Test Server',
      host: '192.168.1.1',
      port: 22,
      username: 'testuser',
      authType: AuthType.password,
    ));
  });

  setUp(() {
    mockRepo = MockConnectionRepository();
    container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ConnectionNotifier', () {
    group('initial state', () {
      test('Given new provider, When created, Then has loading state with empty connections', () {
        final state = container.read(connectionProvider);
        expect(state.connections, isEmpty);
        expect(state.isLoading, true); // build() returns loading state
        expect(state.error, isNull);
        expect(state.searchQuery, '');
      });
    });

    group('loadConnections', () {
      test(
          'Given successful repository call, When loadConnections called, Then loads connections and clears error',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepo.getAllConnections()).thenReturn(connections);

        // Act (When)
        await container.read(connectionProvider.notifier).loadConnections();

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.connections.length, 1);
        expect(state.connections.first.name, 'Server 1');
        expect(state.isLoading, false);
        expect(state.error, isNull);
        // getAllConnections is called once by _load microtask + once by loadConnections()
        verify(() => mockRepo.getAllConnections()).called(2);
      });

      test(
          'Given repository throws error, When loadConnections called, Then sets error and stops loading',
          () async {
        // Arrange (Given)
        when(() => mockRepo.getAllConnections())
            .thenThrow(Exception('Failed to load'));

        // Act (When)
        await container.read(connectionProvider.notifier).loadConnections();

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.connections, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, isNotNull);
        expect(state.error, contains('加载连接失败'));
      });
    });

    group('addConnection', () {
      test(
          'Given valid connection, When addConnection called, Then saves to repository and reloads',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'new_conn',
          name: 'New Server',
          host: '192.168.1.100',
          port: 22,
          username: 'newuser',
          authType: AuthType.password,
        );
        when(() => mockRepo.saveConnection(connection))
            .thenAnswer((_) async {});
        when(() => mockRepo.getAllConnections()).thenReturn([connection]);

        // Act (When)
        await container.read(connectionProvider.notifier).addConnection(connection);

        // Assert (Then)
        verify(() => mockRepo.saveConnection(connection)).called(1);
        // getAllConnections: _load microtask + loadConnections
        verify(() => mockRepo.getAllConnections()).called(2);
      });

      test(
          'Given repository throws error on add, When addConnection called, Then sets error and rethrows',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'new_conn',
          name: 'New Server',
          host: '192.168.1.100',
          port: 22,
          username: 'newuser',
          authType: AuthType.password,
        );
        when(() => mockRepo.saveConnection(connection))
            .thenThrow(Exception('Save failed'));

        // Act & Assert (When)
        expect(
          () => container.read(connectionProvider.notifier).addConnection(connection),
          throwsException,
        );
        final state = container.read(connectionProvider);
        expect(state.error, isNotNull);
        expect(state.error, contains('添加连接失败'));
      });
    });

    group('updateConnection', () {
      test(
          'Given valid connection, When updateConnection called, Then updates in repository and reloads',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Updated Server',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        when(() => mockRepo.saveConnection(connection))
            .thenAnswer((_) async {});
        when(() => mockRepo.getAllConnections()).thenReturn([connection]);

        // Act (When)
        await container.read(connectionProvider.notifier).updateConnection(connection);

        // Assert (Then)
        verify(() => mockRepo.saveConnection(connection)).called(1);
        // getAllConnections: _load microtask + loadConnections
        verify(() => mockRepo.getAllConnections()).called(2);
      });
    });

    group('deleteConnection', () {
      test(
          'Given connection id, When deleteConnection called, Then deletes from repository and reloads',
          () async {
        // Arrange (Given)
        const connectionId = 'conn1';
        when(() => mockRepo.deleteConnection(connectionId))
            .thenAnswer((_) async {});
        when(() => mockRepo.getAllConnections()).thenReturn([]);

        // Act (When)
        await container.read(connectionProvider.notifier).deleteConnection(connectionId);

        // Assert (Then)
        verify(() => mockRepo.deleteConnection(connectionId)).called(1);
        // getAllConnections: _load microtask + loadConnections
        verify(() => mockRepo.getAllConnections()).called(2);
      });

      test(
          'Given repository throws error on delete, When deleteConnection called, Then sets error',
          () async {
        // Arrange (Given)
        const connectionId = 'conn1';
        when(() => mockRepo.deleteConnection(connectionId))
            .thenThrow(Exception('Delete failed'));

        // Act & Assert (When)
        expect(
          () => container.read(connectionProvider.notifier).deleteConnection(connectionId),
          throwsException,
        );
        final state = container.read(connectionProvider);
        expect(state.error, isNotNull);
        expect(state.error, contains('删除连接失败'));
      });
    });

    group('getConnectionById', () {
      test(
          'Given existing connection id, When getConnectionById called, Then returns connection',
          () {
        // Arrange (Given)
        const connectionId = 'conn1';
        final connection = SshConnection(
          id: connectionId,
          name: 'Server 1',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        when(() => mockRepo.getConnectionById(connectionId))
            .thenReturn(connection);

        // Act (When)
        final result = container.read(connectionProvider.notifier).getConnectionById(connectionId);

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.id, connectionId);
        verify(() => mockRepo.getConnectionById(connectionId)).called(1);
      });

      test(
          'Given non-existing connection id, When getConnectionById called, Then returns null',
          () {
        // Arrange (Given)
        const connectionId = 'nonexistent';
        when(() => mockRepo.getConnectionById(connectionId))
            .thenReturn(null);

        // Act (When)
        final result = container.read(connectionProvider.notifier).getConnectionById(connectionId);

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('search and filter', () {
      test(
          'Given search query, When setSearchQuery called, Then updates search query',
          () {
        // Act (When)
        container.read(connectionProvider.notifier).setSearchQuery('prod');

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.searchQuery, 'prod');
      });

      test(
          'Given search query matching name, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Production Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Development Server',
            host: '192.168.2.2',
            port: 22,
            username: 'user2',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepo.getAllConnections()).thenReturn(connections);
        await container.read(connectionProvider.notifier).loadConnections();

        // Act (When)
        container.read(connectionProvider.notifier).setSearchQuery('Production');

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.filteredConnections.length, 1);
        expect(state.filteredConnections.first.name, 'Production Server');
      });

      test(
          'Given search query matching username, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'admin',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Server 2',
            host: '192.168.2.2',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepo.getAllConnections()).thenReturn(connections);
        await container.read(connectionProvider.notifier).loadConnections();

        // Act (When)
        container.read(connectionProvider.notifier).setSearchQuery('admin');

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.filteredConnections.length, 1);
        expect(state.filteredConnections.first.username, 'admin');
      });

      test(
          'Given case insensitive search, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Production Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepo.getAllConnections()).thenReturn(connections);
        await container.read(connectionProvider.notifier).loadConnections();

        // Act (When)
        container.read(connectionProvider.notifier).setSearchQuery('PRODUCTION');

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.filteredConnections.length, 1);
      });

      test(
          'Given search query with no match, When filteredConnections accessed, Then returns empty list',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepo.getAllConnections()).thenReturn(connections);
        await container.read(connectionProvider.notifier).loadConnections();

        // Act (When)
        container.read(connectionProvider.notifier).setSearchQuery('nonexistent');

        // Assert (Then)
        final state = container.read(connectionProvider);
        expect(state.filteredConnections, isEmpty);
      });

      test('Given clearSearch called, When accessed, Then searchQuery is empty', () {
        // Arrange
        container.read(connectionProvider.notifier).setSearchQuery('test');

        // Act
        container.read(connectionProvider.notifier).clearSearch();

        // Assert
        expect(container.read(connectionProvider).searchQuery, '');
      });
    });

    group('duplicate connection handling', () {
      test(
          'Given duplicate connection name, When adding, Then allows duplicate names',
          () async {
        // Arrange (Given)
        final connection1 = SshConnection(
          id: 'conn1',
          name: 'Server',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        final connection2 = SshConnection(
          id: 'conn2',
          name: 'Server',
          host: '192.168.1.2',
          port: 22,
          username: 'user2',
          authType: AuthType.password,
        );
        when(() => mockRepo.saveConnection(connection1))
            .thenAnswer((_) async {});
        when(() => mockRepo.getAllConnections()).thenReturn([connection1]);

        await container.read(connectionProvider.notifier).addConnection(connection1);

        when(() => mockRepo.saveConnection(connection2))
            .thenAnswer((_) async {});
        when(() => mockRepo.getAllConnections()).thenReturn([connection1, connection2]);

        // Act (When)
        await container.read(connectionProvider.notifier).addConnection(connection2);

        // Assert (Then)
        verify(() => mockRepo.saveConnection(connection2)).called(1);
      });
    });
  });
}
