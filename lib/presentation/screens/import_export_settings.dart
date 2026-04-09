import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ssh_connection.dart';
import '../../../domain/services/import_export_service.dart';
import '../providers/import_export_provider.dart';

/// 导入导出设置界面
class ImportExportSettingsScreen extends StatefulWidget {
  const ImportExportSettingsScreen({super.key});

  @override
  State<ImportExportSettingsScreen> createState() =>
      _ImportExportSettingsScreenState();
}

class _ImportExportSettingsScreenState
    extends State<ImportExportSettingsScreen> {
  ImportExportProvider? _provider;
  List<SshConnection> _importedConnections = [];
  bool _showImportPreview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= Provider.of<ImportExportProvider>(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入导出配置'),
        actions: [
          if (_showImportPreview)
            IconButton(
              onPressed: () => _clearImportPreview(),
              icon: const Icon(Icons.clear),
              tooltip: '清除预览',
            ),
        ],
      ),
      body: Consumer<ImportExportProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(LinearSpacing.spacing16),
            children: [
              _buildStatsCard(),
              const SizedBox(height: LinearSpacing.spacing24),
              _buildExportSection(provider),
              const SizedBox(height: LinearSpacing.spacing24),
              _buildImportSection(provider),
              const SizedBox(height: LinearSpacing.spacing24),
              if (_showImportPreview && _importedConnections.isNotEmpty)
                _buildImportPreview(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _provider!.getExportStats();

    return Card(
      elevation: 0,
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: LinearSpacing.spacing8),
                Text(
                  '当前SSH连接统计',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总连接数',
                    '${stats['totalConnections']}',
                    Icons.link,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '密码认证',
                    '${stats['passwordAuth']}',
                    Icons.password,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '密钥认证',
                    '${stats['keyAuth']}',
                    Icons.key,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing8),
            if ((stats['jumpHostConnections'] as int? ?? 0) > 0)
              Row(
                children: [
                  _buildStatItem(
                    '跳板机连接',
                    '${stats['jumpHostConnections']}',
                    Icons.router,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                  if (stats['lastUpdated'] != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '最后更新',
                            style: TextStyle(fontSize: 12, color: LinearColors.textSecondary),
                          ),
                          Text(
                            '${stats['lastUpdated']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Icon(icon, color: LinearColors.accentInteractive),
        const SizedBox(height: LinearSpacing.spacing4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: LinearColors.textQuaternary)),
      ],
    );
  }

  Widget _buildExportSection(ImportExportProvider provider) {
    return Card(
      elevation: 0,
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_upload),
                SizedBox(width: LinearSpacing.spacing8),
                Text(
                  '导出配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing8),
            const Text(
              '将SSH连接配置导出到本地文件，包含所有连接信息（密码、私钥等敏感信息）。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.status == ImportExportStatus.exporting
                    ? null
                    : () => _exportConfiguration(provider),
                icon: provider.status == ImportExportStatus.exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload),
                label: Text(
                  provider.status == ImportExportStatus.exporting
                      ? '导出中...'
                      : '导出配置',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(ImportExportProvider provider) {
    return Card(
      elevation: 0,
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_download),
                SizedBox(width: LinearSpacing.spacing8),
                Text(
                  '导入配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing8),
            const Text(
              '从之前导出的配置文件导入SSH连接配置。支持覆盖现有连接或添加前缀避免冲突。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.status == ImportExportStatus.importing
                    ? null
                    : () => _importConfiguration(provider),
                icon: provider.status == ImportExportStatus.importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download),
                label: Text(
                  provider.status == ImportExportStatus.importing
                      ? '导入中...'
                      : '导入配置',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportPreview() {
    return Card(
      elevation: 0,
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.preview),
                SizedBox(width: LinearSpacing.spacing8),
                Text(
                  '导入预览',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing8),
            Text(
              '发现 ${_importedConnections.length} 个连接配置：',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: LinearSpacing.spacing12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _importedConnections.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final connection = _importedConnections[index];
                return ListTile(
                  leading: Icon(
                    _getAuthTypeIcon(connection.authType),
                    color: LinearColors.accentInteractive,
                  ),
                  title: Text(connection.name),
                  subtitle: Text(
                    '${connection.username}@${connection.host}:${connection.port}',
                  ),
                  trailing: connection.jumpHost != null
                      ? const Icon(Icons.router, size: 16, color: LinearColors.warning)
                      : null,
                );
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showImportDialog(false),
                    child: const Text('添加前缀'),
                  ),
                ),
                const SizedBox(width: LinearSpacing.spacing8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showImportDialog(true),
                    child: const Text('覆盖现有'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAuthTypeIcon(AuthType authType) {
    switch (authType) {
      case AuthType.password:
        return Icons.password;
      case AuthType.key:
        return Icons.key;
      case AuthType.keyWithPassword:
        return Icons.vpn_key;
      case AuthType.sshConfig:
        return Icons.settings;
    }
  }

  Future<void> _exportConfiguration(ImportExportProvider provider) async {
    try {
      final file = await provider.exportToLocalFile();
      if (file != null && mounted) {
        final summary = provider.generateExportSummary();
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导出成功'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(summary),
                  const SizedBox(height: LinearSpacing.spacing16),
                  const Text(
                    '文件保存位置:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(file.path),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: LinearColors.error),
        );
      }
    }
  }

  Future<void> _importConfiguration(ImportExportProvider provider) async {
    try {
      final connections = await provider.importFromLocalFile();

      if (connections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('文件中没有有效的连接配置')));
        }
        return;
      }

      setState(() {
        _importedConnections = connections;
        _showImportPreview = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: LinearColors.error),
        );
      }
    }
  }

  void _showImportDialog(bool overwrite) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(overwrite ? '确认覆盖' : '确认添加'),
        content: Text(
          overwrite ? '这将覆盖现有的同名连接，确定继续吗？' : '将为导入的连接添加前缀避免冲突，确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performImport(overwrite);
            },
            child: Text(overwrite ? '覆盖' : '添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _performImport(bool overwrite) async {
    try {
      await _provider!.importAndSaveConnections(
        _importedConnections,
        overwrite: overwrite,
        addPrefix: !overwrite,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(overwrite ? '连接已覆盖' : '连接已添加'),
            backgroundColor: LinearColors.success,
          ),
        );

        setState(() {
          _showImportPreview = false;
          _importedConnections.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: LinearColors.error),
        );
      }
    }
  }

  void _clearImportPreview() {
    setState(() {
      _showImportPreview = false;
      _importedConnections.clear();
    });
    _provider!.resetStatus();
  }
}
