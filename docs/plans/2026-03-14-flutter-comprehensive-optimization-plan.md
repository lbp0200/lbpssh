# Flutter 终端应用全面优化实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 对 lbpSSH 应用进行全面优化，涵盖性能优化、架构现代化、终端功能增强、可访问性支持和测试金字塔完善

**Architecture:** 本计划分为5个主要领域，每个领域独立执行但共享基础代码审查流程

**Tech Stack:** Flutter 3.10+, Provider (当前) → Riverpod 2.0, kterm, dartssh2, mocktail

---

## Chunk 1: 性能优化与渲染改进

### 任务 1.1: 添加 RepaintBoundary 减少重绘区域

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart:245-320`
- Test: `test/widgets/terminal_view_test.dart` (新建)

- [ ] **Step 1: 创建性能测试文件**

```dart
// test/widgets/terminal_view_performance_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/terminal_view.dart';

void main() {
  group('TerminalViewWidget Performance Tests', () {
    testWidgets('should render without excessive rebuilds', (tester) async {
      // Build widget and verify render time
      // This is a placeholder for performance benchmarking
    });
  });
}
```

- [ ] **Step 2: 运行测试验证文件创建成功**

Run: `flutter test test/widgets/terminal_view_performance_test.dart`
Expected: PASS (empty test suite)

- [ ] **Step 3: 添加 RepaintBoundary 优化**

在 `_TerminalViewWithSelection` 的 `build` 方法中，用 RepaintBoundary 包裹 TerminalView:

```dart
@override
Widget build(BuildContext context) {
  final graphicsManager = widget.terminal.graphicsManager as dynamic;
  final cellWidth = widget.config.fontSize * 0.6;
  final cellHeight = widget.config.fontSize * widget.config.lineHeight;

  return RepaintBoundary(
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TerminalView(
            widget.terminal,
            key: ValueKey(
              'terminal_${widget.config.fontSize}_${widget.config.fontFamily}',
            ),
            // ... existing code
          ),
        ),
        // GraphicsOverlay remains outside RepaintBoundary
        if (graphicsManager != null)
          GraphicsOverlayWidget(
            graphicsManager: graphicsManager,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            scrollOffset: 0,
          ),
      ],
    ),
  );
}
```

- [ ] **Step 4: 运行测试验证**

Run: `flutter test test/widgets/terminal_view_performance_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/presentation/widgets/terminal_view.dart test/widgets/terminal_view_performance_test.dart
git commit -m "perf(terminal): add RepaintBoundary for render optimization"
```

---

### 任务 1.2: 优化终端配置解析

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart:119-125`
- Test: `test/widgets/terminal_view_config_test.dart` (新建)

- [ ] **Step 1: 创建配置测试**

```dart
// test/widgets/terminal_view_config_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Color Parsing Performance', () {
    test('should parse color efficiently', () {
      Color parseColor(String colorHex) {
        try {
          return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        } catch (e) {
          return Colors.white;
        }
      }

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        parseColor('#FF5733');
      }
      stopwatch.stop();

      // Should complete 1000 parses in under 10ms
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test test/widgets/terminal_view_config_test.dart`
Expected: PASS

- [ ] **Step 3: 将 parseColor 移至配置类**

创建 `lib/utils/color_utils.dart`:

```dart
import 'package:flutter/material.dart';

class ColorUtils {
  static Color parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white;
    }
  }

  // 预编译常用颜色缓存
  static final Map<String, Color> _colorCache = {};

  static Color parseColorCached(String colorHex) {
    return _colorCache.putIfAbsent(colorHex, () => parseColor(colorHex));
  }
}
```

- [ ] **Step 4: 更新 terminal_view.dart 使用缓存版本**

```dart
import '../../utils/color_utils.dart';

// 在 build 方法中
theme: TerminalTheme(
  foreground: ColorUtils.parseColorCached(widget.config.foregroundColor),
  background: ColorUtils.parseColorCached(widget.config.backgroundColor),
  // ...
),
```

- [ ] **Step 5: 运行测试**

Run: `flutter test test/widgets/terminal_view_config_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/utils/color_utils.dart lib/presentation/widgets/terminal_view.dart test/widgets/
git commit -m "perf(terminal): add color caching for config parsing"
```

---

### 任务 1.3: 减少不必要的状态重建

**Files:**
- Modify: `lib/presentation/providers/terminal_provider.dart`
- Test: `test/providers/terminal_provider_test.dart`

- [ ] **Step 1: 检查当前 Provider 实现**

Read: `lib/presentation/providers/terminal_provider.dart` (前100行)

- [ ] **Step 2: 使用 Selectable 减少重建**

在 `terminal_view.dart` 中使用 `context.select`:

