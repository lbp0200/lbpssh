import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../utils/sentry_service.dart';

/// 在本机寻找一个可用端口（绑定 0 让系统分配）
Future<int> findAvailablePort() async {
  ServerSocket? server;
  try {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return server.port;
  } finally {
    await server?.close();
  }
}

/// 轮询探测跳板机隧道是否就绪
///
/// 轮询最多 2s（10 次 × 200ms），与旧固定等待对齐但可提前返回
Future<void> waitForTunnelReady(int port) async {
  const maxAttempts = 10;
  const interval = Duration(milliseconds: 200);
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var i = 0; i < maxAttempts; i++) {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      await socket.close();
      return;
    } catch (e, stackTrace) {
      // 端口尚未就绪是轮询期间的预期状态，静默重试
      lastError = e;
      lastStackTrace = stackTrace;
      await Future<void>.delayed(interval);
    }
  }
  // 全部尝试均未就绪：上报一次，其余交给调用方（后续连接会抛错）
  if (lastError != null) {
    debugPrint(
      '[JumpHostTunnel] port $port not ready after $maxAttempts attempts: $lastError',
    );
    unawaited(
      SentryService().captureException(lastError, stackTrace: lastStackTrace),
    );
  }
}
