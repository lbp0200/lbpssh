import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/sync_service.dart' show SyncStatusEnum, SyncConfig;
import '../providers_riverpod/sync_provider_riverpod.dart';
import '../widgets/error_dialog.dart';

/// 同步设置界面
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _gistIdController = TextEditingController();
  final _gistFilenameController = TextEditingController();
  final _syncIntervalController = TextEditingController();

  bool _autoSync = false;
  int _syncInterval = 5;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final state = ref.read(syncProvider);
    final config = state.config;

    if (config != null) {
      _gistIdController.text = config.gistId ?? '';
      _gistFilenameController.text = config.gistFilename;
      _autoSync = config.autoSync;
      _syncInterval = config.syncIntervalMinutes;
      // 不显示 token，只显示占位符
      _tokenController.text = config.accessToken != null ? '***' : '';
    } else {
      _gistFilenameController.text = AppConstants.defaultGistFilename;
    }
    _syncIntervalController.text = _syncInterval.toString();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _gistIdController.dispose();
    _gistFilenameController.dispose();
    _syncIntervalController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(syncProvider.notifier);

    // 如果 token 是占位符，保持原有 token
    String? accessToken = _tokenController.text;
    if (accessToken == '***' || accessToken == '...') {
      accessToken = ref.read(syncProvider).config?.accessToken;
    }

    final gistId = _gistIdController.text.trim();
    final config = SyncConfig(
      accessToken: accessToken,
      gistId: gistId.isNotEmpty ? gistId : null,
      gistFilename: _gistFilenameController.text.trim().isNotEmpty
          ? _gistFilenameController.text.trim()
          : AppConstants.defaultGistFilename,
      autoSync: _autoSync,
      syncIntervalMinutes: _syncInterval,
    );

    try {
      await notifier.saveConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _testConnection() async {
    final notifier = ref.read(syncProvider.notifier);
    final state = ref.read(syncProvider);
    final config = state.config;

    if (config == null || config.accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先配置并保存设置')));
      }
      return;
    }

    try {
      // 尝试下载配置来测试连接
      await notifier.testConnection();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接测试成功')));
      }
    } catch (e, stackTrace) {
      if (mounted) {
        showErrorDialog(
          context,
          title: '连接测试失败',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(LinearSpacing.spacing16),
        children: [
          // Token 认证
          Card(
            elevation: 0,
            color: LinearColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LinearRadius.card),
              side: const BorderSide(color: LinearColors.borderStandard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(LinearSpacing.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GitHub Token',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: LinearColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: LinearSpacing.spacing8),
                  const Text(
                    '请输入 GitHub Personal Access Token，'
                    '需要在 GitHub Settings → Developer settings → Personal access tokens 中创建，'
                    '并勾选 gist 权限。',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: LinearSpacing.spacing16),
                  TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'GitHub Token',
                      hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureToken = !_obscureToken;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureToken,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Token';
                      }
                      // *** 表示保留原 token，不验证
                      if (value == '***' || value == '...') {
                        return null;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: LinearSpacing.spacing8),
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(
                        'https://github.com/settings/tokens/new?scopes=gist',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('创建 Token'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LinearSpacing.spacing16),

          // Gist 配置
          Card(
            elevation: 0,
            color: LinearColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LinearRadius.card),
              side: const BorderSide(color: LinearColors.borderStandard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(LinearSpacing.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GitHub Gist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: LinearColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: LinearSpacing.spacing8),
                  const Text(
                    'Gist ID 留空时，首次上传将自动创建新的 Gist。',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: LinearSpacing.spacing16),
                  TextFormField(
                    controller: _gistIdController,
                    decoration: const InputDecoration(
                      labelText: 'Gist ID（可选）',
                      hintText: '例如：abc123def456',
                      helperText: '留空自动创建。可在 https://gist.github.com 查看。',
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                  ),
                  const SizedBox(height: LinearSpacing.spacing16),
                  TextFormField(
                    controller: _gistFilenameController,
                    decoration: const InputDecoration(
                      labelText: '文件名',
                      hintText: 'ssh_connections.json',
                      helperText: 'Gist 中存储配置的文件名。',
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入文件名';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LinearSpacing.spacing24),

          // 自动同步
          SwitchListTile(
            title: const Text('自动同步'),
            subtitle: const Text('定期自动同步配置'),
            value: _autoSync,
            onChanged: (value) {
              setState(() {
                _autoSync = value;
              });
            },
          ),

          if (_autoSync) ...[
            const SizedBox(height: LinearSpacing.spacing16),
            TextFormField(
              controller: _syncIntervalController,
              decoration: const InputDecoration(
                labelText: '同步间隔（分钟）',
                filled: true,
                fillColor: LinearColors.fillSurface,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _syncInterval = int.tryParse(value) ?? 5;
              },
            ),
          ],

          const SizedBox(height: LinearSpacing.spacing32),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testConnection,
                  child: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: LinearSpacing.spacing16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveConfig,
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),

          const SizedBox(height: LinearSpacing.spacing16),

          // 同步操作
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: syncState.status == SyncStatusEnum.syncing
                    ? null
                    : () => _uploadConfig(),
                icon: const Icon(Icons.upload),
                label: const Text('上传配置'),
              ),
              const SizedBox(height: LinearSpacing.spacing8),
              ElevatedButton.icon(
                onPressed: syncState.status == SyncStatusEnum.syncing
                    ? null
                    : () => _downloadConfig(),
                icon: const Icon(Icons.download),
                label: const Text('下载配置'),
              ),
              if (syncState.status == SyncStatusEnum.syncing)
                const Padding(
                  padding: EdgeInsets.all(LinearSpacing.spacing16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (syncState.lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.all(LinearSpacing.spacing8),
                  child: Text(
                    '最后同步时间: ${syncState.lastSyncTime}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _uploadConfig() async {
    final notifier = ref.read(syncProvider.notifier);
    final state = ref.read(syncProvider);

    if (state.config == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置同步设置')));
      return;
    }

    try {
      await notifier.uploadConfig();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已上传')));
      }
    } catch (e, stackTrace) {
      if (mounted) {
        showErrorDialog(
          context,
          title: '上传失败',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _downloadConfig() async {
    final notifier = ref.read(syncProvider.notifier);
    final state = ref.read(syncProvider);

    if (state.config == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置同步设置')));
      return;
    }

    try {
      await notifier.downloadConfig();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已下载')));
      }
    } catch (e, stackTrace) {
      if (mounted) {
        showErrorDialog(
          context,
          title: '下载失败',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
