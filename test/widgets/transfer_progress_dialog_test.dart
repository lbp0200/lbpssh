import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/presentation/widgets/transfer_progress_dialog.dart';

void main() {
  group('TransferProgressDialog Widget', () {
    testWidgets(
      'Given initial state, When rendered, Then shows file name and progress',
      (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create a stream that won't emit anything (no progress updates)
        final progressController =
            StreamController<TransferProgress>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransferProgressDialog(
                fileName: 'test_file.txt',
                totalBytes: 1024,
                progressStream: progressController.stream,
                onCancel: () {},
              ),
            ),
          ),
        );

        // Verify initial state
        expect(find.text('上传文件'), findsOneWidget);
        expect(find.text('文件: test_file.txt'), findsOneWidget);
        expect(find.text('0.0%'), findsOneWidget);
        expect(find.text('0 B / 1.0 KB'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      },
    );

    testWidgets(
      'Given progress updates, When progress changes, Then updates UI',
      (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Create a stream controller to simulate progress updates
        final progressController =
            StreamController<TransferProgress>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransferProgressDialog(
                fileName: 'test_file.txt',
                totalBytes: 1000,
                progressStream: progressController.stream,
                onCancel: () {},
              ),
            ),
          ),
        );

        // Emit progress update
        progressController.add(
          TransferProgress(
            fileName: 'test_file.txt',
            transferredBytes: 500,
            totalBytes: 1000,
            percent: 50.0,
            bytesPerSecond: 1000,
          ),
        );

        await tester.pumpAndSettle();

        // Verify progress update
        expect(find.text('50.0%'), findsOneWidget);
        // 500 bytes and 1000 bytes are both < 1024, so formatted as "500 B / 1000 B"
        expect(find.textContaining('500 B'), findsOneWidget);
        expect(find.text('速度: 1000 B/s'), findsOneWidget);
      },
    );

    testWidgets(
      'Given 100% progress, When progress reaches 100, Then shows completion',
      (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final progressController =
            StreamController<TransferProgress>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransferProgressDialog(
                fileName: 'complete.txt',
                totalBytes: 1024,
                progressStream: progressController.stream,
                onCancel: () {},
              ),
            ),
          ),
        );

        // Emit 100% progress
        progressController.add(
          TransferProgress(
            fileName: 'complete.txt',
            transferredBytes: 1024,
            totalBytes: 1024,
            percent: 100.0,
            bytesPerSecond: 50000,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('100.0%'), findsOneWidget);
        expect(find.text('1.0 KB / 1.0 KB'), findsOneWidget);
      },
    );

    testWidgets('Given cancel button, When tapped, Then calls onCancel', (
      WidgetTester tester,
    ) async {
      // Set up screen size
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool cancelCalled = false;
      final progressController = StreamController<TransferProgress>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferProgressDialog(
              fileName: 'test_file.txt',
              totalBytes: 1024,
              progressStream: progressController.stream,
              onCancel: () {
                cancelCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap cancel button
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });

    testWidgets(
      'Given small file size, When rendering, Then formats bytes correctly',
      (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final progressController =
            StreamController<TransferProgress>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransferProgressDialog(
                fileName: 'tiny.txt',
                totalBytes: 500,
                progressStream: progressController.stream,
                onCancel: () {},
              ),
            ),
          ),
        );

        // Verify initial byte display
        expect(find.text('0 B / 500 B'), findsOneWidget);
      },
    );

    testWidgets(
      'Given large file size, When rendering, Then formats MB correctly',
      (WidgetTester tester) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final progressController =
            StreamController<TransferProgress>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransferProgressDialog(
                fileName: 'large.zip',
                totalBytes: 50 * 1024 * 1024, // 50 MB
                progressStream: progressController.stream,
                onCancel: () {},
              ),
            ),
          ),
        );

        // Verify MB format
        expect(find.textContaining('MB'), findsOneWidget);
      },
    );
  });
}
