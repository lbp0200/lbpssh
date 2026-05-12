import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/sync_service.dart';
import 'service_providers.dart';

/// 同步状态类
class SyncStatus {
  final SyncConfig? config;
  final SyncStatusEnum status;
  final DateTime? lastSyncTime;

  const SyncStatus({
    this.config,
    this.status = SyncStatusEnum.idle,
    this.lastSyncTime,
  });

  SyncStatus copyWith({
    SyncConfig? config,
    SyncStatusEnum? status,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      config: config ?? this.config,
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          config == other.config &&
          status == other.status &&
          lastSyncTime == other.lastSyncTime;

  @override
  int get hashCode => Object.hash(config, status, lastSyncTime);
}

/// 同步通知器
class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final syncService = ref.watch(syncServiceProvider);
    return SyncStatus(
      config: syncService.getConfig(),
      status: syncService.status,
      lastSyncTime: syncService.lastSyncTime,
    );
  }

  SyncService get _service => ref.read(syncServiceProvider);

  Future<void> saveConfig(SyncConfig config) async {
    await _service.saveConfig(config);
    state = state.copyWith(config: config);
  }

  Future<void> uploadConfig() async {
    state = state.copyWith(status: SyncStatusEnum.syncing);
    try {
      await _service.uploadConfig();
      state = state.copyWith(
        status: SyncStatusEnum.idle,
        lastSyncTime: _service.lastSyncTime,
      );
    } catch (e) {
      state = state.copyWith(status: SyncStatusEnum.error);
      rethrow;
    }
  }

  Future<void> downloadConfig() async {
    state = state.copyWith(status: SyncStatusEnum.syncing);
    try {
      await _service.downloadConfig();
      state = state.copyWith(
        status: SyncStatusEnum.idle,
        lastSyncTime: _service.lastSyncTime,
        config: _service.getConfig(),
      );
    } catch (e) {
      state = state.copyWith(status: SyncStatusEnum.error);
      rethrow;
    }
  }

  Future<void> testConnection() async {
    state = state.copyWith(status: SyncStatusEnum.syncing);
    try {
      await _service.downloadConfig(skipConflictCheck: true);
      state = state.copyWith(status: SyncStatusEnum.idle);
    } catch (e) {
      state = state.copyWith(status: SyncStatusEnum.error);
      rethrow;
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
