# 高吞吐数据 CPU 优化计划

> 背景：SSH 连接远程服务器产生大量数据时 CPU 占用较高。
> 诊断方法：通过对 kterm 解析器、缓冲区、渲染管线的逐层基准测试定位热点。

## ✅ 最终基准测试结果

| 场景 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 纯文本 1000 行 | 8.3 ms (9.5 MB/s) | **3.6 ms (22.1 MB/s)** | **2.3x** |
| 纯文本 5000 行 | 72.9 ms (5.4 MB/s) | **21.0 ms (18.9 MB/s)** | **3.5x** |
| 纯文本 20000 行 | 414 ms (3.8 MB/s) | **127 ms (12.5 MB/s)** | **3.3x** |
| 彩色文本 1000 行 | 39.7 ms (5.7 MB/s) | **26.1 ms (8.6 MB/s)** | **1.5x** |
| 彩色文本 5000 行 | 148 ms (7.5 MB/s) | **131 ms (8.7 MB/s)** | **1.2x** |
| 彩色文本 20000 行 | 696 ms (6.5 MB/s) | **487 ms (9.3 MB/s)** | **1.4x** |

## 已完成优化

### ✅ P0: Terminal.write() 纯文本快速路径

- **文件**: `/Users/lbp/Projects/kterm.dart/lib/src/terminal.dart` (line 305-317)
- **改动**: 在 `Terminal.write()` 入口检查数据是否包含 ESC 字节 (`\x1b`)，若无则直接写入 `_buffer`，跳过整个解析器
- **原理**: 纯文本数据（`cat`、`tail -f` 等）无需经过 EscapeParser 的逐字符状态机，直接批量写入缓冲区
- **收益**: 纯文本吞吐量从 ~5 MB/s 提升到 ~18 MB/s（3.5x）

### ✅ P3: SshService Last login 过滤优化

- **文件**: `/Users/lbp/Projects/lbpSSH/lib/domain/services/ssh_service.dart` (line 180-199)
- **改动**: `output.split('\n')` 改为 `indexOf('\n')` 逐行扫描，避免创建临时字符串列表
- **收益**: 仅连接初期触发一次，节省 ~340µs

## 已评估但暂缓

### ⏸️ P1: Buffer.writeChar() ASCII 快速路径

- **评估结果**: 基准测试噪声大，收益不稳定。ASCII 字符在 `wcwidth()` 中已有 `codePoint < 127 → 1` 快速路径，增加额外分支反而引入不确定性

### ⏸️ P2: 增量 dirty 区域渲染

- **评估结果**: Flutter 的 `Canvas` 每帧是全新的，必须全量重绘。无法通过只画部分行来节省。`RepaintBoundary` 已隔离终端区域。如需进一步优化 paint，需考虑 `ParagraphCache` 命中率或行级缓存

## 未优化项

### P4: 基准测试回归（已覆盖）

- 基准测试文件: `/Users/lbp/Projects/lbpSSH/test/benchmarks/terminal_write_benchmark_test.dart`
- 每次优化后运行验证，确保吞吐量提升