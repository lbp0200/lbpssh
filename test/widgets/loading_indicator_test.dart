import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/loading_indicator.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';

void main() {
  const defaultSize = 24.0;

  group('LoadingIndicator', () {
    testWidgets('renders with default size and color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: LoadingIndicator()),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, defaultSize);
      expect(sizedBox.height, defaultSize);
    });

    testWidgets('renders with custom size', (tester) async {
      const size = 48.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: LoadingIndicator(size: size)),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, size);
      expect(sizedBox.height, size);
    });

    testWidgets('applies custom color when provided', (tester) async {
      const customColor = Colors.red;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: LoadingIndicator(color: customColor)),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final valueColor =
          progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
      expect(valueColor.value, customColor);
    });

    testWidgets('uses default accent color when no color provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: LoadingIndicator()),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final valueColor =
          progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
      expect(valueColor.value, LinearColors.accentInteractive);
    });

    testWidgets('renders with strokeWidth 2', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: LoadingIndicator()),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.strokeWidth, 2);
    });
  });
}
