import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/service_providers.dart';
import 'package:lbp_ssh/presentation/widgets/sync_status.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSyncService mockSyncService;

  setUp(() {
    mockSyncService = MockSyncService();
  });

  Widget createTestWidget({
    SyncStatusEnum status = SyncStatusEnum.idle,
    DateTime? lastSyncTime,
  }) {
    when(() => mockSyncService.status).thenReturn(status);
    when(() => mockSyncService.lastSyncTime).thenReturn(lastSyncTime);
    when(() => mockSyncService.getConfig()).thenReturn(null);

    return ProviderScope(
      overrides: [syncServiceProvider.overrideWithValue(mockSyncService)],
      child: const MaterialApp(home: Scaffold(body: SyncStatus())),
    );
  }

  group('SyncStatus Widget', () {
    testWidgets(
      'Given idle status, When rendered, Then shows 未同步 text and sync icon',
      (tester) async {
        await tester.pumpWidget(createTestWidget(status: SyncStatusEnum.idle));
        await tester.pump();

        expect(find.text('未同步'), findsOneWidget);
        expect(find.byIcon(Icons.sync), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'Given syncing status, When rendered, Then shows 同步中... text and CircularProgressIndicator',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(status: SyncStatusEnum.syncing),
        );
        await tester.pump();

        expect(find.text('同步中...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.sync), findsNothing);
      },
    );

    testWidgets(
      'Given success status, When rendered, Then shows 同步成功 text and check_circle icon',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(status: SyncStatusEnum.success),
        );
        await tester.pump();

        expect(find.text('同步成功'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'Given error status, When rendered, Then shows 同步失败 text and error icon',
      (tester) async {
        await tester.pumpWidget(createTestWidget(status: SyncStatusEnum.error));
        await tester.pump();

        expect(find.text('同步失败'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
      },
    );

    testWidgets(
      'Given lastSyncTime 30 minutes ago, When rendered, Then shows formatted time',
      (tester) async {
        final syncTime = DateTime.now().subtract(const Duration(minutes: 30));
        await tester.pumpWidget(
          createTestWidget(
            status: SyncStatusEnum.success,
            lastSyncTime: syncTime,
          ),
        );
        await tester.pump();

        expect(find.textContaining('分钟前'), findsOneWidget);
        expect(find.byKey(const Key('sync_status_time')), findsOneWidget);
      },
    );

    testWidgets(
      'Given no lastSyncTime, When rendered, Then does not show time text',
      (tester) async {
        await tester.pumpWidget(createTestWidget(status: SyncStatusEnum.idle));
        await tester.pump();

        expect(find.byKey(const Key('sync_status_time')), findsNothing);
      },
    );

    testWidgets(
      'Given all four statuses, When rendered, Then each has unique key text',
      (tester) async {
        // 验证所有四个状态的 widget key 都存在
        for (final status in SyncStatusEnum.values) {
          await tester.pumpWidget(createTestWidget(status: status));
          await tester.pump();

          // 每个状态都应该有 container key
          expect(
            find.byKey(const Key('sync_status_container')),
            findsOneWidget,
          );
        }
      },
    );
  });
}
