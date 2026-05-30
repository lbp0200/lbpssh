import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/linear_styled_text_field.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';

Widget wrapWithApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('LinearStyledTextField', () {
    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '测试标签',
          ),
        ),
      );

      expect(find.text('测试标签'), findsOneWidget);
    });

    testWidgets('shows hint text when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '名称',
            hintText: '请输入名称',
          ),
        ),
      );

      expect(find.text('请输入名称'), findsOneWidget);
    });

    testWidgets('displays controller text', (tester) async {
      final controller = TextEditingController(text: 'Hello World');
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(controller: controller, labelText: '名称'),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('validates input with validator', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithApp(
          Form(
            key: formKey,
            child: LinearStyledTextField(
              controller: TextEditingController(),
              labelText: '名称',
              validator: (value) {
                if (value == null || value.isEmpty) return '必填';
                return null;
              },
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('必填'), findsOneWidget);
    });

    testWidgets('obscures text when obscureText is true', (tester) async {
      final controller = TextEditingController(text: 'secret123');
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: controller,
            labelText: '密码',
            obscureText: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('shows suffix icon when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '名称',
            suffixIcon: const Icon(Icons.check, color: Colors.green),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '名称',
            prefixIcon: const Icon(Icons.edit),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('sets readOnly when readOnly is true', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(text: 'readonly'),
            labelText: '名称',
            readOnly: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, isTrue);
    });

    testWidgets('renders with custom maxLines', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '备注',
            maxLines: 3,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 3);
    });

    testWidgets('renders with autofocus', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '名称',
            autofocus: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('uses Linear-style InputDecoration', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          LinearStyledTextField(
            controller: TextEditingController(),
            labelText: '名称',
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;

      expect(decoration!.filled, isTrue);
      expect(decoration.fillColor, LinearColors.fillSurface);

      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(LinearRadius.standard));
    });
  });

  group('HostPortRow', () {
    testWidgets('renders host and port fields', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          HostPortRow(
            hostController: TextEditingController(),
            portController: TextEditingController(),
            hostLabel: '主机地址',
          ),
        ),
      );

      expect(find.text('主机地址'), findsOneWidget);
      expect(find.text('端口'), findsOneWidget);
    });

    testWidgets('shows host hint when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          HostPortRow(
            hostController: TextEditingController(),
            portController: TextEditingController(),
            hostLabel: '主机地址',
            hostHint: '例如：192.168.1.1',
          ),
        ),
      );

      expect(find.text('例如：192.168.1.1'), findsOneWidget);
    });

    testWidgets('shows port hint when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          HostPortRow(
            hostController: TextEditingController(),
            portController: TextEditingController(),
            hostLabel: '主机地址',
            portHint: '默认 1080',
          ),
        ),
      );

      expect(find.text('默认 1080'), findsOneWidget);
    });

    testWidgets('validates host with hostValidator', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithApp(
          Form(
            key: formKey,
            child: HostPortRow(
              hostController: TextEditingController(),
              portController: TextEditingController(text: '22'),
              hostLabel: '主机地址',
              hostValidator: (value) {
                if (value == null || value.isEmpty) return '请输入主机地址';
                return null;
              },
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('请输入主机地址'), findsOneWidget);
    });

    testWidgets('validates port with default port validator', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithApp(
          Form(
            key: formKey,
            child: HostPortRow(
              hostController: TextEditingController(text: 'host'),
              portController: TextEditingController(),
              hostLabel: '主机地址',
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('请输入端口'), findsOneWidget);
    });

    testWidgets('accepts valid port', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithApp(
          Form(
            key: formKey,
            child: HostPortRow(
              hostController: TextEditingController(text: 'host'),
              portController: TextEditingController(text: '2222'),
              hostLabel: '主机地址',
            ),
          ),
        ),
      );

      final valid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(valid, isTrue);
    });

    testWidgets('uses custom port label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          HostPortRow(
            hostController: TextEditingController(),
            portController: TextEditingController(),
            hostLabel: '主机地址',
            portLabel: '跳板机端口',
          ),
        ),
      );

      expect(find.text('跳板机端口'), findsOneWidget);
    });

    testWidgets('uses custom port validator', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithApp(
          Form(
            key: formKey,
            child: HostPortRow(
              hostController: TextEditingController(text: 'host'),
              portController: TextEditingController(),
              hostLabel: '主机地址',
              portValidator: (value) => '自定义错误',
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('自定义错误'), findsOneWidget);
    });
  });
}