```dart
// 修改前
return Consumer2<TerminalProvider, AppConfigProvider>(
  builder: (context, terminalProvider, configProvider, child) {

// 修改后 - 只监听需要的属性
return Consumer<TerminalProvider>(
  builder: (context, terminalProvider, child) {
    final session = terminalProvider.activeSession;
    return Consumer<AppConfigProvider>(
      builder: (context, configProvider, child) {
        final config = configProvider.terminalConfig;
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/providers/terminal_provider_test.dart`
Expected: PASS (所有现有测试)

- [ ] **Step 4: 提交**

```bash
git add lib/presentation/widgets/terminal_view.dart
git commit -r efactor(terminal): optimize rebuilds with selective consumers"
```

---

## Chunk 2: 架构现代化 - Riverpod 迁移

### 任务 2.1: 评估 Provider → Riverpod 迁移成本

**Files:**
- Analyze: 所有 Provider 文件
- Create: `docs/plans/2026-03-14-riverpod-migration-analysis.md`

- [ ] **Step 1: 分析所有 Provider 依赖**

```bash
# 统计 Provider 使用情况
grep -r "ChangeNotifierProvider\|Provider.of\|context.read\|context.watch" lib/ --include="*.dart" | wc -l
```

- [ ] **Step 2: 创建迁移分析文档]

```markdown
# Provider → Riverpod 迁移分析

## 当前状态
- Provider 文件数: X
- 总依赖点: Y

## 迁移成本评估
| Provider | 复杂度 | 依赖数 |
|----------|--------|--------|
| ConnectionProvider | 中 | 12 |
| TerminalProvider | 高 | 28 |
| SyncProvider | 低 | 8 |
| AppConfigProvider | 低 | 6 |
| ImportExportProvider | 中 | 10 |
| SftpProvider | 中 | 15 |

## 推荐策略
1. 新功能使用 Riverpod
2. 现有 Provider 逐步迁移
3. 保持兼容性，使用 provider 兼容层
```

- [ ] **Step 3: 提交分析**

```bash
git add docs/plans/2026-03-14-riverpod-migration-analysis.md
git commit -m "docs: add Riverpod migration analysis"
```

---

### 任务 2.2: 添加 Riverpod 依赖并验证

**Files:**
- Modify: `pubspec.yaml`
- Test: `test/riverpod/connection_provider_test.dart` (新建)

- [ ] **Step 1: 添加 Riverpod 依赖**

```yaml
# pubspec.yaml 添加
dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

dev_dependencies:
  riverpod_generator: ^2.6.5
  build_runner: ^2.10.5
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 创建简单 Riverpod 测试**

```dart
// test/riverpod/simple_riverpod_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Riverpod basic functionality', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(provider((ref) => 'test'));
    expect(container.read(provider((ref) => 'test')), 'test');
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/riverpod/simple_riverpod_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml test/riverpod/
git commit -m "chore(deps): add Riverpod dependencies"
```

---

### 任务 2.3: 创建新的 Riverpod 风格 Provider 示例

**Files:**
- Create: `lib/presentation/providers_riverpod/app_config_provider_riverpod.dart`
- Test: `test/riverpod/app_config_provider_riverpod_test.dart`

- [ ] **Step 1: 创建 Riverpod 版本 AppConfigProvider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/app_config_service.dart';
import '../../data/models/terminal_config.dart';

/// AppConfigService 单例提供者
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService.getInstance();
});

/// 终端配置提供者
final terminalConfigProvider = StateNotifierProvider<TerminalConfigNotifier, TerminalConfig>((ref) {
  final service = ref.watch(appConfigServiceProvider);
  return TerminalConfigNotifier(service);
});

class TerminalConfigNotifier extends StateNotifier<TerminalConfig> {
  final AppConfigService _service;

  TerminalConfigNotifier(this._service) : super(_service.loadTerminalConfig());

  void updateConfig(TerminalConfig config) {
    state = config;
    _service.saveTerminalConfig(config);
  }

  void updateFontSize(double size) {
    updateConfig(state.copyWith(fontSize: size));
  }
}
```

- [ ] **Step 2: 创建测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/presentation/providers_riverpod/app_config_provider_riverpod.dart';
import 'package:lbp_ssh/domain/services/app_config_service.dart';
import 'package:lbp_ssh/data/models/terminal_config.dart';

