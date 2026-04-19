import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'ssh_test_utils.dart';

void main() {
  test(
    'Direct SSH connection (requires SSH server)',
    () async {
      await _runTest();
    },
    skip: !shouldRunSSHIntegrationTests
        ? 'Set ENABLE_SSH_INTEGRATION_TESTS=1 to run SSH integration tests'
        : null,
  );
}

Future<void> _runTest() async {
  print('=' * 70);
  print('SSH Direct Connection Test - $sshTestHost');
  print('=' * 70);
  print('');

  final stopwatch = Stopwatch()..start();

  try {
    print('Step 1: TCP connect...');
    final socket = await SSHSocket.connect(
      sshTestHost,
      22,
      timeout: Duration(seconds: 5),
    );
    print('  ✓ Connected in ${stopwatch.elapsedMilliseconds}ms');

    print('\nStep 2: Loading SSH keys...');
    final identities = await loadTestIdentities();
    if (identities.isEmpty) {
      stderr.writeln('✗ No SSH identities found');
      fail('No SSH identities found');
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

    session.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
      output.write(data);
      chunks.add(data.length);
    }, onError: (Object e) => stderr.writeln('STDOUT ERROR: $e'));

    session.stderr
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          (data) => stderr.writeln('STDERR: $data'),
          onError: (Object e) => stderr.writeln('STDERR ERROR: $e'),
        );

    print('  → Waiting 6s for welcome banner...');
    await Future<void>.delayed(Duration(seconds: 6));

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
    print(
      '  ${full.contains('Last login:') ? '✓' : '✗'} Contains "Last login:"',
    );
    print('  ${full.contains('Linux') ? '✓' : '✗'} Contains "Linux"');
    print(
      '  ${full.contains('_') && full.contains('|') ? '✓' : '✗'} Contains ASCII art',
    );
    print('  ${full.contains('\x1b') ? '✓' : '✗'} Contains ANSI codes');

    print('\n--- Full Output ---');
    print(full);
    print('--- End ---\n');

    if (lines.length <= 2 || full.length < 50) {
      stderr.writeln('⚠️  WARNING: Output may be truncated!');
    } else {
      stdout.writeln('✓ Output appears complete');
    }

    // Assertions
    expect(
      full.length,
      greaterThan(1000),
      reason: 'Should have substantial output',
    );
    expect(lines.length, greaterThan(20), reason: 'Should have many lines');
    expect(full.contains('Linux'), isTrue, reason: 'Should contain Linux info');
    expect(
      full.contains('Last login:'),
      isTrue,
      reason: 'Should have login marker',
    );

    session.close();
    client.close();
    await socket.close();
  } catch (e, st) {
    stderr.writeln('✗ Error: $e');
    if (st.toString().isNotEmpty) stderr.writeln(st);
    rethrow;
  }
}
