import 'dart:math';
import 'dart:io';
import 'package:kterm/kterm.dart';
import 'package:test/test.dart';

/// 生成带 ANSI 颜色的文本行，模拟彩色日志输出
String generateColoredLine(int cols, int lineNum) {
  final rng = Random(lineNum);
  final colors = [31, 32, 33, 34, 35, 36, 37, 91, 92, 93, 94, 95, 96, 97];
  final buf = StringBuffer();
  var pos = 0;
  while (pos < cols) {
    final color = colors[rng.nextInt(colors.length)];
    final bold = rng.nextBool();
    final len = min(rng.nextInt(10) + 1, cols - pos);
    buf.write(bold ? '\x1b[1;${color}m' : '\x1b[${color}m');
    for (var i = 0; i < len; i++) {
      buf.writeCharCode(0x20 + rng.nextInt(0x5e)); // 可打印 ASCII
    }
    buf.write('\x1b[0m');
    pos += len;
  }
  buf.writeln();
  return buf.toString();
}

/// 生成纯文本行
String generatePlainLine(int cols, int lineNum) {
  final rng = Random(lineNum);
  final buf = StringBuffer();
  for (var i = 0; i < cols; i++) {
    buf.writeCharCode(0x20 + rng.nextInt(0x5e));
  }
  buf.writeln();
  return buf.toString();
}

/// 生成 "tail -f" 风格追加行（带时间戳+日志级别颜色）
String generateLogLine(int cols, int lineNum) {
  final rng = Random(lineNum);
  final levels = ['INFO', 'WARN', 'ERROR', 'DEBUG'];
  final level = levels[rng.nextInt(levels.length)];
  final levelColor = switch (level) {
    'ERROR' => 31,
    'WARN'  => 33,
    'INFO'  => 32,
    'DEBUG' => 36,
    _       => 37,
  };
  final buf = StringBuffer();
  buf.write('\x1b[90m${DateTime.now().toIso8601String()}\x1b[0m ');
  buf.write('\x1b[1;${levelColor}m[$level]\x1b[0m ');
  buf.write('\x1b[37m');
  final remaining = cols - 30;
  for (var i = 0; i < max(remaining, 10); i++) {
    buf.writeCharCode(0x20 + rng.nextInt(0x5e));
  }
  buf.write('\x1b[0m');
  buf.writeln();
  return buf.toString();
}

