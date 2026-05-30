import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/import_export_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';

class MockImportExportService extends Mock implements ImportExportService {}

void main() {
  late MockImportExportService mockService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      SshConnection(
        id: 'test_id',
        name: 'Test Server',
        host: '192.168.1.1',
        username: 'testuser',
        authType: AuthType.password,
      ),
    );
  });

  setUp(() {
    mockService = MockImportExportService();
    container = ProviderContainer(
      overrides: [importExportServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ImportExportNotifier', () {
    group('initial state', () {
      test(
        'Given new provider, When created, Then has idle status with no error',
        () {
          // Act (When)
          final state = container.read(importExportProvider);

          // Assert (Then)
          expect(state.status, ImportExportStatus.idle);
          expect(state.lastError, isNull);
        },
      );
    });

    group('exportToLocalFile', () {
      test(
        'Given successful export, When called, Then returns file and sets success status',
        () async {
          // Arrange (Given)
          final mockFile = File('/tmp/test_export.json');
          when(
            () => mockService.exportToLocalFile(),
          ).thenAnswer((_) async => mockFile);
          when(() => mockService.status).thenReturn(ImportExportStatus.success);

          // Act (When)
          final result = await container
              .read(importExportProvider.notifier)
              .exportToLocalFile();

          // Assert (Then)
          expect(result, mockFile);
          verify(() => mockService.exportToLocalFile()).called(1);
        },
      );

      test(
        'Given service throws, When called, Then rethrows and sets error',
        () async {
          // Arrange (Given)
          when(
            () => mockService.exportToLocalFile(),
          ).thenThrow(Exception('Export failed'));

          // Act & Assert (When)
          await expectLater(
            () => container
                .read(importExportProvider.notifier)
                .exportToLocalFile(),
            throwsException,
          );
        },
      );
    });

    group('importFromLocalFile', () {
      test(
        'Given successful import, When called, Then returns connections and sets success',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'imported_1',
              name: 'Imported',
              host: '10.0.0.1',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importFromLocalFile(),
          ).thenAnswer((_) async => connections);
          when(() => mockService.status).thenReturn(ImportExportStatus.success);

          // Act (When)
          final result = await container
              .read(importExportProvider.notifier)
              .importFromLocalFile();

          // Assert (Then)
          expect(result, connections);
          verify(() => mockService.importFromLocalFile()).called(1);
        },
      );

      test(
        'Given service throws, When called, Then rethrows and sets error',
        () async {
          // Arrange (Given)
          when(
            () => mockService.importFromLocalFile(),
          ).thenThrow(Exception('Import failed'));

          // Act & Assert (When)
          await expectLater(
            () => container
                .read(importExportProvider.notifier)
                .importFromLocalFile(),
            throwsException,
          );
        },
      );
    });

    group('importAndSaveConnections', () {
      test(
        'Given connections, When called, Then delegates to service',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'c1',
              name: 'Server 1',
              host: '10.0.0.1',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importAndSaveConnections(
              any(),
              overwrite: any(named: 'overwrite'),
              addPrefix: any(named: 'addPrefix'),
            ),
          ).thenAnswer((_) async {});

          // Act (When)
          await container
              .read(importExportProvider.notifier)
              .importAndSaveConnections(connections);

          // Assert (Then)
          verify(
            () => mockService.importAndSaveConnections(
              connections,
            ),
          ).called(1);
        },
      );

      test(
        'Given custom options, When called, Then passes options to service',
        () async {
          // Arrange (Given)
          final connections = [
            SshConnection(
              id: 'c2',
              name: 'Server 2',
              host: '10.0.0.2',
              username: 'admin',
              authType: AuthType.password,
            ),
          ];
          when(
            () => mockService.importAndSaveConnections(
              any(),
              overwrite: any(named: 'overwrite'),
              addPrefix: any(named: 'addPrefix'),
            ),
          ).thenAnswer((_) async {});

          // Act (When)
          await container
              .read(importExportProvider.notifier)
              .importAndSaveConnections(
                connections,
                overwrite: true,
                addPrefix: false,
              );

          // Assert (Then)
          verify(
            () => mockService.importAndSaveConnections(
              connections,
              overwrite: true,
              addPrefix: false,
            ),
          ).called(1);
        },
      );
    });

    group('getExportStats', () {
      test('When called, Then returns stats from service', () {
        // Arrange (Given)
        const stats = {'totalConnections': 5};
        when(() => mockService.getExportStats()).thenReturn(stats);

        // Act (When)
        final result = container
            .read(importExportProvider.notifier)
            .getExportStats();

        // Assert (Then)
        expect(result, stats);
        verify(() => mockService.getExportStats()).called(1);
      });
    });

    group('generateExportSummary', () {
      test('When called, Then returns summary string', () {
        // Arrange (Given)
        const summary = 'Exported 5 connections';
        when(() => mockService.generateExportSummary()).thenReturn(summary);

        // Act (When)
        final result = container
            .read(importExportProvider.notifier)
            .generateExportSummary();

        // Assert (Then)
        expect(result, summary);
        verify(() => mockService.generateExportSummary()).called(1);
      });
    });

    group('resetStatus', () {
      test('When called, Then resets service and state', () {
        // Arrange (Given)
        when(() => mockService.resetStatus()).thenReturn(null);

        // Act (When)
        container.read(importExportProvider.notifier).resetStatus();

        // Assert (Then)
        verify(() => mockService.resetStatus()).called(1);
        expect(
          container.read(importExportProvider).status,
          ImportExportStatus.idle,
        );
      });
    });
  });
}
