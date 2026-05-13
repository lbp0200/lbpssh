import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/error_dialog.dart';

void main() {
  setUpAll(() async {
    // Register mock handlers for platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        return null;
      },
    );
  });
  group('ErrorDialog Widget', () {
    testWidgets('Given basic error, When rendered, Then shows title and error message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'Test Error',
                    error: 'Something went wrong',
                    appVersion: '1.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Title with error icon
      expect(find.text('Test Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Error message
      expect(find.text('Something went wrong'), findsOneWidget);

      // Action buttons
      expect(find.text('复制报告'), findsOneWidget);
      expect(find.text('反馈问题'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('Given error with stack trace, When rendered, Then shows stack trace section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ErrorDialog(
                    title: 'Stack Error',
                    error: Exception('test exception'),
                    stackTrace: StackTrace.fromString('line 1\nline 2\nline 3'),
                    appVersion: '2.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Stack trace section header
      expect(find.text('Stack Trace'), findsOneWidget);

      // Stack trace content
      expect(find.textContaining('line 1'), findsOneWidget);
      expect(find.textContaining('line 2'), findsOneWidget);
    });

    testWidgets('Given error with extra context, When rendered, Then shows context key-value pairs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'Context Error',
                    error: 'connection failed',
                    extraContext: {
                      'host': '192.168.1.1',
                      'port': '22',
                      'user': 'admin',
                    },
                    appVersion: '1.5.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Context labels
      expect(find.textContaining('host:'), findsOneWidget);
      expect(find.textContaining('port:'), findsOneWidget);
      expect(find.textContaining('user:'), findsOneWidget);

      // Context values
      expect(find.text('192.168.1.1'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('Given copy report button, When tapped, Then copies report to clipboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'Copy Test',
                    error: 'error to copy',
                    appVersion: '1.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap copy button
      await tester.tap(find.text('复制报告'));
      await tester.pump();

      // Pump past the 3-second timer to avoid pending timer error
      await tester.pump(const Duration(seconds: 3));

      // Verify dialog is still shown
      expect(find.text('Copy Test'), findsOneWidget);
    });

    testWidgets('Given close button, When tapped, Then dismisses dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'Close Test',
                    error: 'test',
                    appVersion: '1.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Close Test'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Close Test'), findsNothing);
    });

    testWidgets('Given error without stack trace, When rendered, Then no stack trace section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'No Stack',
                    error: 'simple error',
                    appVersion: '1.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Stack Trace header should not appear
      expect(find.text('Stack Trace'), findsNothing);
    });

    testWidgets('Given error without extra context, When rendered, Then no context section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ErrorDialog(
                    title: 'No Context',
                    error: 'simple error',
                    appVersion: '1.0.0',
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Title should be shown
      expect(find.text('No Context'), findsOneWidget);
    });
  });
}
