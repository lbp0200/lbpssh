import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/presentation/widgets/error_detail_dialog.dart';

/// Helper: create an SshConnection with sensible defaults for testing.
SshConnection _createConnection({
  String id = 'test-conn',
  String name = '测试服务器',
  String host = '192.168.1.100',
  int port = 22,
  String username = 'admin',
  AuthType authType = AuthType.password,
  JumpHostConfig? jumpHost,
  Socks5ProxyConfig? socks5Proxy,
}) {
  return SshConnection(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    authType: authType,
    jumpHost: jumpHost,
    socks5Proxy: socks5Proxy,
  );
}

/// Helper: wrap ErrorDetailDialog in a MaterialApp + button that opens it.
Future<void> pumpDialog(
  WidgetTester tester, {
  required SshConnection connection,
  required String errorMessage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<Widget>(
              context: context,
              builder: (_) => ErrorDetailDialog(
                connection: connection,
                errorMessage: errorMessage,
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
}

void main() {
  setUpAll(() {
    // Mock platform channels to avoid MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      return null;
    });
  });

  group('ErrorDetailDialog', () {
    group('dialog structure', () {
      testWidgets(
        'Given basic connection error, When dialog opens, Then shows title and error message',
        (WidgetTester tester) async {
          final conn = _createConnection();
          const errorMsg = 'Connection refused: connection timed out';

          await pumpDialog(tester, connection: conn, errorMessage: errorMsg);

          // Title
          expect(find.text('连接失败'), findsOneWidget);

          // Connection info
          expect(find.textContaining('测试服务器'), findsOneWidget);
          expect(find.textContaining('192.168.1.100:22'), findsOneWidget);
          expect(find.textContaining('admin'), findsOneWidget);
          expect(find.textContaining('密码认证'), findsOneWidget);

          // Error message
          expect(find.textContaining(errorMsg), findsOneWidget);

          // Buttons
          expect(find.text('复制错误'), findsOneWidget);
          expect(find.text('反馈问题'), findsOneWidget);
          expect(find.text('关闭'), findsOneWidget);
        },
      );

      testWidgets(
        'Given connection with jump host, When dialog opens, Then shows jump host info',
        (WidgetTester tester) async {
          final conn = _createConnection(
            jumpHost: JumpHostConfig(
              host: '10.0.0.1',
              port: 2222,
              username: 'jump-user',
              authType: AuthType.password,
            ),
          );

          await pumpDialog(tester, connection: conn, errorMessage: 'test');

          expect(find.textContaining('10.0.0.1:2222'), findsOneWidget);
          expect(find.textContaining('跳板机'), findsOneWidget);
        },
      );

      testWidgets(
        'Given connection with SOCKS5 proxy, When dialog opens, Then shows proxy info',
        (WidgetTester tester) async {
          final conn = _createConnection(
            socks5Proxy: Socks5ProxyConfig(host: 'proxy.local', port: 1080),
          );

          await pumpDialog(tester, connection: conn, errorMessage: 'test');

          expect(find.textContaining('proxy.local:1080'), findsOneWidget);
          expect(find.textContaining('SOCKS5 代理'), findsOneWidget);
        },
      );

      testWidgets(
        'Given connection without jump host, When dialog opens, Then no jump host section',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(tester, connection: conn, errorMessage: 'test');

          expect(find.textContaining('跳板机'), findsNothing);
        },
      );
    });

    group('solution hints', () {
      testWidgets(
        'Given PTY error, When dialog opens, Then shows PTY-specific hint',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(
            tester,
            connection: conn,
            errorMessage: 'Failed to start PTY: no tty allocated',
          );

          expect(find.textContaining('可能原因与解决方法'), findsOneWidget);
          expect(find.textContaining('PermitTTY'), findsOneWidget);
        },
      );

      testWidgets(
        'Given authentication error, When dialog opens, Then shows auth hint',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(
            tester,
            connection: conn,
            errorMessage: 'Authentication failed: permission denied',
          );

          expect(find.textContaining('排查建议'), findsAtLeast(1));
          expect(find.textContaining('密码/密钥验证失败'), findsOneWidget);
        },
      );

      testWidgets(
        'Given connection refused error, When dialog opens, Then shows network hint',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(
            tester,
            connection: conn,
            errorMessage: 'Connection refused',
          );

          expect(find.textContaining('排查建议'), findsAtLeast(1));
          expect(find.textContaining('SSH 服务未运行'), findsOneWidget);
        },
      );

      testWidgets(
        'Given host key error, When dialog opens, Then shows key hint',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(
            tester,
            connection: conn,
            errorMessage: 'Host key verification failed',
          );

          expect(find.textContaining('排查建议'), findsAtLeast(1));
          expect(find.textContaining('主机密钥验证失败'), findsOneWidget);
        },
      );

      testWidgets(
        'Given unknown error, When dialog opens, Then shows generic hint',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(
            tester,
            connection: conn,
            errorMessage: 'Something completely unexpected happened',
          );

          expect(find.textContaining('排查建议'), findsAtLeast(1));
          expect(find.textContaining('主机地址、端口、用户名'), findsOneWidget);
        },
      );
    });

    group('actions', () {
      testWidgets(
        'Given close button, When tapped, Then dismisses dialog',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(tester, connection: conn, errorMessage: 'test');

          expect(find.text('连接失败'), findsOneWidget);

          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();

          expect(find.text('连接失败'), findsNothing);
        },
      );

      testWidgets(
        'Given copy error button, When tapped, Then copies to clipboard',
        (WidgetTester tester) async {
          const errorMsg = 'Copy this error message';
          final conn = _createConnection();

          await pumpDialog(tester, connection: conn, errorMessage: errorMsg);

          await tester.tap(find.text('复制错误'));
          await tester.pump();

          // Wait for the SnackBar to appear
          await tester.pump(const Duration(seconds: 1));

          expect(
            find.text('错误信息已复制到剪贴板'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Given feedback button, When tapped, Then does not throw',
        (WidgetTester tester) async {
          final conn = _createConnection();

          await pumpDialog(tester, connection: conn, errorMessage: 'test');

          // Tap the "反馈问题" button — url_launcher will fail gracefully
          // in test, and the state should still update to show checkmark
          await tester.tap(find.text('反馈问题'));
          await tester.pump();

          // Button text changes to "已复制，前往 Issues" after tap
          expect(find.text('已复制，前往 Issues'), findsOneWidget);
        },
      );
    });
  });
}
