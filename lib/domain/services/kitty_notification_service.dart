import 'dart:async';

import 'terminal_service.dart';

/// 通知点击回调
typedef NotificationCallback = void Function(String notificationId);

/// 通知进度回调
typedef NotificationProgressCallback =
    void Function(String notificationId, int progress);

/// 桌面通知服务
///
/// 通过 SSH 终端发送 OSC 99 控制序列实现桌面通知
class KittyNotificationService {
  final TerminalSession? _session;

  // 回调
  NotificationCallback? onClick;
  NotificationProgressCallback? onProgress;
  NotificationCallback? onClose;

  KittyNotificationService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 发送桌面通知
  ///
  /// [id] - 通知 ID
  /// [title] - 通知标题
  /// [body] - 通知内容
  /// [progress] - 进度 (可选，0-100)
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    int? progress,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 构建 OSC 99 序列
    // 格式: OSC 99 ; i=id ; t=title ; b=body [; p=progress]
    String cmd = '\x1b]99;i=$id;t=${_encode(title)};b=${_encode(body)}';
    if (progress != null) {
      cmd += ';p=$progress';
    }
    cmd += '\x1b\\';

    _session.writeRaw(cmd);
  }

  /// 更新通知进度
  Future<void> updateProgress({
    required String id,
    required int progress,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 99 ; i=id ; p=progress
    final cmd = '\x1b]99;i=$id;p=$progress\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 关闭通知
  Future<void> closeNotification(String id) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 99 ; i=id ; p=close
    final cmd = '\x1b]99;i=$id;p=close\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 查询通知状态
  Future<void> queryNotification(String id) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 99 ; i=id ; p=?
    final cmd = '\x1b]99;i=$id;p=?\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 处理通知响应
  /// 由外部调用，解析终端返回的通知响应
  void handleNotificationResponse(String response) {
    try {
      // 解析 OSC 99 响应
      // 格式: i=id ; p=action ; [button]
      // action: close, activate, clicked, progress

      final regex = RegExp(r'i=([^;]+);p=([^;]+)');
      final match = regex.firstMatch(response);
      if (match == null) return;

      final id = match.group(1)!;
      final action = match.group(2)!;

      switch (action) {
        case 'activate':
        case 'clicked':
          onClick?.call(id);
          break;
        case 'close':
          onClose?.call(id);
          break;
        case 'progress':
          // 提取进度
          final progressRegex = RegExp(r'p=progress;(\d+)');
          final progressMatch = progressRegex.firstMatch(response);
          if (progressMatch != null) {
            final progress = int.tryParse(progressMatch.group(1) ?? '0') ?? 0;
            onProgress?.call(id, progress);
          }
          break;
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// 编码字符串用于 OSC 序列
  String _encode(String text) {
    // 需要对特殊字符进行转义
    return text
        .replaceAll(';', '\\;')
        .replaceAll(':', '\\:')
        .replaceAll('\\', '\\\\');
  }
}
