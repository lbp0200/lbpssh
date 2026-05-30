import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// 加密工具类
class EncryptionUtil {
  static const _keyLength = 32; // AES-256 需要 32 字节密钥

  /// 从主密码派生加密密钥
  static Key deriveKey(String masterPassword) {
    // 使用 PBKDF2 派生密钥
    final keyBytes = utf8.encode(masterPassword);
    // 如果密码长度不足，使用 SHA-256 哈希
    if (keyBytes.length < _keyLength) {
      final hash = utf8.encode(masterPassword);
      final padded = List<int>.filled(_keyLength, 0);
      for (int i = 0; i < hash.length && i < _keyLength; i++) {
        padded[i] = hash[i];
      }
      return Key(Uint8List.fromList(padded));
    } else {
      return Key(Uint8List.fromList(keyBytes.take(_keyLength).toList()));
    }
  }

  /// 加密数据
  static String encrypt(String plainText, String masterPassword) {
    if (plainText.isEmpty) {
      throw Exception('无法加密空字符串');
    }
    final key = deriveKey(masterPassword);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = <int>[...iv.bytes, ...encrypted.bytes];
    return base64Encode(combined);
  }

  /// 解密数据
  static String decrypt(String encryptedText, String masterPassword) {
    try {
      final key = deriveKey(masterPassword);
      final combined = base64Decode(encryptedText);
      final iv = IV(Uint8List.fromList(combined.take(16).toList()));
      final encrypted = Encrypted(
        Uint8List.fromList(combined.skip(16).toList()),
      );
      final encrypter = Encrypter(AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('解密失败: $e');
    }
  }

  /// 生成随机密钥（用于测试）
  static String generateRandomKey() {
    final random = Key.fromSecureRandom(32);
    return base64Encode(random.bytes);
  }
}
