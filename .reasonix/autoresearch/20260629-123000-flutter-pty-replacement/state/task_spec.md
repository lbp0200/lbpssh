# flutter_pty 替代方案调研报告

## 调研目标
找到支持 Swift Package Manager (SPM) 的 flutter_pty 替代品，同时保持完整的 PTY 功能。

## 候选方案评估

### 1. kyroon_pty (❌ 不推荐)
- **GitHub**: https://github.com/cesarmod2017/kyroon_pty
- **版本**: 1.0.4 (26 天前发布)
- **API 兼容性**: ⭐⭐⭐⭐⭐ 几乎与 flutter_pty 完全相同
- **SPM 支持**: ❌ **不支持** - 只有 .podspec，没有 Package.swift
- **结论**: 与 flutter_pty 有相同的 SPM 问题，无法解决根本问题

### 2. portable_pty (⚠️ 需权衡)
- **GitHub**: https://github.com/kingwill101/dart_terminal
- **版本**: 0.0.5 (57 天前发布)
- **API 兼容性**: ⭐⭐ 完全不同的 API 设计
- **SPM 支持**: ✅ **完全绕过** - 使用 Rust 原生库 + native_toolchain_rust
- **关键差异**:
  - 使用同步读取 (`readSync`) 而非流式输出
  - 构造函数不同: `PortablePty.open()` + `.spawn()` vs `Pty.start()`
  - 属性名不同: `.childPid` vs `.pid`
  - 退出码处理不同: `.tryWait()` vs `.exitCode` Future
- **迁移成本**: ⚠️ **高** - 需要重构 LocalTerminalService 架构

### 3. pty (❌ 不推荐)
- **版本**: 0.1.1 (5 年前发布)
- **状态**: 已过时，无人维护
- **结论**: 不适合生产环境使用

## 核心发现

### SPM 问题的本质
- **flutter_pty**: 使用 CocoaPods → 不支持 SPM
- **kyroon_pty**: 使用 CocoaPods → 不支持 SPM
- **portable_pty**: 使用 Rust 原生库 → 完全绕过 CocoaPods/SPM

### API 兼容性对比
```
flutter_pty API:                    portable_pty API:
Pty.start()                         PortablePty.open() + .spawn()
.output (Stream)                    .readSync() (同步)
.write(bytes)                       .writeString() / .writeBytes()
.exitCode (Future)                  .tryWait() (非阻塞)
.pid                                .childPid
.resize(rows, cols)                 .resize(rows:, cols:)
.kill()                             .kill() / .close()
```

## 建议方案

### 方案 A: 暂不替换 (推荐)
**理由**:
1. SPM 警告目前只是警告，不影响编译和运行
2. Flutter 正在渐进式迁移 SPM，CocoaPods 短期内仍可用
3. 等待 flutter_pty 作者适配 SPM，或等待 Flutter 强制要求时再处理
4. 避免引入不稳定的 0.0.5 版本依赖

**风险**: 未来 Flutter 版本可能将警告变为错误

### 方案 B: 切换到 portable_pty
**理由**:
1. 彻底解决 SPM 问题
2. 使用 Rust 实现，性能可能更好
3. 支持 Web 传输（未来扩展）

**风险**:
1. API 完全不同，需要重构 LocalTerminalService
2. 版本 0.0.5，可能不稳定
3. 需要 Rust 工具链或预编译二进制文件
4. 下载量仅 527，社区验证较少

### 方案 C: Fork flutter_pty 添加 SPM 支持
**理由**:
1. 保持现有 API 不变
2. 自己控制维护进度

**风险**:
1. 需要维护 fork 版本
2. 需要了解 Swift Package Manager 和 Flutter 插件系统

## 最终建议

**选择方案 A (暂不替换)**，原因:
1. 当前系统工作正常，SPM 警告不影响功能
2. 等待更成熟的替代方案出现
3. portable_pty 版本太新 (0.0.5)，风险较高
4. 迁移成本高，不值得为一个警告投入

**监控计划**:
- 关注 flutter_pty 的 GitHub Issues 和 Releases
- 关注 Flutter 官方关于 SPM 迁移的公告
- 当 Flutter 将 SPM 警告变为错误时，再评估 portable_pty 或其他方案
