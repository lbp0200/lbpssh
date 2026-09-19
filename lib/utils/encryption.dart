import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

class EncryptionUtil {
  static const _keyLength = 32;
  static const _ivLength = 16;

  /// AES加密前缀，用于标识加密字段
  static const encryptedPrefix = r'$AES$V1$';

  /// 将主密码派生为 32 字节 AES 密钥
  ///
  /// 旧实现为零填充/截断，熵损失严重且易受字典攻击。
  /// 现改用 SHA-256 哈希派生，保留完整密码熵且固定 32 字节。
  /// 解密时为兼容旧数据会回退到 legacy 零填充方式。
  static Uint8List deriveKey(String masterPassword) {
    final digest = SHA256Digest();
    final pwdBytes = Uint8List.fromList(utf8.encode(masterPassword));
    return digest.process(pwdBytes);
  }

  /// 旧版零填充派生（仅用于解密回退，兼容历史数据）
  static Uint8List _deriveKeyLegacy(String masterPassword) {
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
    try {
      final key = deriveKey(masterPassword);
      return decryptWithKey(encryptedText, key);
    } catch (_) {
      // 兼容旧版零填充加密的数据（新密钥解密失败是预期回退路径，不上报）
      final legacyKey = _deriveKeyLegacy(masterPassword);
      try {
        return decryptWithKey(encryptedText, legacyKey);
      } catch (_) {
        // 两种密钥均失败：主密码错误或数据损坏。异常详情可能含密文片段，
        // 只记录通用信息，不带上报与敏感数据。
        debugPrint(
          '[Encryption] decrypt failed: invalid password or corrupted data',
        );
        rethrow;
      }
    }
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
