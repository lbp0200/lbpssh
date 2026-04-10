import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'ssh_test_utils.dart';

void main() {
  test('SSH client reuse MOTD behavior (requires SSH server)', () async {
    await _runTest();
  }, skip: !shouldRunSSHIntegrationTests
      ? 'Set ENABLE_SSH_INTEGRATION_TESTS=1 to run SSH integration tests'
      : null);
}

Future<void> _runTest() async {
  print('=== Client Reuse Test: PTY First ===\n');

  final socket = await SSHSocket.connect(sshTestHost, 22, timeout: Duration(seconds: 5));
  print('✓ Socket connected');

  final identities = await loadTestIdentities();
  final client = SSHClient(socket, username: 'lbp', identities: identities);
  print('✓ Authenticated\n');

  // Test 1: PTY FIRST
  print('--- Test 1: shell() with PTY (xterm 80x24) ---');
  final session1 = await client.shell(pty: SSHPtyConfig(type: 'xterm', width: 80, height: 24));
  final out1 = StringBuffer();
  final sub1 = session1.stdout.cast<List<int>>().transform(utf8.decoder).listen(out1.write);
  await Future.delayed(Duration(seconds: 5));
  await sub1.cancel();
  session1.close();
  final fullOut1 = out1.toString();
  print('Chars: ${fullOut1.length}, Lines: ${fullOut1.split('\n').length}');
  print('First 300: ${fullOut1.substring(0, min(300, fullOut1.length))}');
  print('');

  // Test 2: Non-PTY SECOND (on same client)
  print('--- Test 2: shell() without PTY (same client) ---');
  final session2 = await client.shell();
  final out2 = StringBuffer();
  final sub2 = session2.stdout.cast<List<int>>().transform(utf8.decoder).listen(out2.write);
  await Future.delayed(Duration(seconds: 5));
  await sub2.cancel();
  session2.close();
  final fullOut2 = out2.toString();
  print('Chars: ${fullOut2.length}, Lines: ${fullOut2.split('\n').length}');
  print('First 300: ${fullOut2.substring(0, min(300, fullOut2.length))}');
  print('');

  client.close();
  await socket.close();

  // Verify: First channel gets MOTD, second doesn't
  expect(fullOut1.length, greaterThan(1000), reason: 'First channel should have full MOTD');
  expect(fullOut2.length, lessThan(500), reason: 'Second channel on same client gets truncated');
  print('✓ Confirmed: MOTD only on first channel per SSH connection');
}

int min(int a, int b) => a < b ? a : b;
