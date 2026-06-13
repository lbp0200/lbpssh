# lbpSSH

跨平台 SSH 终端管理器

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-green.svg)](#)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-blue.svg)](#)
[![CI](https://github.com/lbp0200/lbpssh/actions/workflows/ci.yml/badge.svg)](https://github.com/lbp0200/lbpssh/actions/workflows/ci.yml)

[English](README.md) | [中文](README.zh-CN.md)

</div>

---

## 功能特性

- **SSH 连接管理** - 添加、编辑、删除 SSH 连接配置
- **多种认证方式** - 密码、密钥、密钥+密码
- **跳板机支持** - 通过跳板机连接到目标服务器
- **终端模拟器** - 基于 xterm 的完整交互式终端体验
- **多标签页** - 同时管理多个 SSH 连接
- **配置同步** - 支持同步到 Gitee Gist 或 GitHub Gist
- **加密存储** - 敏感信息本地加密存储

---

## 为什么选择 lbpSSH

| 功能 | lbpSSH | Termius | MobaXterm | PuTTY | Tabby |
|------|---------|---------|-----------|-------|-------|
| **跨平台** | ✅ Win/Lin/Mac | ✅ Win/Lin/Mac | ❌ Windows | ❌ Windows | ✅ Win/Lin/Mac |
| **开源免费** | ✅ MIT | ❌ 收费 | ❌ 收费 | ✅ 免费 | ✅ 免费 |
| **配置同步** | ✅ Gist | ✅ Termius Cloud | ❌ | ❌ | ❌ |
| **跳板机** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **多标签页** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **加密存储** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **自托管同步** | ✅ Gitee | ❌ | ❌ | ❌ | ❌ |

### 核心优势

1. **完全开源** - MIT 许可证，代码完全透明

2. **自托管同步** - 支持 Gitee Gist，无需第三方云服务

3. **隐私优先** - 所有数据本地加密存储

4. **Flutter 开发** - 现代化 UI，一套代码多平台

---

## 下载安装

### macOS

#### Homebrew (推荐)

```bash
# 添加 Homebrew Tap
brew tap lbp0200/homebrew-lbpssh-tap

# 安装 lbpSSH
brew install --cask lbpssh
```

#### 手动下载

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-macos-universal.zip`，解压后拖动 `lbpSSH.app` 到 Applications 文件夹。

---

### Windows

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-windows-x64.zip`，解压后运行 `lbpSSH.exe`。

---

### Linux

从 [GitHub Releases](https://github.com/lbp0200/lbpssh/releases/latest) 下载 `lbpSSH-linux-x64.zip`，解压后运行：

```bash
cd bundle
chmod +x lbpSSH
./lbpSSH
```

---

## 截图

![lbpSSH 终端](docs/screen/截屏ll.jpg)

---

## 快速开始

### 前置要求

- Flutter SDK (3.10.7+)
- Dart SDK
- Desktop platform support (Windows, Linux, macOS)

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

### 构建发布版本

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

---

## 配置同步

将 SSH 配置同步到云端 Gist，方便多设备共享配置。

### Gitee Gist 同步

1. 访问 [Gitee 个人访问令牌](https://gitee.com/profile/personal_access_tokens) 创建 Token
2. 在应用的"同步设置"中选择 **Gitee Gist**
3. 填入 Token，选择是否填写 Gist ID
4. 点击"保存配置"，然后使用"上传配置"同步到 Gist

### GitHub Gist 同步

1. 访问 [GitHub Settings](https://github.com/settings/tokens/new?scopes=gist) 创建 Personal Access Token（需勾选 `gist` 权限）
2. 在应用的"同步设置"中选择 **GitHub Gist**
3. 填入 Token，选择是否填写 Gist ID
4. 点击"保存配置"，然后使用"上传配置"同步到 Gist

---

## 使用说明

### 添加 SSH 连接

1. 点击应用栏的"添加连接"按钮
2. 填写连接信息：
   - 连接名称
   - 主机地址和端口
   - 用户名
   - 选择认证方式（密码/密钥/密钥+密码）
   - 输入相应的认证信息
3. 可选：配置跳板机
4. 点击"保存"

### 连接管理

- 点击连接列表中的连接快速打开终端
- 支持多标签页同时连接多个服务器
- 标签页支持拖拽排序
- 支持拖拽文件到终端上传

### 文件传输

lbpSSH 使用 Kitty 协议的 OSC 5113 实现文件传输。

> **注意**: 远程服务器需要安装 Kitty 的 `ki` 工具才能接收文件

- **已实现**: 文件上传、文件列表浏览、文件下载

---

## Kitty 协议支持

lbpSSH 全面支持 Kitty 终端协议，提供丰富的终端增强功能。

### 已实现功能

| 功能 | 协议 |
|------|------|
| 文件传输 | OSC 5113 |
| 桌面通知 | OSC 99 |
| 图像显示 | OSC 71 |
| Shell 集成 | OSC 133 |
| 超链接 | OSC 8 |
| 鼠标指针 | OSC 22 |
| 颜色栈 | OSC 4, 21 |
| 文本大小 | - |
| 终端标记 | - |
| 窗口标题 | OSC 0, 1, 2 |
| 提示符颜色 | OSC 10-132, 708 |
| 键盘协议 | OSC 1, 2, 200, 201 |
| 远程控制 | OSC 5xx |
| 终端模式 | SM/RM |
| 会话管理 | - |
| 终端操作 | OSC 5 |
| 下划线样式 | OSC 4:58 |
| 扩展搜索 | - |
| 程序启动 | OSC 6 |
| 多光标 | OSC 6 > |
| 广色域 | - |
| 滚动控制 | OSC 2026 |
| 窗口布局 | OSC 20 |
| 终端截图 | OSC 20 |

### 文件传输增强

- ✅ 文件上传
- ✅ 拖拽上传
- ✅ 文件列表浏览
- ✅ 文件下载
- ✅ 目录导航 (cd, cd ..)
- ✅ 目录操作 (mkdir, rm, rmdir)
- ✅ 压缩传输 (compression=zlib)
- ✅ 符号链接
- ✅ 元数据保留
- ✅ 传输取消
- ✅ 静默模式
- ✅ 密码授权

### 安装 ki 工具

> **注意**: 远程服务器需要安装 Kitty 的 `ki` 工具才能使用文件传输功能

```bash
# 方法一：从源码编译
git clone https://github.com/kovidgoyal/kitty
cd kitty
python3 setup.py ki

# 方法二：使用 pip
pip3 install kitty-cli
```

---

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── core/                        # 核心配置
│   ├── theme/                   # 主题配置
│   └── constants/               # 常量定义
├── data:                         # 数据层
│   ├── models/                  # 数据模型
│   └── repositories/             # 数据仓库
├── domain:                       # 业务逻辑层
│   └── services/                # 业务服务
├── presentation:                  # 展示层
│   ├── screens/                 # 页面
│   ├── widgets/                 # 组件
│   └── providers/               # 状态管理
└── utils/                        # 工具类
```

---

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter | UI 框架 |
| dartssh2 | SSH 客户端 |
| xterm | 终端模拟器 |
| flutter_pty | 伪终端支持 |
| flutter_riverpod | 状态管理 |
| dio | HTTP 客户端 |
| encrypt | 加密 |
| shared_preferences | 本地存储 |

---

## 开发

### 代码规范

- 文件命名使用 `snake_case`
- 类使用 `PascalCase`
- 变量方法使用 `camelCase`
- 私有成员使用下划线前缀

### 代码生成

修改模型类后需要重新生成代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 代码分析

```bash
flutter analyze
```

---

## 贡献

欢迎提交 Issue 和 Pull Request！

---

## 许可证

MIT License
