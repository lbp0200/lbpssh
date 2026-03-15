# Error Tracking 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development to implement this plan.

**Goal:** 为 lbpSSH 添加 Sentry 错误追踪

**Architecture:** 使用 Sentry SDK 捕获异常，通过 SentryService 统一管理

**Tech Stack:** Sentry SDK, Flutter

---

## Chunk 1: Sentry 依赖和服务

### 任务 1.1: 添加 Sentry 依赖

- [ ] **Step 1: 添加 Sentry 依赖到 pubspec.yaml**

```yaml
dependencies:
  sentry: ^8.0.0
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml
git commit -m "chore(deps): add sentry for error tracking"
```

---

### 任务 1.2: 创建 SentryService

- [ ] **Step 1: 创建 lib/utils/sentry_service.dart**

```dart
import 'package:sentry/sentry.dart';

class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _isInitialized = false;

  Future<void> init({required String dsn}) async {
    if (_isInitialized || dsn.isEmpty) return;
    await Sentry.init((options) {
      options.dsn = dsn;
      options.environment = 'production';
    });
    _isInitialized = true;
  }

  Future<void> captureException(Object e, {StackTrace? stackTrace}) async {
    if (!_isInitialized) return;
    await Sentry.captureException(e, stackTrace: stackTrace);
  }
}
```

- [ ] **Step 2: 更新 lib/main.dart 初始化 Sentry**

```dart
import 'utils/sentry_service.dart';

void main() async {
  await SentryService().init(
    dsn: const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
  );
  // ...
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/utils/sentry_service.dart lib/main.dart
git commit -m "feat(monitoring): add SentryService for error tracking"
```

---

### 任务 1.3: 添加全局错误处理器

- [ ] **Step 1: 在 main.dart 添加错误处理器**

```dart
FlutterError.onError = (details) {
  SentryService().captureException(details.exception, stackTrace: details.stack);
};

PlatformDispatcher.instance.onError = (error, stack) {
  SentryService().captureException(error, stackTrace: stack);
  return true;
};
```

- [ ] **Step 2: 提交**

```bash
git add lib/main.dart
git commit -m "feat(monitoring): add global error handler"
```

---

## 总结

| 任务 | 描述 |
|------|------|
| 1.1 | 添加 Sentry 依赖 |
| 1.2 | 创建 SentryService |
| 1.3 | 添加全局错误处理器 |

共 3 个提交
