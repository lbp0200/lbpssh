import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class EncryptionUtil {
  static const _keyLength = 32;
  static const _ivLength = 16;

  /// AES加密前缀，用于标识加密字段
  static const encryptedPrefix = r'$AES$V1$';

  static Uint8List deriveKey(String masterPassword) {
    final keyBytes = utf8.encode(masterPassword);
    if (keyBytes.length < _keyLength) {
      final padded = Uint8List(_keyLength);
      for (int i = 0; i < keyBytes.length && i < _keyLength; i++) {
        padded[i] = keyBytes[i];
      }
      return padded;
    } else {
      return Uint8List.fromList(keyBytes.take(_keyLength).toList());
    }
  }

  static String encrypt(String plainText, String masterPassword) {
    final key = deriveKey(masterPassword);
    return encryptWithKey(plainText, key);
  }

  static String decrypt(String encryptedText, String masterPassword) {
    final key = deriveKey(masterPassword);
    return decryptWithKey(encryptedText, key);
  }

  static String encryptWithKey(String plainText, Uint8List key) {
    if (plainText.isEmpty) {
      throw Exception('无法加密空字符串');
    }
    final iv = randomBytes(_ivLength);
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
    );
    final plainBytes = utf8.encode(plainText);
    final encrypted = cipher.process(Uint8List.fromList(plainBytes));
    final combined = <int>[...iv, ...encrypted];
    return base64Encode(combined);
  }

  static String decryptWithKey(String encryptedText, Uint8List key) {
    try {
      final combined = base64Decode(encryptedText);
      final iv = Uint8List.fromList(combined.take(_ivLength).toList());
      final encrypted = Uint8List.fromList(combined.skip(_ivLength).toList());
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
      final decrypted = cipher.process(encrypted);
      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('解密失败: $e');
    }
  }

  /// 检测字符串是否为加密格式
  static bool isEncrypted(String value) {
    return value.startsWith(encryptedPrefix);
  }

  /// 用密钥加密明文字段，返回带前缀的密文
  static String encryptField(String plainText, Uint8List key) {
    return '$encryptedPrefix${encryptWithKey(plainText, key)}';
  }

  /// 解密带前缀的加密字段，如果是明文则原样返回
  static String? decryptField(String? value, Uint8List key) {
    if (value == null || value.isEmpty) return value;
    if (!isEncrypted(value)) return value;
    return decryptWithKey(value.substring(encryptedPrefix.length), key);
  }

  static String generateRandomKey() {
    return base64Encode(randomBytes(32));
  }

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