void main() {
  const terminalWidth = 80;
  const terminalHeight = 24;
  const totalLines = 5000;
  const warmupLines = 200;

  Terminal createTerminal() {
    final t = Terminal(maxLines: 10000);
    t.resize(terminalWidth, terminalHeight);
    return t;
  }

  // 数据生成
  late String largePlainText;
  late String largeColoredText;
  late String largeLogText;

  setUp(() {
    // 预生成数据
    final plainBuf = StringBuffer();
    final coloredBuf = StringBuffer();
    final logBuf = StringBuffer();
    for (var i = 0; i < totalLines; i++) {
      plainBuf.write(generatePlainLine(terminalWidth, i));
      coloredBuf.write(generateColoredLine(terminalWidth, i));
      logBuf.write(generateLogLine(terminalWidth, i));
    }
    largePlainText = plainBuf.toString();
    largeColoredText = coloredBuf.toString();
    largeLogText = logBuf.toString();
  });

  group('Terminal write 性能基准测试', () {
    test('Plain text throughput (纯文本)', () {
      final terminal = createTerminal();
      // Warmup
      terminal.write(largePlainText.substring(0, warmupLines * terminalWidth));
      terminal.notifyListeners();

      final sw = Stopwatch()..start();
      terminal.write(largePlainText);
      sw.stop();
      terminal.notifyListeners();

      final bytes = largePlainText.length;
      final elapsedMs = sw.elapsedMicroseconds / 1000;
      final throughput = (bytes / 1024 / 1024) / (elapsedMs / 1000);
      print(
        '[Plain] ${totalLines} lines, ${bytes} bytes: '
        '${elapsedMs.toStringAsFixed(1)} ms, '
        '${throughput.toStringAsFixed(1)} MB/s'
      );
      expect(terminal.buffer.lines.length, greaterThan(terminalHeight));
    });

    test('Colored text throughput (彩色ANSI文本)', () {
      final terminal = createTerminal();
      // Warmup
      terminal.write(largeColoredText.substring(0, warmupLines * terminalWidth));
      terminal.notifyListeners();

      final sw = Stopwatch()..start();
      terminal.write(largeColoredText);
      sw.stop();
      terminal.notifyListeners();

      final bytes = largeColoredText.length;
      final elapsedMs = sw.elapsedMicroseconds / 1000;
      final throughput = (bytes / 1024 / 1024) / (elapsedMs / 1000);
      print(
        '[Colored] ${totalLines} lines, ${bytes} bytes: '
        '${elapsedMs.toStringAsFixed(1)} ms, '
        '${throughput.toStringAsFixed(1)} MB/s'
      );
    });

    test('Log-style text throughput (日志风格)', () {
      final terminal = createTerminal();
      // Warmup
      terminal.write(largeLogText.substring(0, warmupLines * terminalWidth));
      terminal.notifyListeners();

      final sw = Stopwatch()..start();
      terminal.write(largeLogText);
      sw.stop();
      terminal.notifyListeners();

      final bytes = largeLogText.length;
      final elapsedMs = sw.elapsedMicroseconds / 1000;
      final throughput = (bytes / 1024 / 1024) / (elapsedMs / 1000);
      print(
        '[Log] ${totalLines} lines, ${bytes} bytes: '
        '${elapsedMs.toStringAsFixed(1)} ms, '
        '${throughput.toStringAsFixed(1)} MB/s'
      );
    });

    test('Incremental write (增量写入模拟 tail -f)', () {
      final terminal = createTerminal();
      // 先填充终端
      terminal.write(largePlainText.substring(0, terminalHeight * terminalWidth));
      terminal.notifyListeners();

      // 模拟逐行追加
      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        terminal.write(generateLogLine(terminalWidth, i) + generateLogLine(terminalWidth, i + 500));
      }
      sw.stop();
      terminal.notifyListeners();

      final elapsedMs = sw.elapsedMicroseconds / 1000;
      print(
        '[Incremental] 500 small writes: '
        '${elapsedMs.toStringAsFixed(1)} ms, '
        'avg ${(elapsedMs / 500).toStringAsFixed(3)} ms/write'
      );
    });
  });

  group('EscapeParser 单独基准', () {
    /// 直接测试解析器，隔离 buffer 开销
    test('SGR-heavy text parse (大量颜色切换)', () {
      final terminal = createTerminal();

      // 生成高密度 SGR 文本：每个字符一个颜色
      final sgrBuf = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        sgrBuf.write('\x1b[3${i % 7}m');
        sgrBuf.write('A');
        sgrBuf.write('\x1b[0m');
      }
      final sgrText = sgrBuf.toString();

      // Warmup
      terminal.write(sgrText.substring(0, 200));
      terminal.notifyListeners();

      final sw = Stopwatch()..start();
      terminal.write(sgrText);
      sw.stop();
      terminal.notifyListeners();

      final bytes = sgrText.length;
      final elapsedMs = sw.elapsedMicroseconds / 1000;
      print(
        '[SGR-heavy] 1000 SGR sequences: '
        '${elapsedMs.toStringAsFixed(3)} ms, '
        '${(bytes / elapsedMs).toStringAsFixed(1)} bytes/ms'
      );
    });

    test('Large OSC-8 hyperlink text (超链接文本)', () {
      final terminal = createTerminal();

      // 生成带超链接的文本
      final linkBuf = StringBuffer();
      for (var i = 0; i < 500; i++) {
        linkBuf.write('\x1b]8;id=$i;https://example.com/$i\x1b\\');
        linkBuf.write('Link $i ');
        linkBuf.write('\x1b]8;;\x1b\\');
      }
      linkBuf.writeln();
      final linkText = linkBuf.toString();

      final sw = Stopwatch()..start();
      terminal.write(linkText);
      sw.stop();
      terminal.notifyListeners();

      final bytes = linkText.length;
      final elapsedMs = sw.elapsedMicroseconds / 1000;
      print(
        '[OSC-8] 500 hyperlinks: '
        '${elapsedMs.toStringAsFixed(1)} ms, '
        '${(bytes / max(elapsedMs, 0.001)).toStringAsFixed(1)} bytes/ms'
      );
    });
  });

  group('数据量级对比', () {
    /// 对比不同数据量级下的耗时，找线性关系
    for (final size in [1000, 5000, 20000]) {
      test('Plain text ${size} lines', () {
        final terminal = createTerminal();
        final buf = StringBuffer();
        for (var i = 0; i < size; i++) {
          buf.write(generatePlainLine(terminalWidth, i));
        }
        final text = buf.toString();

        // Warmup
        terminal.write(text.substring(0, min(2000, text.length)));
        terminal.notifyListeners();

        final sw = Stopwatch()..start();
        terminal.write(text);
        sw.stop();
        terminal.notifyListeners();

        final elapsedMs = sw.elapsedMicroseconds / 1000;
        final bytes = text.length;
        print(
          '[Plain/$size] ${bytes} bytes → ${elapsedMs.toStringAsFixed(1)} ms '
          '(${(bytes / 1024 / max(elapsedMs, 0.001)).toStringAsFixed(1)} MB/s)'
        );
      });

      test('Colored text ${size} lines', () {
        final terminal = createTerminal();
        final buf = StringBuffer();
        for (var i = 0; i < size; i++) {
          buf.write(generateColoredLine(terminalWidth, i));
        }
        final text = buf.toString();

        // Warmup
        terminal.write(text.substring(0, min(2000, text.length)));
        terminal.notifyListeners();

        final sw = Stopwatch()..start();
        terminal.write(text);
        sw.stop();
        terminal.notifyListeners();

        final elapsedMs = sw.elapsedMicroseconds / 1000;
        final bytes = text.length;
        print(
          '[Colored/$size] ${bytes} bytes → ${elapsedMs.toStringAsFixed(1)} ms '
          '(${(bytes / 1024 / max(elapsedMs, 0.001)).toStringAsFixed(1)} MB/s)'
        );
      });
    }
  });

  group('SshService 输出缓冲开销', () {
    /// 模拟 SshService 的 buffer/flush 机制
    test('StringBuffer vs direct concat (大量小写入)', () {
      const chunkCount = 5000;
      const chunkSize = 80;

      // 方法 1: StringBuffer
      final sw1 = Stopwatch()..start();
      final sb = StringBuffer();
      for (var i = 0; i < chunkCount; i++) {
        final chunk = 'x' * chunkSize;
        sb.write(chunk);
      }
      final result1 = sb.toString();
      sw1.stop();

      // 方法 2: 直接拼接
      final sw2 = Stopwatch()..start();
      var s = '';
      for (var i = 0; i < chunkCount; i++) {
        final chunk = 'x' * chunkSize;
        s += chunk;
      }
      sw2.stop();

      print(
        '[StringBuffer] ${chunkCount} chunks × ${chunkSize}B: '
        '${sw1.elapsedMicroseconds} µs'
      );
      print(
        '[Direct concat] ${chunkCount} chunks × ${chunkSize}B: '
        '${sw2.elapsedMicroseconds} µs'
      );
      expect(result1.length, equals(chunkCount * chunkSize));
    });

    test('String split overhead (Last login 过滤开销)', () {
      // 模拟 SshService 中的 Last login 过滤
      final buf = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        buf.writeln('line $i with some random content');
      }
      final text = buf.toString();

      final sw = Stopwatch()..start();
      for (var iter = 0; iter < 100; iter++) {
        var output = text;
        if (output.contains('Last login:')) {
          final lines = output.split('\n');
          // ... 过滤逻辑
          final filtered = <String>[];
          for (final line in lines) {
            if (!line.startsWith('Last login:')) {
              filtered.add(line);
            }
          }
          output = filtered.join('\n');
        }
      }
      sw.stop();
      print(
        '[Split overhead] 1000 lines × 100 iterations: '
        '${sw.elapsedMicroseconds} µs '
        '(avg ${(sw.elapsedMicroseconds / 100).toStringAsFixed(1)} µs/iter)'
      );
    });
  });
}