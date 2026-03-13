import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations Tests', () {
    test('should load Chinese localization', () {
      final localizations = AppLocalizations(Locale('zh'));
      expect(localizations.connect, '连接');
    });

    test('should load English localization', () {
      final localizations = AppLocalizations(Locale('en'));
      expect(localizations.connect, 'Connect');
    });

    test('should support Chinese locale', () {
      expect(AppLocalizations.delegate.isSupported(Locale('zh')), isTrue);
    });

    test('should support English locale', () {
      expect(AppLocalizations.delegate.isSupported(Locale('en')), isTrue);
    });
  });
}
