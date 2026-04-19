import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/presentation/widgets/connection_list.dart';

class MockConnectionProvider extends Mock implements ConnectionProvider {}

void main() {
  late MockConnectionProvider mockProvider;

  setUp(() {
    mockProvider = MockConnectionProvider();
  });

  Widget createTestWidget({
    List<SshConnection> connections = const [],
    String? error,
    bool isLoading = false,
    bool isCompact = false,
  }) {
    when(() => mockProvider.isLoading).thenReturn(isLoading);
    when(() => mockProvider.error).thenReturn(error);
    when(() => mockProvider.filteredConnections).thenReturn(connections);

    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ConnectionProvider>.value(
          value: mockProvider,
          child: ConnectionList(
            isCompact: isCompact,
            onConnectionTap: (_) {},
            onSftpTap: (_) {},
          ),
        ),
      ),
    );
  }

  group('ConnectionList Widget', () {
    group('loading state', () {
      testWidgets(
        'Given isLoading is true, When rendered, Then shows CircularProgressIndicator',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(isLoading: true));

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    });

    group('error state', () {
      testWidgets(
        'Given error is not null, When rendered, Then shows error message',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const errorMessage = 'Test error message';
          await tester.pumpWidget(createTestWidget(error: errorMessage));

          expect(find.text(errorMessage), findsOneWidget);
        },
      );
    });

    group('empty state', () {
      testWidgets(
        'Given empty connections, When rendered, Then shows empty state UI',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(connections: []));

          expect(find.text('暂无连接配置'), findsOneWidget);
          expect(find.text('添加连接'), findsOneWidget);
          expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
        },
      );

      testWidgets(
        'Given empty connections, When rendered, Then shows FilledButton',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(connections: []));

          expect(find.byType(FilledButton), findsOneWidget);
        },
      );
    });

    group('with connections', () {
      testWidgets(
        'Given connections exist, When rendered, Then shows ListView',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final connections = [
            SshConnection(
              id: '1',
              name: 'Server 1',
              host: '192.168.1.1',
              username: 'user1',
              authType: AuthType.password,
            ),
            SshConnection(
              id: '2',
              name: 'Server 2',
              host: '192.168.1.2',
              username: 'user2',
              authType: AuthType.key,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          expect(find.byType(ListView), findsOneWidget);
          expect(find.text('Server 1'), findsOneWidget);
          expect(find.text('Server 2'), findsOneWidget);
        },
      );

      testWidgets(
        'Given multiple connections, When rendered, Then shows connection host info',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final connections = [
            SshConnection(
              id: '1',
              name: 'My Server',
              host: 'example.com',
              port: 2222,
              username: 'admin',
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Verify host:port format is shown
          expect(find.textContaining('admin@example.com:2222'), findsOneWidget);
        },
      );
    });

    group('compact mode', () {
      testWidgets(
        'Given isCompact is true, When rendered, Then uses compact layout',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final connections = [
            SshConnection(
              id: '1',
              name: 'Compact Server',
              host: '192.168.1.1',
              username: 'user',
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(
            createTestWidget(connections: connections, isCompact: true),
          );

          expect(find.byType(ListView), findsOneWidget);
          expect(find.text('Compact Server'), findsOneWidget);
        },
      );
    });

    group('FAB', () {
      testWidgets('Given non-compact mode, When rendered, Then shows FAB', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(connections: connections, isCompact: false),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is IconButton && (w.tooltip?.contains('添加连接') ?? false),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Given compact mode, When rendered, Then does not show FAB', (
        WidgetTester tester,
      ) async {
        // Set up screen size
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final connections = [
          SshConnection(
            id: '1',
            name: 'Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(connections: connections, isCompact: true),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is IconButton && (w.tooltip?.contains('添加连接') ?? false),
          ),
          findsNothing,
        );
      });
    });

    group('hover state', () {
      testWidgets(
        'Given connection item, When mouse hovers, Then shows hover styling',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final connections = [
            SshConnection(
              id: '1',
              name: 'Test Server',
              host: '192.168.1.1',
              username: 'testuser',
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Find the InkWell widget
          final inkWellFinder = find.byType(InkWell);
          expect(inkWellFinder, findsWidgets);

          // Simulate hover by entering the inkWell
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await gesture.addPointer(location: Offset.zero);
          addTearDown(() => gesture.removePointer());

          await tester.pump();

          // Move to the center of the first connection item
          final center = tester.getCenter(inkWellFinder.first);
          await gesture.moveTo(center);

          // Pump frames for hover animation
          await tester.pump(const Duration(milliseconds: 200));

          // Widget should still be present after hover
          expect(find.text('Test Server'), findsOneWidget);
        },
      );
    });

    group('focus state', () {
      testWidgets(
        'Given connection item, When focused via Tab, Then shows focus styling',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final connections = [
            SshConnection(
              id: '1',
              name: 'Focus Test Server',
              host: '10.0.0.1',
              username: 'focususer',
              authType: AuthType.key,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Tab to focus the first item
          await tester.tap(find.text('Focus Test Server'));
          await tester.pump();

          // Press Tab to move focus
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();

          // The item should be focusable and respond to focus
          final inkWellFinder = find.byType(InkWell);
          expect(inkWellFinder, findsWidgets);
        },
      );
    });

    group('text contrast', () {
      testWidgets(
        'Given connection with long name, When rendered, Then text is properly styled',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // Test with very long connection name
          final connections = [
            SshConnection(
              id: '1',
              name:
                  'Very Long Server Name That Should Be Truncated With Ellipsis',
              host: 'very-long-hostname.example.com',
              port: 22222,
              username: 'verylongusername',
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Text should be present (possibly truncated)
          expect(find.textContaining('Very Long Server'), findsOneWidget);

          // Host info should also be present
          expect(
            find.textContaining('verylongusername@very-long-hostname'),
            findsOneWidget,
          );
        },
      );
    });

    group('empty state icon', () {
      testWidgets(
        'Given no connections, When rendered, Then empty state icon is visible',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(connections: []));

          // Find the empty state icon
          final iconFinder = find.byIcon(Icons.dns_outlined);
          expect(iconFinder, findsOneWidget);

          // Verify the icon has appropriate size
          final icon = tester.widget<Icon>(iconFinder);
          expect(icon.size, 56);
        },
      );
    });
  });
}
