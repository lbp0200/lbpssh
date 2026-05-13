import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';

void main() {
  group('LinearColors', () {
    test('has expected color values', () {
      expect(LinearColors.background.toARGB32(), 0xFF08090a);
      expect(LinearColors.textPrimary.toARGB32(), 0xFFf7f8f8);
      expect(LinearColors.accent.toARGB32(), 0xFF5e6ad2);
      expect(LinearColors.success.toARGB32(), 0xFF27a644);
      expect(LinearColors.error.toARGB32(), 0xFFf85149);
    });

    test('has all colors defined', () {
      expect(LinearColors.background, isNotNull);
      expect(LinearColors.panel, isNotNull);
      expect(LinearColors.surface, isNotNull);
      expect(LinearColors.surfaceElevated, isNotNull);
      expect(LinearColors.textPrimary, isNotNull);
      expect(LinearColors.textSecondary, isNotNull);
      expect(LinearColors.textTertiary, isNotNull);
      expect(LinearColors.textQuaternary, isNotNull);
      expect(LinearColors.accent, isNotNull);
      expect(LinearColors.accentInteractive, isNotNull);
      expect(LinearColors.accentHover, isNotNull);
      expect(LinearColors.fillSurface, isNotNull);
      expect(LinearColors.fillSurfaceHover, isNotNull);
      expect(LinearColors.borderSubtle, isNotNull);
      expect(LinearColors.borderStandard, isNotNull);
      expect(LinearColors.borderSolid, isNotNull);
      expect(LinearColors.success, isNotNull);
      expect(LinearColors.error, isNotNull);
      expect(LinearColors.warning, isNotNull);
    });
  });

  group('LinearSpacing', () {
    test('has expected spacing values', () {
      expect(LinearSpacing.spacing1, 1.0);
      expect(LinearSpacing.spacing4, 4.0);
      expect(LinearSpacing.spacing16, 16.0);
      expect(LinearSpacing.spacing32, 32.0);
    });

    test('spacing values are positive', () {
      expect(LinearSpacing.spacing1, greaterThan(0));
      expect(LinearSpacing.spacing4, greaterThan(0));
      expect(LinearSpacing.spacing7, greaterThan(0));
      expect(LinearSpacing.spacing8, greaterThan(0));
      expect(LinearSpacing.spacing11, greaterThan(0));
      expect(LinearSpacing.spacing12, greaterThan(0));
      expect(LinearSpacing.spacing16, greaterThan(0));
      expect(LinearSpacing.spacing19, greaterThan(0));
      expect(LinearSpacing.spacing20, greaterThan(0));
      expect(LinearSpacing.spacing22, greaterThan(0));
      expect(LinearSpacing.spacing24, greaterThan(0));
      expect(LinearSpacing.spacing28, greaterThan(0));
      expect(LinearSpacing.spacing32, greaterThan(0));
      expect(LinearSpacing.spacing35, greaterThan(0));
    });
  });

  group('LinearRadius', () {
    test('has expected radius values', () {
      expect(LinearRadius.micro, 2.0);
      expect(LinearRadius.small, 4.0);
      expect(LinearRadius.standard, 6.0);
      expect(LinearRadius.card, 8.0);
      expect(LinearRadius.panel, 12.0);
      expect(LinearRadius.large, 22.0);
      expect(LinearRadius.pill, 9999.0);
    });
  });

  group('LinearDuration', () {
    test('has expected duration values', () {
      expect(LinearDuration.fast, const Duration(milliseconds: 150));
      expect(LinearDuration.normal, const Duration(milliseconds: 200));
      expect(LinearDuration.slow, const Duration(milliseconds: 300));
    });
  });

  group('AppTheme', () {
    test('provides dark theme', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
    });

    test('provides light theme', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
    });
  });
}
