# AGENTS.md - Development Guidelines for lbpSSH

This document provides guidelines and commands for agentic coding agents working in the lbpSSH Flutter project.

## Build, Lint, and Test Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Code generation (required after modifying model classes)
dart run build_runner build --delete-conflicting-outputs

# Clean build artifacts
flutter clean

# Analyze code
flutter analyze --no-fatal-infos

# Format code
dart format .

# Run all tests
flutter test

# Run single test file
flutter test test/models/ssh_connection_test.dart

# Run specific test with pattern
flutter test --name="SshConnection"

# Build for different platforms
flutter build macos --debug --no-tree-shake-icons
flutter build linux --debug
flutter build windows --debug

# Run application
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

### Development Workflow
1. Make code changes
2. Run `flutter analyze` to check for issues
3. Run relevant tests: `flutter test test/path/to/specific_test.dart`
4. Run code generation if needed
5. Build and test

## Project Structure
```
lib/
├── main.dart              # App entry point, DI setup via ProviderScope
├── core/                  # Constants, theme configuration
├── data/                  # Models (JSON-serializable), repositories
├── domain/                # Services, use cases
├── presentation/          # Screens, widgets, Riverpod providers
└── utils/                 # Utilities (encryption, etc.)
test/                      # Test files
```

## Code Style Guidelines

### Import Organization
1. Dart/Flutter imports (alphabetical)
2. Third-party package imports (alphabetical)
3. Project imports with relative paths (alphabetical)

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/models/ssh_connection.dart';
import '../providers/connection_provider.dart';
```

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Methods: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Private members: Leading underscore (`_privateMethod`)

### Type Guidelines
- Always specify return types for methods
- Use `final` by default, `var` only when necessary
- Prefer concrete types over `dynamic`
- Use `required` for required named parameters

### Model Pattern
Models use `@JsonSerializable()` with `part '*.g.dart'` and include:
- `copyWith()` method
- `fromJson()` and `toJson()` factories

### Widget Guidelines
- Use `const` constructors when possible
- Extract widgets >100 lines to separate files
- Always specify `Key` parameter
- Break long widgets into smaller components

### Error Handling
- Use try-catch for async operations
- Check `mounted`/`context.mounted` in async callbacks
- Provide user-friendly error messages
- Log errors appropriately (avoid sensitive data)

## State Management
State is managed with `flutter_riverpod`:
- Wrap widget tree with `ProviderScope` in `main.dart`
- Use `ConsumerWidget` or `Consumer` to access providers
- Use `ref.watch()` for reactive access, `ref.read()` for one-shot
- Use `@riverpod` annotation with `riverpod_annotation` package

## Testing Guidelines
- Unit tests: `test/models/`, `test/utils/`, `test/repositories/`
- Widget tests: `test/widgets/`
- Naming: `*_test.dart`
- Group tests by functionality with `group()`
- Mock external dependencies

```dart
void main() {
  group('SshConnection', () {
    late SshConnection connection;
    
    setUp(() {
      connection = SshConnection(
        id: 'test-id',
        name: 'Test',
        host: 'localhost',
        username: 'test',
        authType: AuthType.password,
      );
    });
    
    test('should create with default port', () {
      expect(connection.port, equals(22));
    });
  });
}
```

## Dependencies
- **SSH**: dartssh2
- **Terminal**: kterm, flutter_pty
- **State**: flutter_riverpod
- **Routing**: go_router
- **Networking**: dio
- **Encryption**: encrypt

## Critical Rules

1. **Never commit secrets** (passwords, tokens, keys) in code
2. **Always run `flutter analyze`** before committing
3. **Test on multiple platforms** before pushing
4. **Follow Material Design** guidelines for UI
5. **Use consistent code formatting** (`dart format .`)

## Release Process
```bash
# 1. Update version in pubspec.yaml
# 2. Commit: git add pubspec.yaml && git commit -m "release: bump version to X.Y.Z"
# 3. Tag: git tag vX.Y.Z
# 4. Push: git push && git push origin vX.Y.Z
```

## Quick Reference

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Analyze | `flutter analyze` |
| Format | `dart format .` |
| Test | `flutter test` |
| Build | `flutter build macos --debug` |
| Generate | `dart run build_runner build --delete-conflicting-outputs` |

## Homebrew

- **Tap**: `lbp0200/homebrew-lbpssh-tap`
- **Install**: `brew install lbp0200/homebrew-lbpssh-tap/lbpssh`
- **CI**: GitHub Actions (`ci.yml`) 在打 tag 发版时自动更新 cask 的 version 和 sha256
- **本地 cask 目录**: `homebrew/Casks/`（用于开发测试）|
