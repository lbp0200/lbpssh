import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lbp_ssh/domain/services/ssh_legacy_algorithms.dart';

void main() {
  group('legacyFallbackAlgorithms', () {
    test(
      'Given fallback set, '
      'When inspected, '
      'Then modern algorithms stay first (no security downgrade by default)',
      () {
        expect(legacyFallbackAlgorithms.kex.first, SSHKexType.x25519Rfc);
        expect(legacyFallbackAlgorithms.hostkey.first, SSHHostkeyType.ed25519);
        expect(legacyFallbackAlgorithms.cipher.first, SSHCipherType.aes256gcm);
      },
    );

    test('Given fallback set, '
        'When inspected, '
        'Then legacy algorithms removed by dartssh2 v4 are appended', () {
      expect(
        legacyFallbackAlgorithms.kex,
        containsAll([
          SSHKexType.dhGexSha1,
          SSHKexType.dh14Sha1,
          SSHKexType.dh1Sha1,
        ]),
      );
      expect(
        legacyFallbackAlgorithms.hostkey,
        contains(SSHHostkeyType.rsaSha1),
      );
      expect(
        legacyFallbackAlgorithms.cipher,
        containsAll([SSHCipherType.aes256cbc, SSHCipherType.aes128cbc]),
      );
    });

    test('Given fallback set, '
        'When inspected, '
        'Then weakest legacy kex is last resort', () {
      expect(legacyFallbackAlgorithms.kex.last, SSHKexType.dh1Sha1);
    });
  });

  group('isAlgorithmNegotiationFailure', () {
    test('Given raw StateError from transport, '
        'When checked, '
        'Then returns true', () {
      expect(
        isAlgorithmNegotiationFailure(
          StateError('No matching key exchange algorithm'),
        ),
        isTrue,
      );
    });

    test('Given full v4 error chain through authenticated/shell, '
        'When checked, '
        'Then unwraps SSHAuthAbortError/SSHSocketError and returns true', () {
      final chained = SSHAuthAbortError(
        'Connection closed before authentication',
        SSHSocketError(StateError('No matching client cipher algorithm')),
      );
      expect(isAlgorithmNegotiationFailure(chained), isTrue);
    });

    test('Given server-side disconnect for no common algorithm, '
        'When checked, '
        'Then returns true', () {
      final disconnected = SSHDisconnectError(
        3,
        'no matching key exchange method found [preauth]',
      );
      expect(isAlgorithmNegotiationFailure(disconnected), isTrue);
    });

    test('Given app-wrapped message preserving original text, '
        'When checked, '
        'Then matches by text and returns true', () {
      expect(
        isAlgorithmNegotiationFailure(
          Exception(
            '建立会话失败: SSHAuthAbortError('
            'Connection closed before authentication, '
            'SSHSocketError(No matching host key algorithm))',
          ),
        ),
        isTrue,
      );
    });

    test('Given unrelated errors, '
        'When checked, '
        'Then returns false (no wasted reconnect)', () {
      expect(isAlgorithmNegotiationFailure(Exception('boom')), isFalse);
      expect(
        isAlgorithmNegotiationFailure(
          StateError('SSH config identity files all failed: 2 file(s)'),
        ),
        isFalse,
      );
      expect(
        isAlgorithmNegotiationFailure(SSHAuthAbortError('wrong password')),
        isFalse,
      );
    });

    test('Given "no matching" without algorithm context, '
        'When checked, '
        'Then returns false', () {
      expect(
        isAlgorithmNegotiationFailure(
          Exception('no matching host found in config'),
        ),
        isFalse,
      );
    });
  });
}
