import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/sync_service.dart'
    show SyncStatusEnum, SyncPlatform, SyncConfig;
import '../providers/sync_provider.dart';
import '../widgets/error_dialog.dart';

/// 同步设置界面
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gistIdController = TextEditingController();
  final _gistFileNameController = TextEditingController();
  final _tokenController = TextEditingController();

  SyncPlatform _platform = SyncPlatform.gist;
  bool _autoSync = false;
  int _syncInterval = 5;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final config = provider.config;

    if (config != null) {
      _platform = config.platform;
      _gistIdController.text = config.gistId ?? '';
      _gistFileNameController.text =
          config.gistFileName ?? 'ssh_connections.json';
      _autoSync = config.autoSync;
      _syncInterval = config.syncIntervalMinutes;
      // 不显示 token，只显示占位符
      _tokenController.text = config.accessToken != null ? '***' : '';
    } else {
      _gistFileNameController.text = 'ssh_connections.json';
    }
  }

  @override
  void dispose() {
    _gistIdController.dispose();
    _gistFileNameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<SyncProvider>(context, listen: false);

    // 如果 token 是占位符，保持原有 token
    String? accessToken = _tokenController.text;
    if (accessToken == '***' || accessToken == '...') {
      accessToken = provider.config?.accessToken;
    }

    final config = SyncConfig(
      platform: _platform,
      accessToken: accessToken,
      gistId: _gistIdController.text,
      gistFileName: _gistFileNameController.text,
      autoSync: _autoSync,
      syncIntervalMinutes: _syncInterval,
    );

    try {
      await provider.saveConfig(config);

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
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final config = provider.config;

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
      await provider.testConnection();
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
    return Scaffold(
      backgroundColor: LinearColors.background,
      appBar: AppBar(
        title: const Text('同步设置'),
        backgroundColor: LinearColors.panel,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LinearColors.textPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(LinearSpacing.spacing16),
          children: [
            // 平台选择
            DropdownButtonFormField<SyncPlatform>(
              initialValue: _platform,
              decoration: InputDecoration(
                labelText: '同步平台',
                filled: true,
                fillColor: LinearColors.fillSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: SyncPlatform.gist,
                  child: Text('GitHub Gist'),
                ),
                DropdownMenuItem(
                  value: SyncPlatform.giteeGist,
                  child: Text('Gitee Gist'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                });
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),

            // Token 认证
            Card(
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
                    Text(
                      _platform == SyncPlatform.giteeGist
                          ? 'Gitee Token'
                          : 'GitHub Token',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LinearColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: LinearSpacing.spacing8),
                    Text(
                      _platform == SyncPlatform.giteeGist
                          ? '请输入 Gitee Personal Access Token，'
                                '需要在 Gitee 设置 → 安全设置 → 个人访问令牌 中创建。'
                          : '请输入 GitHub Personal Access Token，'
                                '需要在 GitHub Settings → Developer settings → Personal access tokens 中创建，'
                                '并勾选 gist 权限。',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: LinearSpacing.spacing16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: _platform == SyncPlatform.giteeGist
                            ? 'Gitee Token'
                            : 'GitHub Token',
                        hintText: _platform == SyncPlatform.giteeGist
                            ? 'xxxxxxxxxxxxxxxxxxxx'
                            : 'ghp_xxxxxxxxxxxxxxxxxxxx',
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
                        final url = _platform == SyncPlatform.giteeGist
                            ? Uri.parse(
                                'https://gitee.com/profile/personal_access_tokens',
                              )
                            : Uri.parse(
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
            TextFormField(
              controller: _gistIdController,
              decoration: InputDecoration(
                labelText: _platform == SyncPlatform.giteeGist
                    ? 'Gitee Gist ID 或 URL'
                    : 'GitHub Gist ID 或 URL',
                hintText: _platform == SyncPlatform.giteeGist
                    ? '例如：mluri6dyosvgzthfb43jw39'
                    : '例如：abc123def456',
                helperText: '留空点击上传将创建新 Gist，有值则同步现有 Gist。',
                filled: true,
                fillColor: LinearColors.fillSurface,
              ),
              onChanged: (value) {
                // 如果输入的是 URL，提取 Gist ID
                if (value.contains('gist.github.com')) {
                  final uri = Uri.tryParse(value);
                  if (uri != null) {
                    final segments = uri.pathSegments;
                    if (segments.isNotEmpty) {
                      final gistId = segments.last;
                      _gistIdController.text = gistId;
                    }
                  }
                } else if (value.contains('gitee.com/gist')) {
                  final uri = Uri.tryParse(value);
                  if (uri != null) {
                    final segments = uri.pathSegments;
                    if (segments.isNotEmpty) {
                      final gistId = segments.last;
                      _gistIdController.text = gistId;
                    }
                  }
                }
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            TextFormField(
              controller: _gistFileNameController,
              decoration: InputDecoration(
                labelText: 'Gist 文件名',
                hintText: 'ssh_connections.json',
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
                initialValue: _syncInterval.toString(),
                decoration: InputDecoration(
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
            Consumer<SyncProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: provider.status == SyncStatusEnum.syncing
                          ? null
                          : () => _uploadConfig(provider),
                      icon: const Icon(Icons.upload),
                      label: const Text('上传配置'),
                    ),
                    const SizedBox(height: LinearSpacing.spacing8),
                    ElevatedButton.icon(
                      onPressed: provider.status == SyncStatusEnum.syncing
                          ? null
                          : () => _downloadConfig(provider),
                      icon: const Icon(Icons.download),
                      label: const Text('下载配置'),
                    ),
                    if (provider.status == SyncStatusEnum.syncing)
                      const Padding(
                        padding: EdgeInsets.all(LinearSpacing.spacing16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (provider.lastSyncTime != null)
                      Padding(
                        padding: const EdgeInsets.all(LinearSpacing.spacing8),
                        child: Text(
                          '最后同步时间: ${provider.lastSyncTime}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadConfig(SyncProvider provider) async {
    if (provider.config == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置同步设置')));
      return;
    }

    try {
      await provider.uploadConfig();
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

  Future<void> _downloadConfig(SyncProvider provider) async {
    if (provider.config == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置同步设置')));
      return;
    }

    try {
      await provider.downloadConfig();
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
