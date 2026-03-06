import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/encryption.dart';
import 'dart:convert';

void main() {
  group('EncryptionUtil', () {
    group('deriveKey', () {
      test('Given short password, When deriving key, Then produces 32-byte key', () {
        final key = EncryptionUtil.deriveKey('short');

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test('Given long password, When deriving key, Then produces 32-byte key', () {
        final key = EncryptionUtil.deriveKey('a' * 50);

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test('Given empty password, When deriving key, Then produces 32-byte key', () {
        final key = EncryptionUtil.deriveKey('');

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test(
          'Given password with special characters, When deriving key, Then produces valid key',
          () {
        final key = EncryptionUtil.deriveKey('p@ss!word#123');

        expect(key.length, 32);
      });

      test('Given same password, When deriving key multiple times, Then produces same key',
          () {
        final key1 = EncryptionUtil.deriveKey('testpassword');
        final key2 = EncryptionUtil.deriveKey('testpassword');

        expect(base64Encode(key1.bytes), base64Encode(key2.bytes));
      });

      test(
          'Given different passwords, When deriving keys, Then produces different keys',
          () {
        final key1 = EncryptionUtil.deriveKey('password1');
        final key2 = EncryptionUtil.deriveKey('password2');

        expect(base64Encode(key1.bytes), isNot(base64Encode(key2.bytes)));
      });
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
      });

      test('Given empty string, When encrypting, Then throws exception', () {
        const original = '';
        const password = 'testpassword123';

        expect(
          () => EncryptionUtil.encrypt(original, password),
          throwsException,
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
      });

      test(
          'Given special characters and password, When encrypting and decrypting, Then recovers original',
          () {
        const original = '!@#\$%^&*()_+-=[]{}|;\':",./<>?';
        const password = 'testpassword123';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

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
      });

      test(
          'Given same plaintext, When encrypting multiple times, Then produces different ciphertext',
          () {
        const original = 'Same text';
        const password = 'testpassword123';

        final encrypted1 = EncryptionUtil.encrypt(original, password);
        final encrypted2 = EncryptionUtil.encrypt(original, password);

        expect(encrypted1, isNot(encrypted2));
      });

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
      });

      test(
          'Given JSON string and password, When encrypting and decrypting, Then recovers original',
          () {
        const original = '{"name": "test", "value": 123}';
        const password = 'jsonpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test(
          'Given long text and password, When encrypting and decrypting, Then recovers original',
          () {
        final original = 'A' * 10000;
        const password = 'longtextpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test(
          'Given unicode characters and password, When encrypting and decrypting, Then recovers original',
          () {
        const original = 'Hello 你好 مرحبا Привет 🌍';
        const password = 'unicodepassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });
    });

    group('generateRandomKey', () {
      test('Given no input, When generating random key, Then produces key of length 44', () {
        final key = EncryptionUtil.generateRandomKey();

        expect(key.length, 44);
      });

      test('Given no input, When generating multiple random keys, Then produces different keys', () {
        final key1 = EncryptionUtil.generateRandomKey();
        final key2 = EncryptionUtil.generateRandomKey();

        expect(key1, isNot(key2));
      });

      test('Given no input, When generating random key, Then produces valid base64 key', () {
        final key = EncryptionUtil.generateRandomKey();

        expect(() => base64Decode(key), returnsNormally);
      });
    });

    group('encryption format', () {
      test(
          'Given plaintext and password, When encrypting, Then produces base64 encoded ciphertext',
          () {
        const original = 'Test message';
        const password = 'testpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);

        expect(() => base64Decode(encrypted), returnsNormally);
      });

      test(
          'Given plaintext and password, When encrypting, Then includes IV in ciphertext',
          () {
        const original = 'Test message';
        const password = 'testpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decoded = base64Decode(encrypted);

        expect(decoded.length, greaterThan(16));
      });
    });
  });
}
