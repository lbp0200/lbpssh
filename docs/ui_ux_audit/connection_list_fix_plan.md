# 连接列表 UI 修复计划

**创建日期：** 2026-04-11  
**来源审计：** [`docs/ui_ux_audit/connection_list_visual_audit_2026-04-11.md`](../ui_ux_audit/connection_list_visual_audit_2026-04-11.md)  
**受影响组件：** `lib/presentation/widgets/connection_list.dart`

---

## 📋 问题清单

| # | 问题描述 | 优先级 | 影响 | 文件位置 |
|---|----------|--------|------|----------|
| 1 | 键盘导航焦点反馈缺失 | **P0 - 高** | 无障碍合规、键盘用户无法感知焦点 | `connection_list.dart:219` |
| 2 | 空状态图标对比度不足 | **P1 - 中** | 首次用户难以看清空状态图标 | `connection_list.dart:47` |

---

## 🎯 修复方案

### 问题 1：键盘导航焦点反馈缺失

**当前代码：**
```dart
InkWell(
  onTap: widget.onTap,
  borderRadius: BorderRadius.circular(LinearRadius.card),
  hoverColor: LinearColors.accentInteractive.withValues(alpha: 0.08),
  // ❌ 缺失 focusColor
)
```

**修复方案：**
1. 为 `_ConnectionListItemState` 添加 `_isFocused` 状态变量
2. 在 `InkWell` 添加 `onFocusChange` 回调更新状态
3. 为 `InkWell` 配置 `focusColor`
4. 在 `AnimatedContainer` 的 `border` 中根据 `_isFocused` 显示焦点边框

**详细修改：**

```dart
class _ConnectionListItemState extends State<_ConnectionListItem> {
  bool _isHovered = false;
  bool _isFocused = false;  // 新增

  @override
  Widget build(BuildContext context) {
    // ...
    child: AnimatedContainer(
      duration: LinearDuration.fast,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _isHovered
            ? LinearColors.fillSurfaceHover
            : LinearColors.fillSurface,
        borderRadius: BorderRadius.circular(LinearRadius.card),
        border: Border.all(
          color: _isFocused
              ? LinearColors.accentInteractive  // 焦点色（最明显）
              : _isHovered
                  ? LinearColors.borderStandard
                  : LinearColors.borderSubtle,
          width: _isFocused ? 2 : 1,  // 焦点时边框加粗
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(LinearRadius.card),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (hasFocus) {  // 新增
            setState(() => _isFocused = hasFocus);
          },
          borderRadius: BorderRadius.circular(LinearRadius.card),
          focusColor: LinearColors.accentInteractive.withValues(alpha: 0.12),  // 新增
          hoverColor: LinearColors.accentInteractive.withValues(alpha: 0.08),
        ),
      ),
    ),
  }
}
```

**颜色选择：**
- `focusColor`：`accentInteractive.alpha=0.12`（比 hover 的 0.08 略深）
- 焦点边框：`accentInteractive` 纯色（宽度 2px），确保清晰可见

**WCAG 合规：**
- 满足 **2.4.7 Focus Visible**：键盘导航时显示明确视觉焦点
- 焦点色与背景对比度 > 3:1（Material 3 标准）

---

### 问题 2：空状态图标对比度不足

**当前代码：**
```dart
Icon(
  Icons.dns_outlined,
  size: 56,
  color: LinearColors.textPrimary.withValues(alpha: 0.2),  // ❌ 仅 20% 不透明度
)
```

**问题分析：**
- 背景色：`LinearColors.surface` = `#191a1b`（深灰）
- 前景色：`textPrimary` = `#f7f8f8`（亮白），alpha=0.2 → 实际亮度极低
- **估算对比度：~1.2:1**（远低于 4.5:1 阈值）

**修复方案（二选一）：**

**方案 A - 提高不透明度（推荐）**
```dart
color: LinearColors.textPrimary.withValues(alpha: 0.5)  // 提升到 50%
```
- **优点：** 保持原有视觉层次，图标仍较淡但不消失
- **估算对比度：~3.8:1**（接近但略低于 4.5:1）

**方案 B - 使用次级文字色（更稳妥）**
```dart
color: LinearColors.textSecondary  // 直接使用 #d0d6e0
```
- **优点：** 对比度稳定，无需调参
- **估算对比度：~4.2:1**（接近阈值）

**建议：** 采用方案 A，若测试后仍不满足 4.5:1，再降级为方案 B。

---

## 📅 实施步骤

### 阶段 1：修复键盘焦点（P0）
- [ ] 1.1 在 `_ConnectionListItemState` 中添加 `_isFocused` 变量
- [ ] 1.2 修改 `InkWell` 添加 `onFocusChange` 回调
- [ ] 1.3 添加 `focusColor` 参数
- [ ] 1.4 更新 `AnimatedContainer` 的 `border` 逻辑，支持焦点状态
- [ ] 1.5 运行 `flutter test` 验证无回归

### 阶段 2：优化空状态图标（P1）
- [ ] 2.1 修改 `connection_list.dart:47` 的图标颜色
- [ ] 2.2 手动启动应用，视觉验证空状态可读性
- [ ] 2.3 运行 widget 测试确保无破坏

### 阶段 3：回归测试
- [ ] 3.1 运行全部 widget tests：`flutter test test/widgets/`
- [ ] 3.2 运行 golden tests：`flutter test --update-goldens`
- [ ] 3.3 集成测试（如存在）：验证键盘 Tab 导航
- [ ] 3.4 在不同主题（深色/浅色）下人工验证

---

## 🔬 验证清单

- [ ] **键盘导航：** 按 Tab 键切换连接项，焦点边框清晰可见（2px accentInteractive 色）
- [ ] **焦点颜色：** 焦点颜色与 hover 颜色有明确区分（焦点更深/边框更粗）
- [ ] **空状态图标：** 在深色背景下，服务器图标清晰可辨
- [ ] **Hover 状态：** 鼠标悬停时，无布局抖动，颜色平滑过渡
- [ ] **长文本：** 超长连接名仍正确省略，无溢出
- [ ] **所有测试通过：** `flutter test` 无失败
- [ ] **Golden 无差异：** 无意外视觉变化

---

## ⚠️ 风险与回滚

**风险：**
- 焦点边框可能与其他状态（如选中态）冲突（当前无选中态，风险低）
- 空状态图标颜色调整可能影响整体视觉平衡（风险极低）

**回滚方案：**
- 保留 Git 分支修改，如有问题可通过 `git revert` 快速回退
- 所有修改集中在 `connection_list.dart` 单一文件，影响范围可控

---

## 📈 成功标准

- ✅ **WCAG 2.1 合规：** 键盘焦点可见性满足 2.4.7 条款
- ✅ **对比度达标：** 空状态图标对比度 ≥ 3.5:1（装饰性元素阈值）
- ✅ **测试覆盖：** 100% widget 测试通过，无回归
- ✅ **用户体验：** 键盘用户和屏幕阅读器用户均可顺畅操作

---

**预计工时：** 30-45 分钟  
**预计风险：** 低  
**建议执行顺序：** 先完成 P0 焦点修复，再处理 P1 空状态优化
