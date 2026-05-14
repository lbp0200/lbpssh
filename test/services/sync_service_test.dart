import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/data/repositories/connection_repository.dart';

// Mock classes
class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockDio extends Mock implements Dio {}

// Register fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(
    SyncConfig(
      platform: SyncPlatform.githubRepo,
      accessToken: 'test_token',
      repoOwner: 'test_owner',
      repoName: 'test_repo',
    ),
  );
  registerFallbackValue(
    SshConnection(
      id: 'test_id',
      name: 'Test Server',
      host: '192.168.1.1',
      port: 22,
      username: 'testuser',
      authType: AuthType.password,
    ),
  );
  registerFallbackValue(Options());
  registerFallbackValue(RequestOptions(path: ''));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValues();

  // =======================================================================
  // SyncConfig tests
  // =======================================================================
  group('SyncConfig', () {
    test(
      'Given required fields, When creating SyncConfig, Then uses default values for optional fields',
      () {
        final config = SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'test_token',
          repoOwner: 'test_owner',
          repoName: 'test_repo',
        );

        expect(config.platform, SyncPlatform.githubRepo);
        expect(config.accessToken, 'test_token');
        expect(config.repoOwner, 'test_owner');
        expect(config.repoName, 'test_repo');
        expect(config.autoSync, false);
        expect(config.syncIntervalMinutes, 5);
      },
    );

    test(
      'Given SyncConfig with all fields, When serializing to JSON, Then produces correct JSON',
      () {
        final config = SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'my_owner',
          repoName: 'my_repo',
          branch: 'main',
          autoSync: true,
          syncIntervalMinutes: 60,
        );

        final json = config.toJson();

        expect(json['platform'], 'githubRepo');
        expect(json['accessToken'], 'token123');
        expect(json['repoOwner'], 'my_owner');
        expect(json['repoName'], 'my_repo');
        expect(json['branch'], 'main');
        expect(json['autoSync'], true);
        expect(json['syncIntervalMinutes'], 60);
      },
    );

    test(
      'Given valid JSON with all fields, When deserializing, Then creates SyncConfig correctly',
      () {
        final json = {
          'platform': 'githubRepo',
          'accessToken': 'token456',
          'repoOwner': 'owner456',
          'repoName': 'repo456',
          'branch': 'develop',
          'autoSync': true,
          'syncIntervalMinutes': 45,
        };

        final config = SyncConfig.fromJson(json);

        expect(config.platform, SyncPlatform.githubRepo);
        expect(config.accessToken, 'token456');
        expect(config.repoOwner, 'owner456');
        expect(config.repoName, 'repo456');
        expect(config.branch, 'develop');
        expect(config.autoSync, true);
        expect(config.syncIntervalMinutes, 45);
      },
    );

    test(
      'Given JSON with missing optional fields, When deserializing, Then uses default values',
      () {
        final json = {'platform': 'githubRepo'};

        final config = SyncConfig.fromJson(json);

        expect(config.platform, SyncPlatform.githubRepo);
        expect(config.accessToken, isNull);
        expect(config.repoOwner, isNull);
        expect(config.repoName, isNull);
        expect(config.branch, isNull);
        expect(config.autoSync, false);
        expect(config.syncIntervalMinutes, 5);
      },
    );

    test(
      'Given legacy platform name gist, When deserializing, Then maps to githubRepo',
      () {
        final json = {'platform': 'gist'};
        final config = SyncConfig.fromJson(json);
        expect(config.platform, SyncPlatform.githubRepo);
      },
    );

    test(
      'Given legacy platform name giteeGist, When deserializing, Then maps to githubRepo',
      () {
        final json = {'platform': 'giteeGist'};
        final config = SyncConfig.fromJson(json);
        expect(config.platform, SyncPlatform.githubRepo);
      },
    );

    test(
      'Given unknown platform name, When deserializing, Then defaults to githubRepo',
      () {
        final json = {'platform': 'unknown_platform'};
        final config = SyncConfig.fromJson(json);
        expect(config.platform, SyncPlatform.githubRepo);
      },
    );
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
      },
    );
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
      },
    );
  });

  // =======================================================================
  // SyncPlatform enum tests
  // =======================================================================
  group('SyncPlatform', () {
    test(
      'Given SyncPlatform enum, When accessing name, Then returns correct values',
      () {
        expect(SyncPlatform.githubRepo.name, 'githubRepo');
      },
    );
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
      },
    );
  });

  // =======================================================================
  // SyncService - config persistence
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
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.status, SyncStatusEnum.idle);
    });

    test('saveConfig stores config and getConfig returns it', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final config = SyncConfig(
        platform: SyncPlatform.githubRepo,
        accessToken: 'token123',
        repoOwner: 'owner123',
        repoName: 'repo123',
        branch: 'main',
        autoSync: true,
        syncIntervalMinutes: 30,
      );

      await service.saveConfig(config);

      expect(service.getConfig(), isNotNull);
      expect(service.getConfig()!.platform, SyncPlatform.githubRepo);
      expect(service.getConfig()!.accessToken, 'token123');
      expect(service.getConfig()!.repoOwner, 'owner123');
      expect(service.getConfig()!.repoName, 'repo123');
      expect(service.getConfig()!.branch, 'main');
      expect(service.getConfig()!.autoSync, true);
      expect(service.getConfig()!.syncIntervalMinutes, 30);
    });

    test('saveConfig overwrites previous config', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'tokenA',
          repoOwner: 'ownerA',
          repoName: 'repoA',
        ),
      );

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'tokenB',
          repoOwner: 'ownerB',
          repoName: 'repoB',
          branch: 'develop',
        ),
      );

      expect(service.getConfig()!.platform, SyncPlatform.githubRepo);
      expect(service.getConfig()!.accessToken, 'tokenB');
      expect(service.getConfig()!.repoOwner, 'ownerB');
      expect(service.getConfig()!.repoName, 'repoB');
      expect(service.getConfig()!.branch, 'develop');
    });

    test('lastSyncTime is null before any sync', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.lastSyncTime, isNull);
    });
  });

  // =======================================================================
  // SyncService - uploadConfig (GitHub Repo Contents API)
  // =======================================================================
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
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('uploadConfig throws when config has no accessToken', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(SyncConfig(platform: SyncPlatform.githubRepo));

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('uploadConfig throws when config has no repoOwner', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('请设置 GitHub 仓库信息'),
          ),
        ),
      );
    });

    test('uploadConfig throws when config has no repoName', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      expect(
        () => service.uploadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('请设置 GitHub 仓库信息'),
          ),
        ),
      );
    });

    test('status changes during uploadConfig to success', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      // First GET to check existing file -> 404 (file doesn't exist)
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: ''),
          ),
        ),
      );

      // Then PUT to create the file
      when(
        () => mockDio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'content': {'sha': 'new_sha'},
          },
          statusCode: 201,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final future = service.uploadConfig();

      // Status should transition to syncing
      expect(service.status, SyncStatusEnum.syncing);

      await future;
      expect(service.status, SyncStatusEnum.success);
    });

    test('lastSyncTime updates after successful upload', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: ''),
          ),
        ),
      );

      when(
        () => mockDio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'content': {'sha': 'new_sha'},
          },
          statusCode: 201,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final before = DateTime.now();
      await service.uploadConfig();
      final after = DateTime.now();

      expect(service.lastSyncTime, isNotNull);
      expect(
        service.lastSyncTime!.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
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
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // GET 抛出后 catch 块会吞掉，然后继续调用 PUT
      when(
        () => mockDio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(service.uploadConfig(), throwsA(isA<DioException>()));
      expect(service.status, SyncStatusEnum.error);
    });

    test('uploadConfig updates existing file when SHA exists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      // First GET succeeds (file exists with SHA)
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'content': base64Encode(
              utf8.encode(
                jsonEncode({
                  'version': 1,
                  'timestamp': DateTime.now().toIso8601String(),
                  'connections': <Map<String, dynamic>>[],
                }),
              ),
            ),
            'sha': 'existing_sha',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Then PUT updates the file
      when(
        () => mockDio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'content': {'sha': 'updated_sha'},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await service.uploadConfig();
      expect(service.status, SyncStatusEnum.success);
    });

    test('uploadConfig sends correct PUT body to GitHub API', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: ''),
          ),
        ),
      );

      when(
        () => mockDio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: {
            'content': {'sha': 'new_sha'},
          },
          statusCode: 201,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await service.uploadConfig();

      verify(
        () => mockDio.put<Map<String, dynamic>>(
          'https://api.github.com/repos/owner123/repo123/contents/lbpSSH/ssh_connections.json',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });

  // =======================================================================
  // SyncService - downloadConfig (GitHub Repo Contents API)
  // =======================================================================
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
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        () => service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('同步配置未设置或未授权'),
          ),
        ),
      );
    });

    test('downloadConfig throws when config has no repoOwner', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveConfig(
        SyncConfig(platform: SyncPlatform.githubRepo, accessToken: 'token123'),
      );

      expect(
        () => service.downloadConfig(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('请设置 GitHub 仓库信息'),
          ),
        ),
      );
    });

    test('downloadConfig sets status to success on success', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      // GitHub Repo Contents API returns content as base64
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'content': base64Encode(
              utf8.encode(
                jsonEncode({
                  'version': 1,
                  'timestamp': DateTime.now().toIso8601String(),
                  'connections': <Map<String, dynamic>>[],
                }),
              ),
            ),
            'sha': 'file_sha',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([]);
      when(
        () => mockRepository.saveConnections(any()),
      ).thenAnswer((_) async {});

      await service.downloadConfig();

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });

    test(
      'downloadConfig with skipConflictCheck skips conflict detection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(
            platform: SyncPlatform.githubRepo,
            accessToken: 'token123',
            repoOwner: 'owner123',
            repoName: 'repo123',
          ),
        );

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'content': base64Encode(
                utf8.encode(
                  jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': <Map<String, dynamic>>[],
                  }),
                ),
              ),
              'sha': 'file_sha',
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        );

        when(() => mockRepository.getAllConnections()).thenReturn([]);
        when(
          () => mockRepository.saveConnections(any()),
        ).thenAnswer((_) async {});

        await service.downloadConfig(skipConflictCheck: true);

        expect(service.status, SyncStatusEnum.success);
        verify(() => mockRepository.saveConnections(any())).called(1);
      },
    );

    test('downloadConfig sets status to error on Dio failure', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(service.downloadConfig(), throwsA(isA<DioException>()));
      expect(service.status, SyncStatusEnum.error);
    });
  });

  // =======================================================================
  // SyncService - conflict detection
  // =======================================================================
  group('SyncService - conflict detection', () {
    late MockConnectionRepository mockRepository;
    late MockDio mockDio;

    setUp(() {
      mockRepository = MockConnectionRepository();
      mockDio = MockDio();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'detects conflict when version differs and local.updatedAt > remote.updatedAt',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SyncService(mockRepository, dio: mockDio);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await service.saveConfig(
          SyncConfig(
            platform: SyncPlatform.githubRepo,
            accessToken: 'token123',
            repoOwner: 'owner123',
            repoName: 'repo123',
          ),
        );

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

        final localConn2 = SshConnection(
          id: 'conn2',
          name: 'Same',
          host: '192.168.1.2',
          port: 22,
          username: 'user',
          authType: AuthType.password,
          version: 1,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 5),
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
        final remoteJson2 = {
          'id': 'conn2',
          'name': 'Same',
          'host': '192.168.1.2',
          'port': 22,
          'username': 'user',
          'authType': 'password',
          'version': 1,
          'createdAt': DateTime(2024, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2024, 1, 5).toIso8601String(),
        };

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'content': base64Encode(
                utf8.encode(
                  jsonEncode({
                    'version': 1,
                    'timestamp': DateTime.now().toIso8601String(),
                    'connections': [remoteJson, remoteJson2],
                  }),
                ),
              ),
              'sha': 'file_sha',
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        );

        when(
          () => mockRepository.getAllConnections(),
        ).thenReturn([localConn, localConn2]);

        dynamic exception;
        try {
          await service.downloadConfig();
        } catch (e) {
          exception = e;
        }
        expect(exception, isA<SyncConflictException>());
        expect((exception as SyncConflictException).conflicts.length, 1);
        expect(service.status, SyncStatusEnum.error);
      },
    );

    test('no conflict when remote unchanged (same version)', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SyncService(mockRepository, dio: mockDio);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.saveConfig(
        SyncConfig(
          platform: SyncPlatform.githubRepo,
          accessToken: 'token123',
          repoOwner: 'owner123',
          repoName: 'repo123',
        ),
      );

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

      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'content': base64Encode(
              utf8.encode(
                jsonEncode({
                  'version': 1,
                  'timestamp': DateTime.now().toIso8601String(),
                  'connections': [remoteJson],
                }),
              ),
            ),
            'sha': 'file_sha',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockRepository.getAllConnections()).thenReturn([localConn]);
      when(
        () => mockRepository.saveConnections(any()),
      ).thenAnswer((_) async {});

      await service.downloadConfig();

      expect(service.status, SyncStatusEnum.success);
      verify(() => mockRepository.saveConnections(any())).called(1);
    });
  });
}
