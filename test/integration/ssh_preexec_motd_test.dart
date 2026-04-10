import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// Test: Does executing a command BEFORE shell() affect MOTD on the shell?
void main() async {
  print('=== Pre-shell execute() impact on MOTD ===\n');

  await _testShellOnly();
  await _testWithPreExec();
}

Future<void> _testShellOnly() async {
  print('--- Test 1: shell() only, no pre-exec ---');
  final socket = await SSHSocket.connect('192.168.1.250', 22, timeout: Duration(seconds: 5));
  final client = SSHClient(socket, username: 'lbp', identities: await _loadIdentities());
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
  final socket = await SSHSocket.connect('192.168.1.250', 22, timeout: Duration(seconds: 5));
  final client = SSHClient(socket, username: 'lbp', identities: await _loadIdentities());
  print('✓ Authenticated');

  // Simulate _getShellEnvironment() - run commands BEFORE shell
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
}

int min(int a, int b) => a < b ? a : b;

Future<List<SSHKeyPair>> _loadIdentities() async {
  final identities = <SSHKeyPair>[];
  final home = Platform.environment['HOME'] ?? '/Users/lbp';
  final file = File('$home/.ssh/id_rsa');
  if (await file.exists()) {
    identities.addAll(SSHKeyPair.fromPem(await file.readAsString()));
    print('✓ Loaded key');
  }
  return identities;
}
