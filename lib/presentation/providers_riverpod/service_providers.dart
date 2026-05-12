import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/connection_repository.dart';
import '../../domain/services/app_config_service.dart';
import '../../domain/services/import_export_service.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/services/terminal_service.dart';

/// ConnectionRepository 单例
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  final repo = ConnectionRepository();
  // 返回时不再自动 init——由调用方负责 await init()
  return repo;
});

/// TerminalService 单例
final terminalServiceProvider = Provider<TerminalService>((ref) {
  return TerminalService();
});

/// AppConfigService 单例
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService.getInstance();
});

/// SyncService 单例
final syncServiceProvider = Provider<SyncService>((ref) {
  final repo = ref.watch(connectionRepositoryProvider);
  return SyncService(repo);
});

/// ImportExportService 单例
final importExportServiceProvider = Provider<ImportExportService>((ref) {
  final repo = ref.watch(connectionRepositoryProvider);
  return ImportExportService(repo);
});
