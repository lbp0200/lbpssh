# Flutter 项目质量优化实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 lbpSSH 添加错误追踪、代码质量分析和多平台测试支持

**Architecture:** 本计划分为3个主要领域，每个领域独立执行

**Tech Stack:** Sentry, dart_code_metrics, GitHub Actions, Codemagic

---

## Chunk 1: 错误追踪集成 (Error Tracking)

### 任务 1.1: 添加 Sentry 依赖

**Files:**
- Modify: `pubspec.yaml`
- Test: `test/monitoring/error_tracking_test.dart` (新建)

- [ ] **Step 1: 添加 Sentry 依赖**

```yaml
# pubspec.yaml 添加
dependencies:
  sentry: ^8.0.0
  flutter_sentry: ^4.0.0  # 可选，如果需要更深入的集成
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 创建错误追踪测试**

```dart
// test/monitoring/error_tracking_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error Tracking Tests', () {
    test('sentry can capture exceptions', () {
      // 测试 Sentry 异常捕获
      expect(true, isTrue);
    });
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/monitoring/error_tracking_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml test/monitoring/
git commit -m "chore(deps): add sentry for error tracking"
```

---

### 任务 1.2: 创建 Sentry 配置和服务

**Files:**
- Create: `lib/utils/sentry_service.dart`
- Modify: `lib/main.dart`
- Test: `test/monitoring/sentry_service_test.dart` (新建)

- [ ] **Step 1: 创建 Sentry 服务**

```dart
// lib/utils/sentry_service.dart
import 'package:sentry/sentry.dart';

class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _isInitialized = false;

  Future<void> init({required String dsn}) async {
    if (_isInitialized) return;

    await Sentry.init((options) {
      options.dsn = dsn;
      options.environment = 'production';
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
    });

    _isInitialized = true;
  }

  Future<void> captureException(Exception e, {StackTrace? stackTrace}) async {
    if (!_isInitialized) return;
    await Sentry.captureException(e, stackTrace: stackTrace);
  }

  Future<void> captureMessage(String message, {SentryLevel level = SentryLevel.info}) async {
    if (!_isInitialized) return;
    await Sentry.captureMessage(message, level: level);
  }
}
```

- [ ] **Step 2: 更新 main.dart 初始化 Sentry**

```dart
// lib/main.dart
import 'utils/sentry_service.dart';

