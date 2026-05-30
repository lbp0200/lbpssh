# TUI Mode for lbpSSH

## Overview

Add a Text-based User Interface (TUI) mode to lbpSSH, sharing the same data layer and domain services as the existing Flutter GUI. Users can manage SSH connections and connect to remote servers entirely from the terminal.

## Technology Stack

- **Framework**: `utopia_tui` ^2.0.0 — Dart TUI library with components (list, input, table, panel, tabs, status bar)
- **SSH**: `dartssh2` (existing, reused)
- **Persistence**: JSON file via `ConnectionRepository` (existing, reused)
- **Entry point**: `bin/lbpssh_tui.dart`

## Architecture

### Directory Structure

```
lib/tui/
  tui_app.dart              # TuiApp subclass, main lifecycle
  tui_router.dart           # Screen stack / routing
  tui_state.dart            # Shared state (current screen, selected connection, etc.)
  screens/
    connection_list_screen.dart   # P1: Connection list (default screen)
    connection_form_screen.dart   # P2: Add/edit connection
    ssh_terminal_screen.dart      # P3: SSH terminal session (passthrough)
    sftp_browser_screen.dart      # P4: SFTP file browser
    settings_screen.dart          # P5: App settings
  widgets/
    status_bar.dart               # Bottom status bar (connection state, key hints)
    key_hint_bar.dart             # Context-sensitive shortcut bar
    confirm_dialog.dart           # Reusable confirmation popup
    input_form.dart               # Reusable form field group for connection editing
    connection_table.dart         # Reusable connection list table widget
    screen.dart                   # Base screen mixin/class

bin/
  lbpssh_tui.dart                 # Entry point
```

### Screen Routing

Simple stack-based navigation:

```
ConnectionListScreen
  ├─ Enter → ssh_terminal_screen (connect & passthrough)
  ├─ 'a'   → connection_form_screen (add new)
  ├─ 'e'   → connection_form_screen (edit selected)
  ├─ 's'   → sftp_browser_screen (browse files)
  ├─ 't'   → settings_screen (terminal settings)
  └─ 'q'   → exit

ConnectionFormScreen
  ├─ Enter → save & pop back
  └─ Esc   → discard & pop back

SshTerminalScreen
  ├─ Ctrl+Q / F10 → disconnect & pop back
  └─ All other keys → passthrough to SSH

SftpBrowserScreen
  ├─ Up/Down → navigate files
  ├─ Enter   → enter directory / download
  ├─ Backspace → parent directory
  └─ 'q'     → pop back
```

### Data Flow

```
TUI Screen → TuiState (change) → rebuild TuiApp
                ↓
        ConnectionRepository (JSON file)
                ↓
        SshService / dartssh2 → SSH session
```

## Phase 1: Foundation + Connection List + SSH Connect

### Files to create/modify

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Add `utopia_tui: ^2.0.0` dependency |
| `bin/lbpssh_tui.dart` | Entry point: init repo, create TuiRunner |
| `lib/tui/tui_app.dart` | Main `TuiApp` subclass, screen routing |
| `lib/tui/tui_state.dart` | `TuiState` with current screen, selected connection, connections list |
| `lib/tui/widgets/screen.dart` | Base screen abstract class |
| `lib/tui/widgets/status_bar.dart` | Status bar with connection count and key hints |
| `lib/tui/widgets/connection_table.dart` | Connection list table rendering |
| `lib/tui/screens/connection_list_screen.dart` | Main screen with connection table and keyboard shortcuts |
| `lib/tui/screens/ssh_terminal_screen.dart` | SSH terminal session (skeleton for P3) |

### Connection List Screen Layout

```
┌─────────────────────────────────────────────────┐
│  lbpSSH TUI v1.6.5                    Ctrl+Q Quit │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────────┐│
│  │ # │ 名称           │ 主机          │ 端口 ││
│  ├─────────────────────────────────────────────┤│
│  │ 1 │ 生产服务器      │ 192.168.1.10 │ 22   ││
│  │ 2 │ 开发服务器      │ dev.example  │ 2222 ││
│  │ 3 │ 数据库节点      │ 10.0.0.5     │ 22   ││
│  │   │                                    │    ││
│  └─────────────────────────────────────────────┘│
│                                                 │
├─────────────────────────────────────────────────┤
│  [a]添加  [e]编辑  [d]删除  [s]SFTP  [q]退出     │
└─────────────────────────────────────────────────┘
```

### SSH Terminal Screen (Phase 3 placeholder)

Phase 1 connects via dartssh2 and writes output directly. Phase 3 will implement full raw-mode passthrough.

## Phase 2: Connection CRUD

### Files to create

| File | Purpose |
|------|---------|
| `lib/tui/screens/connection_form_screen.dart` | Add/edit connection form |
| `lib/tui/widgets/input_form.dart` | Reusable form group |

### Connection Form Layout

```
┌─────────────────────────────────────────────────┐
│  lbpSSH TUI                     Esc Cancel  ↵ OK │
├─────────────────────────────────────────────────┤
│                                                 │
│  连接名称: [生产服务器_________________________]  │
│  主机地址: [192.168.1.10______________________]  │
│  端口:     [22____________]                      │
│  用户名:   [root__________]                      │
│  认证方式: [密码认证 ▼    ]                      │
│  密码:     [**************]                      │
│  备注:     [______________________________]      │
│                                                 │
├─────────────────────────────────────────────────┤
│  Tab:下一字段  Enter:保存  Esc:取消              │
└─────────────────────────────────────────────────┘
```

## Phase 3: SSH Terminal Passthrough

### Approach

1. Connect via `dartssh2` SSHClient
2. Put host terminal in raw mode (disable echo, line buffering)
3. Create stdin → SSH stdin pipe
4. Create SSH stdout → terminal stdout pipe
5. Intercept Ctrl+Q / F10 for disconnect

### Key considerations

- Raw mode setup: `stty -echo -icanon -isig` (or use `dart:io` stdin raw mode)
- Terminal restore on disconnect: save/restore `stty` settings
- Resize events: trap SIGWINCH, forward window size to SSH pty
- UTF-8 passthrough for international input

## Phase 4: SFTP Browser

### Layout

```
┌─────────────────────────────────────────────────┐
│  SFTP: /home/user                    Backspace ↑│
├─────────────────────────────────────────────────┤
│  📁  ..                                          │
│  📁  projects                                    │
│  📁  downloads                                   │
│  📄  notes.txt                                   │
│  📄  config.yml                                  │
├─────────────────────────────────────────────────┤
│  [d]下载  [u]上传  [q]返回                       │
└─────────────────────────────────────────────────┘
```

## Phase 5: Settings & Polish

- Terminal config editing (font, colors, etc.)
- Sync settings (GitHub token, repo)
- Theme switching (dark/light/contrast)
- Search/filter connections
- Connection import/export
- Error handling with user-friendly messages

## Implementation Order

```
P1a: Add utopia_tui dependency + create tui_app/tui_state/router skeleton
P1b: Connection list screen (read-only)
P1c: SSH connect & simple terminal passthrough
P2a: Connection form screen (add/edit)
P2b: Delete connection + confirmation dialog
P2c: Search/filter connections
P3:  Full raw-mode SSH terminal
P4:  SFTP browser
P5:  Settings + polish
```

## Testing Strategy

- Unit tests for `tui_state.dart` state transitions
- Widget tests for individual screens using utopia_tui test utilities
- Manual integration testing (TUI requires real terminal)
