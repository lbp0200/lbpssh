import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Golden Tests', () {
    testWidgets('ConnectionList golden test', (tester) async {
      // Skip on non-macOS due to rendering differences
      // Golden files generated on macOS, minor pixel differences on other OS
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Connections')),
            body: ListView(
              children: const [
                ListTile(title: Text('Server 1')),
                ListTile(title: Text('Server 2')),
                ListTile(title: Text('Server 3')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/connection_list.png'),
      );
    }, skip: !Platform.isMacOS);

    testWidgets('Empty terminal view golden test', (tester) async {
      // Skip on non-macOS due to rendering differences
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.terminal,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击左侧连接以打开终端',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/empty_terminal.png'),
      );
    }, skip: !Platform.isMacOS);
  });
}