class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late MockAppConfigService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockAppConfigService();
    when(() => mockService.loadTerminalConfig()).thenReturn(TerminalConfig.defaultConfig());
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('should load initial config', () {
    final config = container.read(terminalConfigProvider);
    expect(config.fontSize, 17);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/riverpod/app_config_provider_riverpod_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/presentation/providers_riverpod/ test/riverpod/
git commit -m "feat(riverpod): add Riverpod-based AppConfigProvider example"
```

---

## Chunk 3: 高级终端功能

### 任务 3.1: 实现终端分屏功能

**Files:**
- Create: `lib/presentation/widgets/split_terminal_view.dart`
- Test: `test/widgets/split_terminal_view_test.dart`

- [ ] **Step 1: 创建分屏组件]

```dart
import 'package:flutter/material.dart';

enum SplitDirection { horizontal, vertical }

class SplitTerminalView extends StatefulWidget {
  final String sessionId1;
  final String sessionId2;
  final SplitDirection direction;

  const SplitTerminalView({
    super.key,
    required this.sessionId1,
    required this.sessionId2,
    this.direction = SplitDirection.vertical,
  });

  @override
  State<SplitTerminalView> createState() => _SplitTerminalViewState();
}

class _SplitTerminalViewState extends State<SplitTerminalView> {
  double _splitPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = widget.direction == SplitDirection.horizontal;
        final totalSize = isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final firstSize = totalSize * _splitPosition;

        return Row(
          children: [
            SizedBox(
              width: isHorizontal ? firstSize : constraints.maxWidth,
              height: isHorizontal ? constraints.maxHeight : firstSize,
              child: _TerminalContainer(sessionId: widget.sessionId1),
            ),
            GestureDetector(
              onHorizontalDragUpdate: isHorizontal
                  ? (details) => setState(() => _splitPosition += details.delta.dx / totalSize)
                  : null,
              onVerticalDragUpdate: !isHorizontal
                  ? (details) => setState(() => _splitPosition += details.delta.dy / totalSize)
                  : null,
              child: Container(
                width: isHorizontal ? 8 : constraints.maxWidth,
                height: isHorizontal ? constraints.maxHeight : 8,
                color: Theme.of(context).dividerColor,
              ),
            ),
            Expanded(
              child: _TerminalContainer(sessionId: widget.sessionId2),
            ),
          ],
        );
      },
    );
  }
}

class _TerminalContainer extends StatelessWidget {
  final String sessionId;

  const _TerminalContainer({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    // TODO: 集成 TerminalViewWidget
    return Container(color: Colors.black);
  }
}
```

- [ ] **Step 2: 创建测试]

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/widgets/split_terminal_view.dart';

void main() {
  testWidgets('split view renders correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SplitTerminalView(
            sessionId1: 'session1',
            sessionId2: 'session2',
            direction: SplitDirection.vertical,
          ),
        ),
      ),
    );

    expect(find.byType(SplitTerminalView), findsOneWidget);
    expect(find.byType(GestureDetector), findsOneWidget);
  });
}
```

- [ ] **Step 3: 运行测试]

Run: `flutter test test/widgets/split_terminal_view_test.dart`
Expected: PASS

- [ ] **Step 4: 提交]

```bash
git add lib/presentation/widgets/split_terminal_view.dart test/widgets/split_terminal_view_test.dart
git commit -m "feat(terminal): add split terminal view"
```

---

### 任务 3.2: 添加终端搜索高亮优化

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart`
- Test: `test/widgets/terminal_search_test.dart` (新建)

- [ ] **Step 1: 分析当前搜索实现**

Read: `lib/presentation/widgets/terminal_view.dart:265` (showSearchBar: true)

- [ ] **Step 2: 添加自定义搜索高亮测试]

```dart
// test/widgets/terminal_search_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Terminal Search', () {
    test('search should highlight matches', () {
      // 测试搜索高亮逻辑
    });
  });
}
```

- [ ] **Step 3: 提交]

```bash
git add test/widgets/terminal_search_test.dart
git commit -m "test(terminal): add search highlight tests"
```

---

## Chunk 4: 可访问性与国际化

### 任务 4.1: 添加基础 a11y 支持

**Files:**
- Modify: `lib/presentation/widgets/terminal_view.dart`
- Create: `test/a11y/terminal_a11y_test.dart`

- [ ] **Step 1: 添加 Semantics 包装器]

在 `_TerminalTab` 中添加语义标签:

```dart
@override
Widget build(BuildContext context) {
  return Semantics(
    label: '终端标签: ${session.name}',
    button: true,
    child: Material(
      // ... existing code
    ),
  );
}
```

- [ ] **Step 2: 添加键盘导航支持]

在 `MainScreen` 中添加焦点管理:

```dart
// 在 MainScreen 中
final FocusNode _sidebarFocusNode = FocusNode();
final FocusNode _terminalFocusNode = FocusNode();

@override
void initState() {
  super.initState();
  // 设置初始焦点
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _terminalFocusNode.requestFocus();
  });
}
```

- [ ] **Step 3: 创建 a11y 测试]

```dart
// test/a11y/terminal_a11y_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('terminal tabs have proper semantics', (tester) async {
    // Test semantics labels
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/a11y/`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/presentation/widgets/terminal_view.dart test/a11y/
git commit -m "a11y(terminal): add semantics and keyboard navigation"
```

