import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// Test: Does reusing SSH client cause PTY output truncation?
/// Runs PTY test FIRST, then non-PTY on same client
void main() async {
  print('=== Client Reuse Test: PTY First ===\n');

  final socket = await SSHSocket.connect('192.168.1.250', 22, timeout: Duration(seconds: 5));
  print('✓ Socket connected');

  final identities = await _loadIdentities();
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

  // Test 2: Non-PTY SECOND
  print('--- Test 2: shell() without PTY ---');
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
  print('✓ Test complete');
}

int min(int a, int b) => a < b ? a : b;

Future<List<SSHKeyPair>> _loadIdentities() async {
  final identities = <SSHKeyPair>[];
  final home = Platform.environment['HOME'] ?? '/Users/lbp';
  final keyPath = '$home/.ssh/id_rsa';
  final file = File(keyPath);
  if (await file.exists()) {
    try {
      final keyContent = await file.readAsString();
      identities.addAll(SSHKeyPair.fromPem(keyContent));
      print('✓ Loaded ${identities.length} key(s)');
    } catch (e) {
      print('✗ Error: $e');
    }
  }
  return identities;
}
