import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/encryption.dart';

void main() {
  group('EncryptionUtil', () {
    group('deriveKey', () {
      test(
        'Given short password, When deriving key, Then produces 32-byte key',
        () {
          final key = EncryptionUtil.deriveKey('short');

          expect(key.length, 32);
        },
      );

      test(
        'Given long password, When deriving key, Then produces 32-byte key',
        () {
          final key = EncryptionUtil.deriveKey('a' * 50);

          expect(key.length, 32);
        },
      );

      test(
        'Given empty password, When deriving key, Then produces 32-byte key',
        () {
          final key = EncryptionUtil.deriveKey('');

          expect(key.length, 32);
        },
      );

      test(
        'Given password with special characters, When deriving key, Then produces valid key',
        () {
          final key = EncryptionUtil.deriveKey('p@ss!word#123');

          expect(key.length, 32);
        },
      );

      test(
        'Given same password, When deriving key multiple times, Then produces same key',
        () {
          final key1 = EncryptionUtil.deriveKey('testpassword');
          final key2 = EncryptionUtil.deriveKey('testpassword');

          expect(base64Encode(key1), base64Encode(key2));
        },
      );

      test(
        'Given different passwords, When deriving keys, Then produces different keys',
        () {
          final key1 = EncryptionUtil.deriveKey('password1');
          final key2 = EncryptionUtil.deriveKey('password2');

          expect(base64Encode(key1), isNot(base64Encode(key2)));
        },
      );
    });

    group('encrypt/decrypt', () {
      test(
        'Given simple text and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = 'Hello, World!';
          const password = 'testpassword123';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test('Given empty string, When encrypting, Then throws exception', () {
        const original = '';
        const password = 'testpassword123';

        expect(
          () => EncryptionUtil.encrypt(original, password),
          throwsA(isA<Exception>()),
        );
      });

      test(
        'Given Chinese text and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = '你好，世界！';
          const password = 'testpassword123';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test(
        'Given special characters and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = '!@#\$%^&*()_+-=[]{}|;\':",./<>?';
          const password = 'testpassword123';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test(
        'Given multiline text and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = '''Line 1
Line 2
Line 3''';
          const password = 'testpassword123';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test(
        'Given same plaintext, When encrypting multiple times, Then produces different ciphertext',
        () {
          const original = 'Same text';
          const password = 'testpassword123';

          final encrypted1 = EncryptionUtil.encrypt(original, password);
          final encrypted2 = EncryptionUtil.encrypt(original, password);

          expect(encrypted1, isNot(encrypted2));
        },
      );

      test(
        'Given encrypted text, When decrypting with wrong password, Then throws exception',
        () {
          const original = 'Secret message';
          const correctPassword = 'correctpassword';
          const wrongPassword = 'wrongpassword';

          final encrypted = EncryptionUtil.encrypt(original, correctPassword);

          expect(
            () => EncryptionUtil.decrypt(encrypted, wrongPassword),
            throwsException,
          );
        },
      );

      test(
        'Given JSON string and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = '{"name": "test", "value": 123}';
          const password = 'jsonpassword';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test(
        'Given long text and password, When encrypting and decrypting, Then recovers original',
        () {
          final original = 'A' * 10000;
          const password = 'longtextpassword';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );

      test(
        'Given unicode characters and password, When encrypting and decrypting, Then recovers original',
        () {
          const original = 'Hello 你好 مرحبا Привет 🌍';
          const password = 'unicodepassword';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decrypted = EncryptionUtil.decrypt(encrypted, password);

          expect(decrypted, original);
        },
      );
    });

    group('generateRandomKey', () {
      test(
        'Given no input, When generating random key, Then produces key of length 44',
        () {
          final key = EncryptionUtil.generateRandomKey();

          expect(key.length, 44);
        },
      );

      test(
        'Given no input, When generating multiple random keys, Then produces different keys',
        () {
          final key1 = EncryptionUtil.generateRandomKey();
          final key2 = EncryptionUtil.generateRandomKey();

          expect(key1, isNot(key2));
        },
      );

      test(
        'Given no input, When generating random key, Then produces valid base64 key',
        () {
          final key = EncryptionUtil.generateRandomKey();

          expect(() => base64Decode(key), returnsNormally);
        },
      );
    });

    group('encryptWithKey/decryptWithKey', () {
      late Uint8List key;

      setUp(() {
        key = EncryptionUtil.randomBytes(32);
      });

      test(
        'Given text and key, When encrypting and decrypting, Then recovers original',
        () {
          const original = 'Hello with raw key!';

          final encrypted = EncryptionUtil.encryptWithKey(original, key);
          final decrypted = EncryptionUtil.decryptWithKey(encrypted, key);

          expect(decrypted, original);
        },
      );

      test(
        'Given same text and key, When encrypting multiple times, Then produces different ciphertext',
        () {
          const original = 'Same text with key';

          final encrypted1 = EncryptionUtil.encryptWithKey(original, key);
          final encrypted2 = EncryptionUtil.encryptWithKey(original, key);

          expect(encrypted1, isNot(encrypted2));
        },
      );

      test(
        'Given text, When encrypting with one key and decrypting with another, Then throws exception',
        () {
          const original = 'Secret key test';
          final wrongKey = EncryptionUtil.randomBytes(32);

          final encrypted = EncryptionUtil.encryptWithKey(original, key);

          expect(
            () => EncryptionUtil.decryptWithKey(encrypted, wrongKey),
            throwsException,
          );
        },
      );
    });

    group('encryptField/decryptField', () {
      late Uint8List key;

      setUp(() {
        key = EncryptionUtil.randomBytes(32);
      });

      test(
        'Given plaintext, When encrypting field, Then produces prefixed ciphertext',
        () {
          const original = 'sensitive data';

          final encrypted = EncryptionUtil.encryptField(original, key);

          expect(encrypted, startsWith('\$AES\$V1\$'));
          expect(encrypted, isNot(original));
        },
      );

      test(
        'Given encrypted field, When decrypting, Then recovers original',
        () {
          const original = 'my password';

          final encrypted = EncryptionUtil.encryptField(original, key);
          final decrypted = EncryptionUtil.decryptField(encrypted, key);

          expect(decrypted, original);
        },
      );

      test(
        'Given plaintext field, When decrypting, Then returns as-is',
        () {
          const original = 'plaintext value';

          final result = EncryptionUtil.decryptField(original, key);

          expect(result, original);
        },
      );

      test(
        'Given null field, When decrypting, Then returns null',
        () {
          final result = EncryptionUtil.decryptField(null, key);

          expect(result, isNull);
        },
      );

      test(
        'Given empty field, When decrypting, Then returns empty',
        () {
          const original = '';

          final result = EncryptionUtil.decryptField(original, key);

          expect(result, isEmpty);
        },
      );
    });

    group('isEncrypted', () {
      test(
        'Given prefixed string, When checking, Then returns true',
        () {
          expect(EncryptionUtil.isEncrypted('\$AES\$V1\$abc123'), isTrue);
        },
      );

      test(
        'Given plain string, When checking, Then returns false',
        () {
          expect(EncryptionUtil.isEncrypted('plaintext'), isFalse);
        },
      );

      test(
        'Given non-matching prefix, When checking, Then returns false',
        () {
          expect(EncryptionUtil.isEncrypted('\$BES\$V1\$abc123'), isFalse);
        },
      );
    });

    group('encryption format', () {
      test(
        'Given plaintext and password, When encrypting, Then produces base64 encoded ciphertext',
        () {
          const original = 'Test message';
          const password = 'testpassword';

          final encrypted = EncryptionUtil.encrypt(original, password);

          expect(() => base64Decode(encrypted), returnsNormally);
        },
      );

      test(
        'Given plaintext and password, When encrypting, Then includes IV in ciphertext',
        () {
          const original = 'Test message';
          const password = 'testpassword';

          final encrypted = EncryptionUtil.encrypt(original, password);
          final decoded = base64Decode(encrypted);

          expect(decoded.length, greaterThan(16));
        },
      );

      test(
        'Given encryptWithKey, When encrypting, Then produces IV prepended ciphertext',
        () {
          const original = 'Key-based test';
          final key = EncryptionUtil.randomBytes(32);

          final encrypted = EncryptionUtil.encryptWithKey(original, key);
          final decoded = base64Decode(encrypted);

          expect(decoded.length, greaterThan(16));
        },
      );
    });
  });
}
