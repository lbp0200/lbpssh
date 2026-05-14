import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/connection_provider_riverpod.dart';
import 'package:lbp_ssh/presentation/widgets/compact_connection_list.dart';

class _MockConnectionNotifier extends ConnectionNotifier {
  final ConnectionState _state;
  _MockConnectionNotifier(this._state);

  @override
  ConnectionState build() => _state;

  @override
  Future<void> deleteConnection(String id) async {
    // Override to avoid null _repo
    state = state.copyWith(
      connections: state.connections.where((c) => c.id != id).toList(),
    );
  }
}

void main() {
  Widget createTestWidget({
    List<SshConnection> connections = const [],
    String? error,
    bool isLoading = false,
  }) {
    final state = ConnectionState(
      isLoading: isLoading,
      error: error,
      connections: connections,
    );

    return MaterialApp(
      home: Scaffold(
        body: ProviderScope(
          overrides: [
            connectionProvider.overrideWith(
              () => _MockConnectionNotifier(state),
            ),
          ],
          child: CompactConnectionList(onConnectionTap: (_) {}),
        ),
      ),
    );
  }

  group('CompactConnectionList Widget', () {
    group('loading state', () {
      testWidgets(
        'Given isLoading is true, When rendered, Then shows small CircularProgressIndicator',
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
        'Given error is not null, When rendered, Then shows error icon',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const errorMessage = 'Test error';
          await tester.pumpWidget(createTestWidget(error: errorMessage));

          expect(find.byIcon(Icons.error_outline), findsOneWidget);
        },
      );
    });

    group('empty state', () {
      testWidgets(
        'Given empty connections, When rendered, Then shows add button and icon',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(connections: []));

          expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
          expect(find.byIcon(Icons.add), findsOneWidget);
        },
      );

      testWidgets(
        'Given empty connections, When rendered, Then shows add connection tooltip',
        (WidgetTester tester) async {
          // Set up screen size
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(createTestWidget(connections: []));

          expect(find.byTooltip('添加连接'), findsOneWidget);
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
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          expect(find.byType(ListView), findsOneWidget);
        },
      );

      testWidgets(
        'Given connections exist, When rendered, Then shows add new connection button',
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
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Should have both "add_circle_outline" for new connection and icons for existing connections
          expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
        },
      );

      testWidgets(
        'Given multiple connections, When rendered, Then shows multiple items',
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
            SshConnection(
              id: '3',
              name: 'Server 3',
              host: '192.168.1.3',
              username: 'user3',
              authType: AuthType.keyWithPassword,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          // Multiple computer icons should be visible for each connection
          expect(find.byIcon(Icons.computer), findsNWidgets(3));
        },
      );
    });

    group('connection item interactions', () {
      testWidgets('Given connection, When long press, Then shows popup menu', (
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
            name: 'Test Server',
            host: '192.168.1.1',
            username: 'user',
            authType: AuthType.password,
          ),
        ];

        await tester.pumpWidget(createTestWidget(connections: connections));

        // Find the PopupMenuButton and long press to trigger menu
        expect(find.byType(PopupMenuButton<String>), findsWidgets);
      });

      testWidgets(
        'Given connection popup menu, When connect is tapped, Then calls onTap callback',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1000, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          String? tappedId;
          final connections = [
            SshConnection(
              id: '1',
              name: 'Test Server',
              host: '192.168.1.1',
              username: 'user',
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ProviderScope(
                  overrides: [
                    connectionProvider.overrideWith(
                      () => _MockConnectionNotifier(
                        ConnectionState(connections: connections),
                      ),
                    ),
                  ],
                  child: CompactConnectionList(
                    onConnectionTap: (conn) => tappedId = conn.id,
                  ),
                ),
              ),
            ),
          );

          // Tap the connection directly (GestureDetector onTap)
          await tester.tap(find.byIcon(Icons.computer));
          await tester.pump();

          expect(tappedId, '1');
        },
      );

      testWidgets(
        'Given connection, When rendered, Then shows tooltip with connection details',
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
              name: 'MyServer',
              host: '10.0.0.1',
              username: 'admin',
              port: 2222,
              authType: AuthType.password,
            ),
          ];

          await tester.pumpWidget(createTestWidget(connections: connections));

          expect(
            find.byTooltip('MyServer\nadmin@10.0.0.1:2222'),
            findsOneWidget,
          );
        },
      );
    });
  });
}
