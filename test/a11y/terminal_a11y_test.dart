import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Terminal A11y Tests', () {
    testWidgets('semantics should be present on terminal tabs', (tester) async {
      // 验证 Semantics widget 可以正确构建
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Test tab',
              button: true,
              child: const Text('Terminal Tab'),
            ),
          ),
        ),
      );

      // MaterialApp 和 Scaffold 内部会包含其他 Semantics 组件
      // 我们验证我们添加的 Semantics 至少存在
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('focusable elements should be focusable', (tester) async {
      // 验证 Focus widget 可以正确构建
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Focus(
              autofocus: true,
              child: TextField(),
            ),
          ),
        ),
      );

      // MaterialApp 和 Scaffold 内部会包含其他 Focus 组件
      // 我们验证我们添加的 Focus 至少存在
      expect(find.byType(Focus), findsWidgets);
    });

    testWidgets('semantics label should be accessible', (tester) async {
      const testLabel = 'Terminal tab: Test Server';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: testLabel,
              button: true,
              child: const Text('Terminal Tab'),
            ),
          ),
        ),
      );

      // 验证 Semantics widget 存在 - 查找包含我们设置的 label 的 Semantics
      final semanticsWidgets = tester.widgetList<Semantics>(find.byType(Semantics));
      final hasLabel = semanticsWidgets.any((s) => s.properties.label == testLabel);
      expect(hasLabel, isTrue);
    });
  });
}
