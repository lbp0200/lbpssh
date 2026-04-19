import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// Helper to check if SSH integration tests should run
/// Set environment variable ENABLE_SSH_INTEGRATION_TESTS=1 to enable
bool get shouldRunSSHIntegrationTests {
  return Platform.environment['ENABLE_SSH_INTEGRATION_TESTS'] == '1';
}

/// Get SSH test target from environment or default
String get sshTestHost {
  return Platform.environment['SSH_TEST_HOST'] ?? '192.168.1.250';
}

/// Throws a skip exception for test frameworks
void skipSSHIntegrationTest() {
  if (!shouldRunSSHIntegrationTests) {
    throw 'SKIP: Set ENABLE_SSH_INTEGRATION_TESTS=1 to run SSH integration tests';
  }
}

Future<List<SSHKeyPair>> loadTestIdentities() async {
  final identities = <SSHKeyPair>[];
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '/Users/lbp';

  final keyPaths = [
    '$home/.ssh/id_rsa',
    '$home/.ssh/id_ed25519',
    '$home/.ssh/id_ecdsa',
    '$home/.ssh/id_ed25519_sk',
  ];

  for (final keyPath in keyPaths) {
    final file = File(keyPath);
    if (await file.exists()) {
      try {
        final keyContent = await file.readAsString();
        identities.addAll(SSHKeyPair.fromPem(keyContent));
        print('✓ Loaded key(s) from $keyPath');
      } catch (e) {
        print('✗ Failed to parse $keyPath: $e');
      }
    }
  }

  if (identities.isEmpty) {
    print('⚠️  No SSH keys found. Tried: $keyPaths');
  }

  return identities;
}
