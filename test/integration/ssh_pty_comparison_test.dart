import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

Future<void> main() async {
  print('=' * 70);
  print('PTY vs NON-PTY Shell Comparison Test');
  print('=' * 70);
  print('');

  final socket = await SSHSocket.connect('192.168.1.250', 22, timeout: Duration(seconds: 5));
  print('✓ Connected to 192.168.1.250');

  final identities = await _loadIdentities();
  final client = SSHClient(socket, username: 'lbp', identities: identities);
  print('✓ Authenticated\n');

  // Test 1: shell without PTY
  print('--- Test 1: shell() without PTY ---');
  final session1 = await client.shell();
  final out1 = StringBuffer();
  final sub1 = session1.stdout.cast<List<int>>().transform(utf8.decoder).listen(out1.write);
  await Future.delayed(Duration(seconds: 5));
  await sub1.cancel();
  session1.close();
  final fullOut1 = out1.toString();
  final lines1 = fullOut1.split('\n');
  print('Lines: ${lines1.length}');
  if (lines1.length <= 2) {
    print('⚠️  No welcome banner (only ${lines1.length} lines)');
  } else {
    print('✓ Has welcome content');
  }
  print('Full output (${fullOut1.length} chars):');
  print(fullOut1);
  print('');

  // Test 2: shell with PTY - use a fresh client/connection
  print('--- Test 2: shell() with PTY (xterm 80x24) ---');
  // Close old socket and create new connection to isolate PTY behavior
  client.close();
  await socket.close();

  final socket2 = await SSHSocket.connect('192.168.1.250', 22, timeout: Duration(seconds: 5));
  final client2 = SSHClient(socket2, username: 'lbp', identities: identities);

  final session2 = await client2.shell(pty: SSHPtyConfig(type: 'xterm', width: 80, height: 24));
  final out2 = StringBuffer();
  final sub2 = session2.stdout.cast<List<int>>().transform(utf8.decoder).listen(out2.write);
  await Future.delayed(Duration(seconds: 5));
  await sub2.cancel();
  session2.close();
  final fullOut2 = out2.toString();
  final lines2 = fullOut2.split('\n');
  print('Lines: ${lines2.length}');
  if (lines2.length > 5) {
    print('✓ Full welcome banner received');
  } else {
    print('✗ Welcome banner truncated or missing');
  }
  print('Full output (${fullOut2.length} chars):');
  print(fullOut2);
  print('');

  client2.close();
  await socket2.close();

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
    final content = await file.readAsString();
    identities.addAll(SSHKeyPair.fromPem(content));
    print('✓ Loaded SSH key');
  }
  return identities;
}
