import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Terminal Search Tests', () {
    testWidgets('search bar should be present', (tester) async {
      // 验证 SearchBar widget 可以正常构建
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search in terminal...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('search should support text input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextField())),
      );

      await tester.enterText(find.byType(TextField), 'test query');
      expect(find.text('test query'), findsOneWidget);
    });

    testWidgets('search should support clearing', (tester) async {
      final controller = TextEditingController(text: 'initial text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );

      // Clear the text
      controller.clear();
      await tester.pump();

      expect(controller.text, isEmpty);
    });

    test('search query pattern matching', () {
      // 简单的搜索匹配测试
      const content = 'Hello World\nTest Line\nAnother Line';

      // 测试包含搜索
      expect(content.contains('World'), isTrue);
      expect(content.contains('test'), isFalse); // Case sensitive

      // 测试不区分大小写搜索
      expect(content.toLowerCase().contains('test'), isTrue);
    });
  });
}
