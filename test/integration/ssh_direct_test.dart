import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

Future<void> main() async {
  print('=' * 70);
  print('SSH Direct Connection Test - 192.168.1.250');
  print('=' * 70);
  print('');

  final stopwatch = Stopwatch()..start();

  try {
    print('Step 1: TCP connect...');
    final socket = await SSHSocket.connect(
      '192.168.1.250',
      22,
      timeout: Duration(seconds: 5),
    );
    print('  ✓ Connected in ${stopwatch.elapsedMilliseconds}ms');

    print('\nStep 2: Loading SSH keys...');
    final identities = await _loadIdentities();
    if (identities.isEmpty) {
      stderr.writeln('✗ No SSH identities found');
      exit(1);
    }
    print('  ✓ Loaded ${identities.length} key pair(s)');

    print('\nStep 3: SSH handshake...');
    final client = SSHClient(
      socket,
      username: 'lbp',
      identities: identities,
      keepAliveInterval: Duration(seconds: 30),
    );
    print('  ✓ Authenticated');

    print('\nStep 4: Creating shell session...');
    final session = await client.shell(
      pty: SSHPtyConfig(type: 'xterm', width: 80, height: 24),
    );
    print('  ✓ Shell ready');

    print('\nStep 5: Capturing output...');
    final output = StringBuffer();
    final chunks = <int>[];

    session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          (data) {
            output.write(data);
            chunks.add(data.length);
          },
          onError: (e) => stderr.writeln('STDOUT ERROR: $e'),
        );

    session.stderr
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          (data) => stderr.writeln('STDERR: $data'),
          onError: (e) => stderr.writeln('STDERR ERROR: $e'),
        );

    print('  → Waiting 6s for welcome banner...');
    await Future.delayed(Duration(seconds: 6));

    final full = output.toString();
    final lines = full.split('\n');
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).length;

    print('\n' + '=' * 70);
    print('RESULTS');
    print('=' * 70);
    print('Total time:      ${stopwatch.elapsedMilliseconds}ms');
    print('Chunks:          ${chunks.length}');
    print('Total bytes:     ${full.length}');
    print('Total lines:     ${lines.length}');
    print('Non-empty lines: $nonEmpty');
    print('');

    print('Content checks:');
    print('  ${full.contains('Last login:') ? '✓' : '✗'} Contains "Last login:"');
    print('  ${full.contains('Linux') ? '✓' : '✗'} Contains "Linux"');
    print('  ${full.contains('_') && full.contains('|') ? '✓' : '✗'} Contains ASCII art');
    print('  ${full.contains('\x1b') ? '✓' : '✗'} Contains ANSI codes');

    print('\n--- Full Output ---');
    print(full);
    print('--- End ---\n');

    if (lines.length <= 2 || full.length < 50) {
      stderr.writeln('⚠️  WARNING: Output may be truncated!');
    } else {
      stdout.writeln('✓ Output appears complete');
    }

    session.close();
    client.close();
    await socket.close();

  } catch (e, st) {
    stderr.writeln('✗ Error: $e');
    if (st.toString().isNotEmpty) stderr.writeln(st);
    exit(1);
  }
}

Future<List<SSHKeyPair>> _loadIdentities() async {
  final identities = <SSHKeyPair>[];
  final home = Platform.environment['HOME'] ?? '/Users/lbp';
  final paths = ['$home/.ssh/id_rsa', '$home/.ssh/id_ed25519', '$home/.ssh/id_ecdsa'];

  for (final p in paths) {
    final f = File(p);
    if (await f.exists()) {
      try {
        final content = await f.readAsString();
        final pairs = SSHKeyPair.fromPem(content);
        identities.addAll(pairs);
        print('  ✓ $p (${pairs.length} pair(s))');
      } catch (e) {
        stderr.writeln('  ✗ Failed $p: $e');
      }
    }
  }
  return identities;
}