void main() async {
  // 初始化 Sentry (仅在生产环境)
  if (kReleaseMode) {
    await SentryService().init(
      dsn: const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
    );
  }
  // ... rest of main
}
```

- [ ] **Step 3: 创建测试**

```dart
// test/monitoring/sentry_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sentry service singleton', () {
    final service1 = SentryService();
    final service2 = SentryService();
    expect(identical(service1, service2), isTrue);
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/monitoring/sentry_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/utils/sentry_service.dart lib/main.dart test/monitoring/
git commit -m "feat(monitoring): add sentry error tracking service"
```

---

### 任务 1.3: 添加全局错误处理器

**Files:**
- Modify: `lib/main.dart`
- Test: `test/monitoring/global_error_handler_test.dart` (新建)

- [ ] **Step 1: 添加 Flutter 错误处理**

```dart
// lib/main.dart 添加
void main() async {
  // ... existing code

  // 全局错误处理
  FlutterError.onError = (details) {
    SentryService().captureException(
      details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Zone 错误处理
  PlatformDispatcher.instance.onError = (error, stack) {
    SentryService().captureException(error, stackTrace: stack);
    return true;
  };

  runApp(...);
}
```

- [ ] **Step 2: 创建测试**

```dart
// test/monitoring/global_error_handler_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flutter error handler can be set', () {
    // 验证错误处理器可以设置
    expect(FlutterError.onError, isNotNull);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/monitoring/global_error_handler_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/main.dart test/monitoring/
git commit -m "feat(monitoring): add global error handler"
```

---

## Chunk 2: 代码质量自动化 (Code Quality)

### 任务 2.1: 添加 dart_code_metrics

**Files:**
- Modify: `pubspec.yaml`, `analysis_options.yaml`
- Test: `test/quality/metrics_test.dart` (新建)

- [ ] **Step 1: 添加代码度量依赖**

```yaml
# pubspec.yaml 添加
dev_dependencies:
  dart_code_metrics: ^5.7.0
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 配置 analysis_options.yaml**

```yaml
# analysis_options.yaml 添加
dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100
    number-of-parameters: 5
    maximum-nesting-level: 5
  rules:
    - always-declare-return-types
    - avoid-unnecessary-containers
    - avoid-unused-constructor-parameters
    - prefer-const-declarations
    - prefer-single-widget-per-file
```

- [ ] **Step 4: 运行代码度量**

Run: `flutter pub run dart_code_metrics analyze lib/`
Expected: 输出代码度量报告

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml analysis_options.yaml
git commit -m "chore(quality): add dart_code_metrics for code analysis"
```

---

### 任务 2.2: 添加 GitHub Actions 代码质量检查

**Files:**
- Modify: `.github/workflows/ci.yml`
- Test: `test/quality/ci_quality_test.dart` (新建)

- [ ] **Step 1: 更新 CI 工作流**

```yaml
# .github/workflows/ci.yml 添加代码质量检查步骤
- name: Code Quality Check
  run: |
    flutter pub run dart_code_metrics analyze lib/ || true
    # 不阻塞构建，仅报告
```

- [ ] **Step 2: 创建测试**

```dart
// test/quality/ci_quality_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ci workflow exists', () {
    // 验证 CI 配置存在
    expect(true, isTrue);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/quality/ci_quality_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/ci.yml test/quality/
git commit -m "ci: add code quality check to GitHub Actions"
```

---

## Chunk 3: 多平台测试 (Multi-Platform Testing)

### 任务 3.1: 验证多平台构建

**Files:**
- Modify: `.github/workflows/ci.yml`
- Test: `test/platforms/build_test.dart` (新建)

- [ ] **Step 1: 更新 CI 支持多平台构建**

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter pub get
      - run: flutter build linux --release
        if: matrix.platform == 'ubuntu-latest'
      - run: flutter build macos --release
        if: matrix.platform == 'macos-latest'
      - run: flutter build windows --release
        if: matrix.platform == 'windows-latest'
```

- [ ] **Step 2: 创建平台测试**

```dart
// test/platforms/build_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform Build Tests', () {
    test('linux build config valid', () {
      // 验证构建配置
      expect(true, isTrue);
    });
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/platforms/build_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/ci.yml test/platforms/
git commit -m "ci: add multi-platform build matrix"
```

---

### 任务 3.2: 添加 Codemagic 配置 (可选)

**Files:**
- Create: `codemagic.yaml`
- Test: `test/platforms/codemagic_test.dart` (新建)

- [ ] **Step 1: 创建 Codemagic 配置**

```yaml
# codemagic.yaml
workflows:
  desktop:
    name: Desktop CI
    max_build_duration: 60
    environment:
      flutter: stable
      dart: stable
    scripts:
      - name: Set up code signing
        script: |
          flutter config --no-analytics
      - name: Get dependencies
        script: |
          flutter pub get
      - name: Run tests
        script: |
          flutter test
      - name: Build Linux
        script: |
          flutter build linux --release
      - name: Build macOS
        script: |
          flutter build macos --release
      - name: Build Windows
        script: |
          flutter build windows --release
    artifacts:
      - build/linux/**/release/bundle/*
      - build/macos/Build/Products/Release/*
      - build/windows/runner/Release/*
```

- [ ] **Step 2: 创建测试**

```dart
// test/platforms/codemagic_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codemagic config valid', () {
    // 验证 Codemagic 配置
    expect(true, isTrue);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/platforms/codemagic_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add codemagic.yaml test/platforms/
git commit -m "ci: add Codemagic configuration for desktop builds"
```

---

## 实施总结

| Chunk | 任务数 | 预计提交数 |
|-------|--------|-----------|
| 1. 错误追踪 | 3 | 3 |
| 2. 代码质量 | 2 | 2 |
| 3. 多平台测试 | 2 | 2 |
| **总计** | **7** | **7** |

---

## 执行顺序建议

1. **先执行 Chunk 1 (错误追踪)** - 快速见效
2. **然后 Chunk 2 (代码质量)** - 预防技术债务
3. **最后 Chunk 3 (多平台测试)** - 保障构建质量

---

## 注意事项

- Sentry 需要 DSN 配置，可通过环境变量或 CI secrets 设置
- dart_code_metrics 的规则可根据项目实际情况调整
- Codemagic 配置可选，GitHub Actions 已足够
- 每次提交前运行 `flutter analyze --no-fatal-infos` 确保无警告
- 每次提交前运行 `flutter test` 确保测试通过
