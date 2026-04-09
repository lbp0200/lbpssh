import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/color_utils.dart';

void main() {
  group('Terminal Performance Benchmarks', () {
    test('color parsing benchmark - uncached', () {
      final colors = [
        '#FF5733', '#00FF00', '#0000FF', '#FFFF00',
        '#FF00FF', '#00FFFF', '#FFFFFF', '#000000',
      ];

      final stopwatch = Stopwatch()..start();

      // Simulate 1000 frame renders, each parsing 8 colors
      for (int frame = 0; frame < 1000; frame++) {
        for (final color in colors) {
          ColorUtils.parseColor(color);
        }
      }

      stopwatch.stop();

      // Should complete in reasonable time
      print('Uncached: ${stopwatch.elapsedMilliseconds}ms for 8000 color parses');
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('color parsing benchmark - cached', () {
      // Pre-cache colors
      final colors = [
        '#FF5733', '#00FF00', '#0000FF', '#FFFF00',
        '#FF00FF', '#00FFFF', '#FFFFFF', '#000000',
      ];
      for (final color in colors) {
        ColorUtils.parseColorCached(color);
      }

      final stopwatch = Stopwatch()..start();

      // Simulate 1000 frame renders, each using 8 cached colors
      for (int frame = 0; frame < 1000; frame++) {
        for (final color in colors) {
          ColorUtils.parseColorCached(color);
        }
      }

      stopwatch.stop();

      // Cached should be much faster
      print('Cached: ${stopwatch.elapsedMilliseconds}ms for 8000 color lookups');
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('widget build benchmark', () {
      final stopwatch = Stopwatch()..start();

      // Simulate building terminal widgets
      for (int i = 0; i < 100; i++) {
        // Simulate widget construction overhead
        final container = SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(color: Colors.black),
              ),
            ],
          ),
        );
        // Force compilation
        expect(container, isNotNull);
      }

      stopwatch.stop();

      print('Widget build: ${stopwatch.elapsedMilliseconds}ms for 100 iterations');
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
