import 'package:dartssh2/dartssh2.dart';

/// dartssh2 v4 兼容层：旧设备算法回退。
///
/// v4 起默认协商集对齐现代 OpenSSH，不再主动提供 SHA-1 密钥交换
/// (`diffie-hellman-group14-sha1` / `diffie-hellman-group-exchange-sha1`)、
/// `ssh-rsa` 主机密钥签名以及 CBC 分组模式 (`aes128-cbc` / `aes256-cbc`)。
/// 仍在维护的老路由器 / NAS / 嵌入式设备若只支持这些旧算法，会直接协商失败。
///
/// 策略：首次连接始终用默认（现代）算法集；仅当失败特征明确指向算法协商
/// （见 [isAlgorithmNegotiationFailure]）时，才用 [legacyFallbackAlgorithms]
/// 重连一次。新算法排在前面，老设备按需降级，不牺牲与现代服务器的安全性。
///
/// 注意：v4 已彻底移除 3DES 等更旧的算法。连 [legacyFallbackAlgorithms]
/// 都协商失败的服务器，只能升级其 SSH 配置，本应用无法再兼容。

/// 兼容模式算法集：默认集原样前置，旧算法按强度降序追加在后。
///
/// - `diffie-hellman-group1-sha1` (1024-bit DH) 排在最后，仅作最后手段；
///   能协商上它说明对端非常老旧，连接成功后建议尽快升级对端。
const SSHAlgorithms legacyFallbackAlgorithms = SSHAlgorithms(
  kex: [
    SSHKexType.x25519Rfc,
    SSHKexType.x25519,
    SSHKexType.nistp521,
    SSHKexType.nistp384,
    SSHKexType.nistp256,
    SSHKexType.dhGexSha256,
    SSHKexType.dh14Sha256,
    // ---- 以下为兼容旧设备的回退项 ----
    SSHKexType.dhGexSha1,
    SSHKexType.dh14Sha1,
    SSHKexType.dh1Sha1,
  ],
  hostkey: [
    SSHHostkeyType.ed25519,
    SSHHostkeyType.rsaSha512,
    SSHHostkeyType.rsaSha256,
    SSHHostkeyType.ecdsa521,
    SSHHostkeyType.ecdsa384,
    SSHHostkeyType.ecdsa256,
    // ---- 以下为兼容旧设备的回退项 ----
    SSHHostkeyType.rsaSha1,
  ],
  cipher: [
    SSHCipherType.aes256gcm,
    SSHCipherType.aes128gcm,
    SSHCipherType.chacha20poly1305,
    SSHCipherType.aes256ctr,
    SSHCipherType.aes128ctr,
    // ---- 以下为兼容旧设备的回退项 ----
    SSHCipherType.aes256cbc,
    SSHCipherType.aes128cbc,
  ],
  // mac 保持默认：hmac-sha1 仍在默认集中，无需回退项。
);

/// 判断 [error] 是否为"客户端与服务器无共同算法"的协商失败。
///
/// 覆盖三种形态（详见实现注释）：
/// 1. 本端传输层抛出的 `StateError('No matching … algorithm')`，经
///    `SSHClient.authenticated` / `shell()` 冒泡时被包成
///    `SSHAuthAbortError → SSHSocketError → StateError` 三层；
/// 2. 对端主动断开（OpenSSH 如 `no matching key exchange method found`），
///    以 [SSHDisconnectError] 到达；
/// 3. 上层调用方用 `Exception('…: $e')` 包过一层、仅剩文本的形态，此时按
///    文本特征兜底匹配。
///
/// 文本匹配要求同时出现 "no matching" 与算法相关词，避免把普通报错
/// （如 "no matching host found" 之类）误判为协商失败而做无谓重连。
bool isAlgorithmNegotiationFailure(Object error) {
  Object? current = error;
  // 最多拆四层包装：SSHAuthAbortError → SSHSocketError → StateError 足够覆盖。
  for (var depth = 0; depth < 4; depth++) {
    if (current is SSHDisconnectError) {
      return _looksLikeNoMatch(current.message);
    }
    if (current is StateError) {
      return _looksLikeNoMatch(current.message);
    }
    if (current is SSHAuthAbortError) {
      current = current.reason ?? current.message;
      continue;
    }
    if (current is SSHSocketError) {
      current = current.error;
      continue;
    }
    if (current is String) {
      return _looksLikeNoMatch(current);
    }
    // 未知包装类型：不再深入拆解，用完整文本做一次兜底判断后返回。
    // （如上层 Exception('建立会话失败: …') 保留了原始错误文本。）
    return _looksLikeNoMatch(current.toString());
  }
  return _looksLikeNoMatch(current.toString());
}

/// 文本特征：含 "no matching"（大小写不敏感）且提及算法相关词。
bool _looksLikeNoMatch(String text) {
  final lower = text.toLowerCase();
  if (!lower.contains('no matching')) return false;
  const algorithmHints = [
    'algorithm',
    'cipher',
    'encryption',
    'decryption',
    'mac',
    'kex',
    'key exchange',
    'host key',
    'hostkey',
    'signature',
  ];
  return algorithmHints.any(lower.contains);
}
