import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/shimmer_loading.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  group('ShimmerLoading', () {
    testWidgets('renders child directly when not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: false,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('wraps child in Shimmer when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('defaults to isLoading true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ShimmerLoading(
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('toggles between shimmer and child on isLoading change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: false,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsNothing);
      expect(find.text('Content'), findsOneWidget);
    });
  });
}
