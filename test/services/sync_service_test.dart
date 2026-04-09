import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';
import 'package:lbp_ssh/core/constants/app_constants.dart';

// Mock classes
class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockDio extends Mock implements Dio {}

// Register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(SyncConfig(
    platform: SyncPlatform.gist,
    accessToken: 'test_token',
    gistId: 'test_gist_id',
  ));
  registerFallbackValue(SshConnection(
    id: 'test_id',
    name: 'Test Server',
    host: '192.168.1.1',
    port: 22,
    username: 'testuser',
    authType: AuthType.password,
  ));
  registerFallbackValue(Options());
  registerFallbackValue(RequestOptions(path: ''));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValues();

  // =======================================================================
  // SyncConfig tests (existing)
  // =======================================================================
  group('SyncConfig', () {
    test(
        'Given required fields, When creating SyncConfig, Then uses default values for optional fields',
        () {
      final config = SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'test_token',
        gistId: 'test_gist_id',
      );

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, 'test_token');
      expect(config.gistId, 'test_gist_id');
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 5);
    });

    test(
        'Given SyncConfig with all fields, When serializing to JSON, Then produces correct JSON',
        () {
      final config = SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'token123',
        gistId: 'gist123',
        gistFileName: 'config.json',
        autoSync: true,
        syncIntervalMinutes: 60,
      );

      final json = config.toJson();

      expect(json['platform'], 'giteeGist');
      expect(json['accessToken'], 'token123');
      expect(json['gistId'], 'gist123');
      expect(json['gistFileName'], 'config.json');
      expect(json['autoSync'], true);
      expect(json['syncIntervalMinutes'], 60);
    });

    test(
        'Given valid JSON with all fields, When deserializing, Then creates SyncConfig correctly',
        () {
      final json = {
        'platform': 'gist',
        'accessToken': 'token456',
        'gistId': 'gist456',
        'gistFileName': 'ssh_config.json',
        'autoSync': true,
        'syncIntervalMinutes': 45,
      };

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.gist);
      expect(config.accessToken, 'token456');
      expect(config.gistId, 'gist456');
      expect(config.gistFileName, 'ssh_config.json');
      expect(config.autoSync, true);
      expect(config.syncIntervalMinutes, 45);
    });

    test(
        'Given JSON with missing optional fields, When deserializing, Then uses default values',
        () {
      final json = {'platform': 'giteeGist'};

      final config = SyncConfig.fromJson(json);

      expect(config.platform, SyncPlatform.giteeGist);
      expect(config.accessToken, isNull);
      expect(config.gistId, isNull);
      expect(config.autoSync, false);
      expect(config.syncIntervalMinutes, 5);
    });
  });

  // =======================================================================
  // SyncConflict tests (existing)
  // =======================================================================
  group('SyncConflict', () {
    test(
        'Given local and remote connections, When creating SyncConflict, Then stores both connections',
        () {
      final localConnection = SshConnection(
        id: 'conn1',
        name: 'Local Server',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );
      final remoteConnection = SshConnection(
        id: 'conn1',
        name: 'Remote Server',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
      );

      final conflict = SyncConflict(
        connectionId: 'conn1',
        localConnection: localConnection,
        remoteConnection: remoteConnection,
      );

      expect(conflict.connectionId, 'conn1');
      expect(conflict.localConnection.name, 'Local Server');
      expect(conflict.remoteConnection.name, 'Remote Server');
    });
  });

  // =======================================================================
  // SyncConflictException tests (existing)
  // =======================================================================
  group('SyncConflictException', () {
    test(
        'Given list of conflicts, When creating SyncConflictException, Then stores conflicts',
        () {
      final conflicts = [
        SyncConflict(
          connectionId: 'conn1',
          localConnection: SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
          remoteConnection: SshConnection(
            id: 'conn1',
            name: 'Server 1 Updated',
            host: '192.168.1.1',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
        ),
      ];

      final exception = SyncConflictException(conflicts);

      expect(exception.conflicts.length, 1);
      expect(exception.toString(), contains('1'));
    });
  });

  // =======================================================================
  // SyncPlatform enum tests (existing)
  // =======================================================================
  group('SyncPlatform', () {
    test('Given SyncPlatform enum, When accessing name, Then returns correct values',
        () {
      expect(SyncPlatform.gist.name, 'gist');
      expect(SyncPlatform.giteeGist.name, 'giteeGist');
    });
  });

  // =======================================================================
  // SyncStatusEnum tests (existing)
  // =======================================================================
  group('SyncStatusEnum', () {
    test(
        'Given SyncStatusEnum enum, When accessing name, Then returns correct values',
        () {
      expect(SyncStatusEnum.idle.name, 'idle');
      expect(SyncStatusEnum.syncing.name, 'syncing');
      expect(SyncStatusEnum.success.name, 'success');
      expect(SyncStatusEnum.error.name, 'error');
    });
  });

  // =======================================================================
  // SyncService integration tests
  // =======================================================================
  group('SyncService - config persistence', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('initial status is idle', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(service.status, SyncStatusEnum.idle);
    });

    test('saveConfig stores config and getConfig returns it', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      final config = SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
        gistFileName: 'test.json',
        autoSync: true,
        syncIntervalMinutes: 30,
      );

      await service.saveConfig(config);

      expect(service.getConfig(), isNotNull);
      expect(service.getConfig()!.platform, SyncPlatform.gist);
      expect(service.getConfig()!.accessToken, 'token123');
      expect(service.getConfig()!.gistId, 'gist123');
      expect(service.getConfig()!.gistFileName, 'test.json');
      expect(service.getConfig()!.autoSync, true);
      expect(service.getConfig()!.syncIntervalMinutes, 30);
    });

    test('saveConfig overwrites previous config', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'tokenA',
      ));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'tokenB',
        gistId: 'gistB',
      ));

      expect(service.getConfig()!.platform, SyncPlatform.giteeGist);
      expect(service.getConfig()!.accessToken, 'tokenB');
      expect(service.getConfig()!.gistId, 'gistB');
    });

    test('lastSyncTime is null before any sync', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(service.lastSyncTime, isNull);
    });
  });

  group('SyncService - uploadConfig', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('uploadConfig throws when no config set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.uploadConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('同步配置未设置或未授权'),
        )),
      );
    });

    test('uploadConfig throws when config has no accessToken', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(SyncConfig(platform: SyncPlatform.gist));

      expect(
        () => service.uploadConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('同步配置未设置或未授权'),
        )),
      );
    });

    test('status changes during uploadConfig to success', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {'id': 'new_gist_id'},
        statusCode: 201,
        requestOptions: RequestOptions(path: ''),
      ));

      final future = service.uploadConfig();

      // Status should transition to syncing
      expect(service.status, SyncStatusEnum.syncing);

      await future;
      expect(service.status, SyncStatusEnum.success);
    });

    test('lastSyncTime updates after successful upload', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {'id': 'new_gist_id'},
        statusCode: 201,
        requestOptions: RequestOptions(path: ''),
      ));

      final before = DateTime.now();
      await service.uploadConfig();
      final after = DateTime.now();

      expect(service.lastSyncTime, isNotNull);
      expect(
        service.lastSyncTime!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        service.lastSyncTime!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('uploadConfig sets status to error on Dio failure', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      await expectLater(service.uploadConfig(), throwsA(isA<DioException>()));
      expect(service.status, SyncStatusEnum.error);
    });
  });

  group('SyncService - downloadConfig', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('downloadConfig throws when no config set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.downloadConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('同步配置未设置或未授权'),
        )),
      );
    });

    test('downloadConfig sets status to success on success', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
      ));

      // _downloadFromGitHubGist calls base64Encode(utf8.encode(file['content']))
      // so we provide the raw JSON string that gets encoded by the service
      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': <Map<String, dynamic>>[],
              }),
              'sha': 'file_sha',
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);
      when(() => mockRepository.saveConnections(any()))
          .thenAnswer((_) async {});

      await service.downloadConfig();

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test('downloadConfig with skipConflictCheck skips conflict detection',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
      ));

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': <Map<String, dynamic>>[],
              }),
              'sha': 'file_sha',
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      // Repository returns a local connection - without skipConflictCheck this
      // would trigger conflict detection
      when(() => mockRepository.getAllConnections()).thenReturn([
        SshConnection(
          id: 'conn1',
          name: 'Local Only',
          host: '192.168.1.1',
          port: 22,
          username: 'user',
          authType: AuthType.password,
          version: 2,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ]);
      when(() => mockRepository.saveConnections(any()))
          .thenAnswer((_) async {});

      // Should NOT throw SyncConflictException because skipConflictCheck is true
      await service.downloadConfig(skipConflictCheck: true);

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });
  });

  group('SyncService - conflict detection', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('no conflict when remote modified before local existed', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
      ));

      // Local: created Jan 1, updated Jan 10 (version 2)
      // Remote: created Dec 15, updated Dec 20 (version 1)
      // remote.updatedAt (Dec 20) > local.createdAt (Jan 1)? NO -> no conflict
      final localConn = SshConnection(
        id: 'conn1',
        name: 'Local Updated',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        version: 2,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 10),
      );

      final remoteJson = {
        'id': 'conn1',
        'name': 'Remote Older',
        'host': '192.168.1.1',
        'port': 22,
        'username': 'user',
        'authType': 'password',
        'version': 1,
        'createdAt': DateTime(2023, 12, 15).toIso8601String(),
        'updatedAt': DateTime(2023, 12, 20).toIso8601String(),
      };

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': [remoteJson],
              }),
              'sha': 'file_sha',
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([localConn]);
      when(() => mockRepository.saveConnections(any()))
          .thenAnswer((_) async {});

      // Should succeed without conflict
      await service.downloadConfig();

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test('detects conflict when both modified', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
      ));

      // Conflict conditions:
      // - version differs (local=2, remote=1)
      // - local.updatedAt (Jan 10) > remote.updatedAt (Jan 5)
      // - remote.updatedAt (Jan 5) > local.createdAt (Jan 1)
      final localConn = SshConnection(
        id: 'conn1',
        name: 'Local Newer',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        version: 2,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 10),
      );

      final remoteJson = {
        'id': 'conn1',
        'name': 'Remote Older',
        'host': '192.168.1.1',
        'port': 22,
        'username': 'user',
        'authType': 'password',
        'version': 1,
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 5).toIso8601String(),
      };

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': [remoteJson],
              }),
              'sha': 'file_sha',
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([localConn]);

      dynamic exception;
      try {
        await service.downloadConfig();
      } catch (e) {
        exception = e;
      }
      expect(exception, isA<SyncConflictException>());
      expect((exception as SyncConflictException).conflicts.length, 1);
      expect(service.status, SyncStatusEnum.error);
    });

    test('no conflict when remote unchanged (same version)', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.gist,
        accessToken: 'token123',
        gistId: 'gist123',
      ));

      // Same version - first condition (version !=) fails, no conflict
      final localConn = SshConnection(
        id: 'conn1',
        name: 'Local',
        host: '192.168.1.1',
        port: 22,
        username: 'user',
        authType: AuthType.password,
        version: 1,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 10),
      );

      final remoteJson = {
        'id': 'conn1',
        'name': 'Remote',
        'host': '192.168.1.1',
        'port': 22,
        'username': 'user',
        'authType': 'password',
        'version': 1,
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 5).toIso8601String(),
      };

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': [remoteJson],
              }),
              'sha': 'file_sha',
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([localConn]);
      when(() => mockRepository.saveConnections(any()))
          .thenAnswer((_) async {});

      await service.downloadConfig();

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });
  });

  group('SyncService - Gitee platform', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test('downloads from Gitee Gist successfully', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'gitee_token',
        gistId: 'gitee_gist_id',
      ));

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'files': {
            AppConstants.defaultSyncFileName: {
              'content': jsonEncode({
                'version': 1,
                'timestamp': DateTime.now().toIso8601String(),
                'connections': <Map<String, dynamic>>[],
              }),
            },
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);
      when(() => mockRepository.saveConnections(any()))
          .thenAnswer((_) async {});

      await service.downloadConfig(skipConflictCheck: true);

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test('uploads to Gitee Gist successfully', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(SyncConfig(
        platform: SyncPlatform.giteeGist,
        accessToken: 'gitee_token',
      ));

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {'id': 'gitee_new_gist_id'},
        statusCode: 201,
        requestOptions: RequestOptions(path: ''),
      ));

      await service.uploadConfig();

      expect(service.status, SyncStatusEnum.success);
      expect(service.getConfig()!.gistId, 'gitee_new_gist_id');
    });
  });
}
