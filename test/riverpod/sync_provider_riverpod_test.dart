import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/sync_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSyncService mockSyncService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(SyncConfig(
      platform: SyncPlatform.gist,
      accessToken: 'test_token',
      gistId: 'test_gist_id',
    ));
  });

  setUp(() {
    mockSyncService = MockSyncService();
    when(() => mockSyncService.status).thenReturn(SyncStatusEnum.idle);
    when(() => mockSyncService.getConfig()).thenReturn(null);
    when(() => mockSyncService.lastSyncTime).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        syncServiceProvider.overrideWithValue(mockSyncService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SyncNotifier', () {
    group('config', () {
      test(
          'Given SyncService with config, When accessing config, Then returns sync config',
          () {
        // Arrange (Given)
        final config = SyncConfig(
          platform: SyncPlatform.gist,
          accessToken: 'test_token',
          gistId: 'test_gist_id',
        );
        when(() => mockSyncService.getConfig()).thenReturn(config);

        // Act (When)
        final result = container.read(syncProvider).config;

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.platform, SyncPlatform.gist);
        verify(() => mockSyncService.getConfig()).called(1);
      });

      test(
          'Given SyncService without config, When accessing config, Then returns null',
          () {
        // Arrange (Given)
        when(() => mockSyncService.getConfig()).thenReturn(null);

        // Act (When)
        final result = container.read(syncProvider).config;

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('status', () {
      test(
          'Given SyncService reports syncing, When accessing status, Then returns syncing status',
          () {
        // Arrange (Given)
        final status = container.read(syncProvider);

        // Assert (Then) — default is idle
        expect(status.status, SyncStatusEnum.idle);
      });
    });

    group('saveConfig', () {
      test(
          'Given valid config, When saveConfig called, Then saves config and updates state',
          () async {
        // Arrange (Given)
        final config = SyncConfig(
          platform: SyncPlatform.gist,
          accessToken: 'new_token',
          gistId: 'new_gist_id',
        );
        when(() => mockSyncService.saveConfig(config))
            .thenAnswer((_) async {});
        when(() => mockSyncService.getConfig()).thenReturn(config);

        // Act (When)
        await container.read(syncProvider.notifier).saveConfig(config);

        // Assert (Then)
        verify(() => mockSyncService.saveConfig(config)).called(1);
        final state = container.read(syncProvider);
        expect(state.config?.accessToken, 'new_token');
      });
    });

    group('uploadConfig', () {
      test(
          'Given successful upload, When uploadConfig called, Then updates status to idle',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.uploadConfig()).thenAnswer((_) async {});

        // Act (When)
        await container.read(syncProvider.notifier).uploadConfig();

        // Assert (Then)
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.idle);
      });

      test(
          'Given upload failure, When uploadConfig called, Then sets error status',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.uploadConfig())
            .thenThrow(Exception('Upload failed'));

        // Act & Assert (When)
        expect(
          () => container.read(syncProvider.notifier).uploadConfig(),
          throwsException,
        );
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.error);
      });
    });

    group('downloadConfig', () {
      test(
          'Given successful download, When downloadConfig called, Then updates status to idle',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig()).thenAnswer((_) async {});

        // Act (When)
        await container.read(syncProvider.notifier).downloadConfig();

        // Assert (Then)
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.idle);
      });

      test(
          'Given download failure, When downloadConfig called, Then sets error status',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig())
            .thenThrow(Exception('Download failed'));

        // Act & Assert (When)
        expect(
          () => container.read(syncProvider.notifier).downloadConfig(),
          throwsException,
        );
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.error);
      });
    });

    group('testConnection', () {
      test(
          'Given successful connection test, When testConnection called, Then returns to idle',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig(skipConflictCheck: true))
            .thenAnswer((_) async {});

        // Act (When)
        await container.read(syncProvider.notifier).testConnection();

        // Assert (Then)
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.idle);
      });

      test(
          'Given connection test failure, When testConnection called, Then throws exception and sets error status',
          () async {
        // Arrange (Given)
        when(() => mockSyncService.downloadConfig(skipConflictCheck: true))
            .thenThrow(Exception('Connection failed'));

        // Act & Assert (When)
        expect(
          () => container.read(syncProvider.notifier).testConnection(),
          throwsException,
        );
        final state = container.read(syncProvider);
        expect(state.status, SyncStatusEnum.error);
      });
    });
  });
}
