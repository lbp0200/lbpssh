import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/kitty_file_transfer_service.dart';
import 'terminal_provider_riverpod.dart';

/// SFTP 标签页数据
class SftpTab {
  final String id;
  final SshConnection connection;
  final KittyFileTransferService service;
  String currentPath;

  SftpTab({
    required this.id,
    required this.connection,
    required this.service,
    required this.currentPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpTab && id == other.id && currentPath == other.currentPath;

  @override
  int get hashCode => Object.hash(id, currentPath);
}

/// SFTP 标签页状态
class SftpState {
  final List<SftpTab> tabs;

  const SftpState({this.tabs = const []});

  SftpState copyWith({List<SftpTab>? tabs}) =>
      SftpState(tabs: tabs ?? this.tabs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpState && listEquals(tabs, other.tabs);

  @override
  int get hashCode => Object.hashAll(tabs);
}

/// SFTP 通知器
class SftpNotifier extends Notifier<SftpState> {
  @override
  SftpState build() => const SftpState();

  /// 打开 SFTP 标签页
  Future<SftpTab> openTab(SshConnection connection, {String? password}) async {
    final tabId = '${connection.id}_${DateTime.now().millisecondsSinceEpoch}';

    final terminalNotifier = ref.read(terminalProvider.notifier);
    final session = terminalNotifier.getSession(connection.id);
    if (session == null) {
      throw Exception('终端会话不存在');
    }

    final initialPath = session.workingDirectory.isNotEmpty
        ? session.workingDirectory
        : '/';

    final transferService = KittyFileTransferService(
      session: session,
      initialPath: initialPath,
    );

    final tab = SftpTab(
      id: tabId,
      connection: connection,
      service: transferService,
      currentPath: initialPath,
    );

    state = state.copyWith(tabs: [...state.tabs, tab]);
    return tab;
  }

  /// 关闭标签页
  Future<void> closeTab(String tabId) async {
    state = state.copyWith(
      tabs: state.tabs.where((t) => t.id != tabId).toList(),
    );
  }

  /// 获取标签页
  SftpTab? getTab(String tabId) {
    return state.tabs.where((t) => t.id == tabId).firstOrNull;
  }
}

final sftpProvider = NotifierProvider<SftpNotifier, SftpState>(
  SftpNotifier.new,
);
