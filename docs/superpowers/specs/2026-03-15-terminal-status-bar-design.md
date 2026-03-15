# SSH 终端状态栏设计文档

**版本**: 1.0
**日期**: 2026-03-15
**功能**: 终端连接状态显示与断线通知

---

## 1. 功能概述

在每个终端标签页下方添加状态栏，显示 SSH 连接状态、延迟、连接时长和服务器信息。当连接断开时，通过状态栏变色、SnackBar 提示和重连按钮通知用户。

---

## 2. UI/UX 规范

### 2.1 布局

- **位置**: 终端标签页下方，每个终端标签页独立显示
- **高度**: 24px
- **宽度**: 100%

```
┌─────────────────────────────────────────────┐
│  标签页栏 (48px)                             │
├─────────────────────────────────────────────┤
│                                              │
│              终端内容                         │
│              (Expanded)                       │
│                                              │
├─────────────────────────────────────────────┤
│ ● Connected • 32ms • 00:15:30 • user@host  │  ← 状态栏 (24px)
└─────────────────────────────────────────────┘
```

### 2.2 配色方案

使用 Flutter Theme 扩展颜色，确保与深色/浅色主题一致：

| 状态 | 背景色 | 文字色 | 指示器 |
|------|--------|--------|--------|
| 连接中 | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurface` | `Colors.amber` |
| 已连接 | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurface` | `Colors.green` |
| 已断开 | `Colors.red.shade900` | `Colors.white` | `Colors.red` |

**注**：本地终端（Local）使用 `Colors.blue` 指示器，显示 "Local"

### 2.3 状态栏内容

| 字段 | 格式 | 示例 | 备注 |
|------|------|------|------|
| 状态指示器 | 圆点 + 文字 | `● Connected` | 支持国际化 |
| 延迟 | `Nms` | `32ms` | SSH 连接时显示，本地终端不显示 |
| 连接时长 | `HH:MM:SS` | `00:15:30` | 连接成功后开始计时 |
| 服务器 | `user@host` | `root@192.168.1.1` | 本地终端显示 "Local" |

### 2.4 断开状态显示

```
● 已断开                        [重连]
```

- 背景色变为 `Colors.red.shade900`
- 显示国际化文字 "已断开" / "Disconnected"
- 右侧显示 "重连" 按钮（本地终端无此按钮）

---

## 3. 功能规范

### 3.1 显示信息

1. **连接状态**: 连接中 / 已连接 / 已断开
2. **网络延迟**: 每秒更新，显示毫秒
3. **连接时长**: 连接成功后开始计时，格式 HH:MM:SS
4. **服务器信息**: 用户名@主机名

### 3.2 断线通知

当检测到连接断开时：

1. **状态栏**: 背景变红，显示 "Disconnected"
2. **SnackBar**: 显示消息 "连接已断开"
3. **重连按钮**: 点击后尝试重新连接

### 3.3 状态流

```
SshService.sshStateStream → TerminalProvider → TerminalSession → UI 状态栏
```

- `SshConnectionState.disconnected` → 显示断开状态
- `SshConnectionState.connecting` → 显示连接中
- `SshConnectionState.connected` → 显示已连接，开始计时
- `SshConnectionState.error` → 显示错误状态

---

## 4. 技术实现

### 4.1 修改文件

| 文件 | 修改内容 |
|------|----------|
| `lib/domain/services/terminal_service.dart` | TerminalSession 添加状态相关字段 |
| `lib/domain/services/ssh_service.dart` | 添加延迟获取方法（可选） |
| `lib/presentation/providers/terminal_provider.dart` | 透传状态流到 session |
| `lib/presentation/widgets/terminal_view.dart` | 添加状态栏 widget |

### 4.2 新增组件

```
TerminalStatusBar (StatefulWidget)
├── _TerminalStatusBarState
│   ├── Timer _durationTimer      # 连接时长计时器
│   └── Timer? _latencyTimer      # 延迟测量定时器
└── Widget build()
    ├── 连接状态指示器 (Icon + Text)
    ├── 延迟显示 (Text)           # 仅 SSH 连接显示
    ├── 连接时长 (Text)
    └── 服务器信息 (Text)
```

### 4.3 延迟计算（可选）

- SSH 连接建立后启动定时器，每 5 秒通过 channel 数据测量延迟
- 如无法测量，显示 "--" 或隐藏延迟字段
- 本地终端不显示延迟

---

## 5. 验收标准

- [ ] 每个终端标签页下方显示独立状态栏
- [ ] SSH 连接状态栏显示：连接状态、延迟、时长、服务器
- [ ] 本地终端状态栏显示：状态、时长、"Local"
- [ ] 连接中状态：黄色指示器
- [ ] 已连接状态：绿色指示器
- [ ] 断开状态：红色背景 + "已断开" + 重连按钮
- [ ] 断线时显示 SnackBar 消息 "连接已断开"
- [ ] 点击重连按钮可重新连接
- [ ] 使用 Flutter Theme 颜色，与深色/浅色主题一致
