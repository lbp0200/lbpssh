import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'ssh_test_utils.dart';

void main() {
  test('Pre-exec consumes MOTD (requires SSH server)', () async {
    await _runTest();
  }, skip: !shouldRunSSHIntegrationTests
      ? 'Set ENABLE_SSH_INTEGRATION_TESTS=1 to run SSH integration tests'
      : null);
}

Future<void> _runTest() async {
  print('=== Pre-shell execute() impact on MOTD ===\n');
  await _testShellOnly();
  await _testWithPreExec();
}

Future<void> _testShellOnly() async {
  print('--- Test 1: shell() only, no pre-exec ---');
  final socket = await SSHSocket.connect(sshTestHost, 22, timeout: Duration(seconds: 5));
  final client = SSHClient(socket, username: 'lbp', identities: await loadTestIdentities());
  print('✓ Authenticated');

  final session = await client.shell(pty: SSHPtyConfig(type: 'xterm', width: 80, height: 24));
  final out = StringBuffer();
  session.stdout.cast<List<int>>().transform(utf8.decoder).listen(out.write);
  await Future.delayed(Duration(seconds: 5));
  session.close();
  client.close();
  await socket.close();

  final full = out.toString();
  print('Chars: ${full.length}, Lines: ${full.split('\n').length}');
  print('First 200: ${full.substring(0, min(200, full.length))}');
  print('');
}

Future<void> _testWithPreExec() async {
  print('--- Test 2: execute() before shell() ---');
  final socket = await SSHSocket.connect(sshTestHost, 22, timeout: Duration(seconds: 5));
  final client = SSHClient(socket, username: 'lbp', identities: await loadTestIdentities());
  print('✓ Authenticated');

  print('Running pre-shell execute commands...');
  final shellSession = await client.execute('echo \$SHELL');
  await for (final data in shellSession.stdout.cast<List<int>>()) {}
  shellSession.close();

  final pwdSession = await client.execute('pwd');
  await for (final data in pwdSession.stdout.cast<List<int>>()) {}
  pwdSession.close();

  print('Pre-shell commands completed, now creating shell...');

  final session = await client.shell(pty: SSHPtyConfig(type: 'xterm', width: 80, height: 24));
  final out = StringBuffer();
  session.stdout.cast<List<int>>().transform(utf8.decoder).listen(out.write);
  await Future.delayed(Duration(seconds: 5));
  session.close();
  client.close();
  await socket.close();

  final full = out.toString();
  print('Chars: ${full.length}, Lines: ${full.split('\n').length}');
  print('First 200: ${full.substring(0, min(200, full.length))}');
  print('');

  // Verify the bug: pre-exec should cause truncation
  expect(full.length, lessThan(500), reason: 'Pre-exec should consume MOTD');
  print('✓ Confirmed: pre-exec causes truncation (${full.length} chars)');
}

int min(int a, int b) => a < b ? a : b;
