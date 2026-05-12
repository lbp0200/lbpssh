import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/import_export_service.dart';
import 'service_providers.dart';

/// 导入导出状态
class ImportExportStatusData {
  final ImportExportStatus status;
  final String? lastError;

  const ImportExportStatusData({
    this.status = ImportExportStatus.idle,
    this.lastError,
  });

  ImportExportStatusData copyWith({
    ImportExportStatus? status,
    String? lastError,
  }) {
    return ImportExportStatusData(
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportExportStatusData &&
          status == other.status &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(status, lastError);
}

/// 导入导出通知器
class ImportExportNotifier extends Notifier<ImportExportStatusData> {
  @override
  ImportExportStatusData build() => const ImportExportStatusData();

  ImportExportService get _service => ref.read(importExportServiceProvider);

  /// 导出到本地文件
  Future<File?> exportToLocalFile() async {
    try {
      final file = await _service.exportToLocalFile();
      state = const ImportExportStatusData(status: ImportExportStatus.success);
      return file;
    } catch (e) {
      state = const ImportExportStatusData(
        status: ImportExportStatus.error,
      );
      rethrow;
    }
  }

  /// 从本地文件导入
  Future<List<SshConnection>> importFromLocalFile() async {
    try {
      final connections = await _service.importFromLocalFile();
      state = const ImportExportStatusData(status: ImportExportStatus.success);
      return connections;
    } catch (e) {
      state = const ImportExportStatusData(
        status: ImportExportStatus.error,
      );
      rethrow;
    }
  }

  /// 导入并保存连接
  Future<void> importAndSaveConnections(
    List<SshConnection> connections, {
    bool overwrite = false,
    bool addPrefix = true,
  }) async {
    try {
      await _service.importAndSaveConnections(
        connections,
        overwrite: overwrite,
        addPrefix: addPrefix,
      );
      state = const ImportExportStatusData(status: ImportExportStatus.success);
    } catch (e) {
      state = const ImportExportStatusData(
        status: ImportExportStatus.error,
      );
      rethrow;
    }
  }

  /// 获取导出统计信息
  Map<String, dynamic> getExportStats() => _service.getExportStats();

  /// 生成导出摘要
  String generateExportSummary() => _service.generateExportSummary();

  /// 重置状态
  void resetStatus() {
    _service.resetStatus();
    state = const ImportExportStatusData();
  }
}

final importExportProvider =
    NotifierProvider<ImportExportNotifier, ImportExportStatusData>(
      ImportExportNotifier.new,
    );
