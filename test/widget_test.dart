import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/domain/services/sync_service.dart';
import 'package:lbp_ssh/presentation/providers/sync_provider.dart';
import 'package:lbp_ssh/presentation/widgets/sync_status.dart';
import 'package:lbp_ssh/presentation/widgets/error_dialog.dart';

void main() {
  group('Widget Tests', () {
    group('SyncStatus Widget', () {
      testWidgets('Given SyncStatus idle, When rendered, Then shows sync icon', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<SyncProvider>(
              create: (_) => _TestSyncProvider(status: SyncStatusEnum.idle),
              child: const Scaffold(
                body: SyncStatus(),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byKey(const Key('sync_status_container')), findsOneWidget);
        expect(find.byKey(const Key('sync_status_icon')), findsOneWidget);
        expect(find.byKey(const Key('sync_status_text')), findsOneWidget);
        expect(find.text('未同步'), findsOneWidget);
      });

      testWidgets('Given SyncStatus syncing, When rendered, Then shows progress indicator', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<SyncProvider>(
              create: (_) => _TestSyncProvider(status: SyncStatusEnum.syncing),
              child: const Scaffold(
                body: SyncStatus(),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('同步中...'), findsOneWidget);
      });

      testWidgets('Given SyncStatus success, When rendered, Then shows check icon', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<SyncProvider>(
              create: (_) => _TestSyncProvider(status: SyncStatusEnum.success),
              child: const Scaffold(
                body: SyncStatus(),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byKey(const Key('sync_status_icon')), findsOneWidget);
        expect(find.text('同步成功'), findsOneWidget);
      });

      testWidgets('Given SyncStatus error, When rendered, Then shows error icon', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<SyncProvider>(
              create: (_) => _TestSyncProvider(status: SyncStatusEnum.error),
              child: const Scaffold(
                body: SyncStatus(),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byKey(const Key('sync_status_icon')), findsOneWidget);
        expect(find.text('同步失败'), findsOneWidget);
      });
    });

    group('ErrorDialog Widget', () {
      testWidgets('Given ErrorDialog, When rendered, Then shows all buttons', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorDialog(
                title: 'Test Error',
                error: 'Test error message',
                appVersion: '1.0.0',
              ),
            ),
          ),
        );

        // Assert - verify all buttons have Keys
        expect(find.byKey(const Key('error_dialog_copy_button')), findsOneWidget);
        expect(find.byKey(const Key('error_dialog_feedback_button')), findsOneWidget);
        expect(find.byKey(const Key('error_dialog_close_button')), findsOneWidget);

        // Verify button text
        expect(find.text('复制报告'), findsOneWidget);
        expect(find.text('反馈问题'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
      });

      testWidgets('Given ErrorDialog, When close button tapped, Then dialog closes', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ErrorDialog(
                        title: 'Test Error',
                        error: 'Test error message',
                        appVersion: '1.0.0',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Act - tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog is shown
        expect(find.byType(ErrorDialog), findsOneWidget);

        // Tap close button
        await tester.tap(find.byKey(const Key('error_dialog_close_button')));
        await tester.pumpAndSettle();

        // Assert - dialog should be closed
        expect(find.byType(ErrorDialog), findsNothing);
      });
    });
  });
}

/// Test helper: Mock SyncProvider for testing SyncStatus widget
/// Only implements properties used by SyncStatus widget
class _TestSyncProvider extends ChangeNotifier implements SyncProvider {
  @override
  final SyncStatusEnum status;

  @override
  final DateTime? lastSyncTime;

  _TestSyncProvider({required this.status, this.lastSyncTime});

  @override
  SyncConfig? get config => null;

  @override
  Future<void> saveConfig(SyncConfig config) async {}

  @override
  Future<void> uploadConfig() async {}

  @override
  Future<void> downloadConfig() async {}

  @override
  Future<void> testConnection() async {}
}
