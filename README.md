# lbpSSH

Cross-platform SSH Terminal Manager

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-green.svg)](#)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-blue.svg)](#)
[![CI](https://github.com/lbp0200/lbpssh/actions/workflows/ci.yml/badge.svg)](https://github.com/lbp0200/lbpssh/actions/workflows/ci.yml)

[English](README.md) | [中文](README.zh-CN.md)

</div>

---

## Features

- **SSH Connection Management** - Add, edit, delete SSH connections
- **Multiple Authentication Methods** - Password, Private Key, Private Key + Password
- **Jump Host Support** - Connect through jump/bastion hosts
- **Terminal Emulator** - Full interactive terminal based on xterm
- **Multi-tab Support** - Manage multiple SSH connections simultaneously
- **Configuration Sync** - Sync to Gitee Gist or GitHub Gist
- **Encrypted Storage** - Sensitive data encrypted locally

---

## Why lbpSSH

| Feature | lbpSSH | Termius | MobaXterm | PuTTY | Tabby |
|---------|--------|---------|-----------|-------|-------|
| **Cross-platform** | ✅ Win/Lin/Mac | ✅ Win/Lin/Mac | ❌ Windows | ❌ Windows | ✅ Win/Lin/Mac |
| **Open Source & Free** | ✅ MIT | ❌ Paid | ❌ Paid | ✅ Free | ✅ Free |
| **Config Sync** | ✅ Gist | ✅ Termius Cloud | ❌ | ❌ | ❌ |
| **Jump Host** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Multi-tab** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Encrypted Storage** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Self-hosted Sync** | ✅ Gitee | ❌ | ❌ | ❌ | ❌ |

### Key Advantages

1. **Fully Open Source** - MIT license, completely transparent code

2. **Self-hosted Sync** - Gitee Gist support, no third-party cloud required

3. **Privacy First** - All data encrypted locally

4. **Flutter Based** - Modern UI, single codebase multi-platform

---

## Download & Install

### macOS

#### Homebrew (Recommended)

```bash
# Add Homebrew Tap
brew tap lbp0200/homebrew-lbpssh-tap

# Install lbpSSH
brew install --cask lbpssh
```

#### Manual Download

Download `lbpSSH-macos-universal.zip` from [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest), unzip and drag `lbpSSH.app` to Applications.

---

### Windows

Download `lbpSSH-windows-x64.zip` from [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) and run `lbpSSH.exe`.

---

### Linux

Download `lbpSSH-linux-x64.zip` from [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) and run:

```bash
cd bundle
chmod +x lbpSSH
./lbpSSH
```

---

## Screenshots

![lbpSSH Terminal](docs/screen/截屏ll.jpg)

---

## Quick Start

### Requirements

- Flutter SDK (3.10.7+)
- Dart SDK
- Desktop platform support (Windows, Linux, macOS)

### Install Dependencies

```bash
flutter pub get
```

### Run Application

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

### Build for Release

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

---

## Configuration Sync

Sync SSH config to GitHub Gist for multi-device sharing.

1. Create a Personal Access Token at [GitHub Settings](https://github.com/settings/tokens/new?scopes=gist) (need `gist` scope)
2. Enter token in sync settings
3. Optionally fill Gist ID (leave blank to auto-create on first upload)
4. Save config, then use "Upload" to sync

---

## Usage

### Add SSH Connection

1. Click "Add Connection" button
2. Fill connection info:
   - Connection name
   - Host address and port
   - Username
   - Auth method (Password/Private Key/Private Key+Password)
   - Auth info
3. Optional: Configure jump host
4. Click "Save"

### Connection Management

- Click connection to open terminal
- Multi-tab for multiple servers
- Drag to reorder tabs
- Drag files to terminal to upload

### File Transfer

lbpSSH uses Kitty protocol OSC 5113 for file transfer.

> **Note**: Remote server needs Kitty's `ki` tool installed to receive files

- **Implemented**: File Upload, File list browsing, File download

---

## Kitty Protocol Support

lbpSSH fully supports Kitty terminal protocol with rich terminal enhancement features.

### Implemented Features

| Feature | Protocol |
|--------|----------|
| File Transfer | OSC 5113 |
| Desktop Notifications | OSC 99 |
| Graphics Protocol | OSC 71 |
| Shell Integration | OSC 133 |
| Hyperlinks | OSC 8 |
| Pointer Shapes | OSC 22 |
| Color Stack | OSC 4, 21 |
| Text Sizing | - |
| Marks | - |
| Window Title | OSC 0, 1, 2 |
| Prompt Colors | OSC 10-132, 708 |
| Keyboard Protocol | OSC 1, 2, 200, 201 |
| Remote Control | OSC 5xx |
| Terminal Modes | SM/RM |
| Session Management | - |
| Actions | OSC 5 |
| Underline Styles | OSC 4:58 |
| Extended Search | - |
| Program Launch | OSC 6 |
| Multiple Cursors | OSC 6 > |
| Wide Gamut Colors | - |
| Scroll Control | OSC 2026 |
| Layout Management | OSC 20 |
| Screenshot | OSC 20 |

### File Transfer Enhanced

- ✅ File Upload
- ✅ Drag-and-drop upload
- ✅ File list browsing
- ✅ File download
- ✅ Directory navigation (cd, cd ..)
- ✅ Directory operations (mkdir, rm, rmdir)
- ✅ Compression (compression=zlib)
- ✅ Symlink support
- ✅ Metadata preservation
- ✅ Transfer cancel
- ✅ Quiet mode
- ✅ Password authorization

### Install ki tool

> **Note**: Remote server needs Kitty's `ki` tool for file transfer

```bash
# Method 1: Build from source
git clone https://github.com/kovidgoyal/kitty
cd kitty
python3 setup.py ki

# Method 2: Use pip
pip3 install kitty-cli
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/                        # Core config
│   ├── theme/                   # Theme
│   └── constants/               # Constants
├── data/                         # Data layer
│   ├── models/                  # Data models
│   └── repositories/             # Repositories
├── domain/                       # Business logic
│   └── services/                # Services
├── presentation:                  # Presentation layer
│   ├── screens/                 # Screens
│   ├── widgets/                 # Widgets
│   └── providers/               # State management
└── utils/                        # Utilities
```

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| Flutter | Cross-platform UI |
| dartssh2 | SSH Client |
| xterm | Terminal Emulator |
| flutter_pty | PTY Support |
| flutter_riverpod | State Management |
| dio | HTTP Client |
| encrypt | Encryption |
| shared_preferences | Local Storage |

---

## Development

### Code Conventions

- Files: `snake_case`
- Classes: `PascalCase`
- Variables/Methods: `camelCase`
- Private members: underscore prefix

### Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Code Analysis

```bash
flutter analyze
```

---

## Contributing

Issues and PRs welcome!

---

## License

MIT License