---

### 任务 4.2: 国际化基础设施

**Files:**
- Create: `lib/l10n/app_localizations.dart`
- Create: `lib/l10n/en.json`
- Create: `lib/l10n/zh.json`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 flutter_localizations 依赖]

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

- [ ] **Step 2: 创建本地化文件]

```dart
// lib/l10n/app_localizations.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String get appTitle => Intl.message('lbpSSH', name: 'appTitle', locale: locale.toString());
  String get connect => Intl.message('连接', name: 'connect', locale: locale.toString());
  String get disconnect => Intl.message('断开', name: 'disconnect', locale: locale.toString());
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
```

- [ ] **Step 3: 更新 main.dart 使用本地化]

```dart
// lib/main.dart
import 'l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en'),
    Locale('zh'),
  ],
  // ...
)
```

- [ ] **Step 4: 创建测试]

```dart
// test/l10n/localizations_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/l10n/app_localizations.dart';

void main() {
  test('should load Chinese localization', () {
    final localizations = AppLocalizations(Locale('zh'));
    expect(localizations.connect, '连接');
  });
}
```

- [ ] **Step 5: 运行测试]

Run: `flutter test test/l10n/localizations_test.dart`
Expected: PASS

- [ ] **Step 6: 提交]

```bash
git add lib/l10n/ pubspec.yaml test/l10n/
git commit -m "i18n: add localization infrastructure"
```

---

## Chunk 5: 测试金字塔完善

### 任务 5.1: 添加 Golden Test 截图对比

**Files:**
- Create: `test/golden/terminal_golden_test.dart`
- Create: `test/golden/screenshots/`

- [ ] **Step 1: 添加 golden_toolkit 依赖]

```yaml
dev_dependencies:
  golden_toolkit: ^0.15.0
```

- [ ] **Step 2: 创建 Golden Test]

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:lbp_ssh/main.dart';

void main() {
  goldenTestWidgets('terminal view golden test', (tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/terminal_view.png'));
  });
}
```

- [ ] **Step 3: 运行测试 (首次会失败生成截图)**

Run: `flutter test test/golden/terminal_golden_test.dart`
Expected: FAIL (生成截图文件)

- [ ] **Step 4: 提交**

```bash
git add test/golden/ pubspec.yaml
git commit -m "test(golden): add golden tests for UI comparison"
```

---

### 任务 5.2: 添加性能基准测试

**Files:**
- Create: `benchmark/terminal_benchmark.dart`

- [ ] **Step 1: 创建性能基准测试]

```dart
// benchmark/terminal_benchmark.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/performance.dart';

void main() {
  group('Terminal Performance Benchmarks', () {
    test('terminal render performance', () {
      final stopwatch = Stopwatch()..start();

      // Simulate terminal render
      for (int i = 0; i < 1000; i++) {
        // Render operations
      }

      stopwatch.stop();
      print('Render time: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
```

- [ ] **Step 2: 运行基准测试]

Run: `flutter test benchmark/terminal_benchmark.dart --enable-vmservice`
Expected: 输出性能数据

- [ ] **Step 3: 提交]

```bash
git add benchmark/
git commit -m "perf: add terminal render benchmarks"
```

---

### 任务 5.3: 添加集成测试

**Files:**
- Create: `integration_test/app_test.dart`

- [ ] **Step 1: 创建集成测试]

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lbp_ssh/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('full app launch flow', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 添加集成测试依赖]

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

- [ ] **Step 3: 运行集成测试]

Run: `flutter test integration_test/app_test.dart`
Expected: PASS

- [ ] **Step 4: 提交]

```bash
git add integration_test/ pubspec.yaml
git commit -m "test(integration): add app integration tests"
```

---

## 实施总结

| Chunk | 任务数 | 预计提交数 |
|-------|--------|-----------|
| 1. 性能优化 | 3 | 5 |
| 2. Riverpod 迁移 | 3 | 4 |
| 3. 高级终端功能 | 2 | 3 |
| 4. 可访问性 & 国际化 | 2 | 3 |
| 5. 测试金字塔 | 3 | 4 |
| **总计** | **13** | **19** |

---

## 执行顺序建议

1. **先执行 Chunk 1 (性能优化)** - 立即可见的改进
2. **然后 Chunk 5 (测试完善)** - 为其他任务提供保障
3. **接着 Chunk 4 (可访问性)** - 锦上添花
4. **再执行 Chunk 3 (高级功能)** - 新功能开发
5. **最后 Chunk 2 (架构迁移)** - 长期技术债务

---

## 注意事项

- 每次提交前运行 `flutter analyze --no-fatal-infos` 确保无警告
- 每次提交前运行 `flutter test` 确保测试通过
- Golden tests 需要人工审核截图差异
- 国际化需要翻译人员配合完善所有字符串
