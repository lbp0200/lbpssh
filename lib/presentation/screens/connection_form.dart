import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_connection.dart';
import '../../domain/services/ssh_config_service.dart';
import '../providers/connection_provider.dart';
import '../widgets/error_dialog.dart';

/// 连接配置表单界面
class ConnectionFormScreen extends StatefulWidget {
  final SshConnection? connection;

  const ConnectionFormScreen({super.key, this.connection});

  @override
  State<ConnectionFormScreen> createState() => _ConnectionFormScreenState();
}

class _ConnectionFormScreenState extends State<ConnectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _keyPathController = TextEditingController();
  final _keyPassphraseController = TextEditingController();
  final _notesController = TextEditingController();

  // 私钥内容存储
  String? _privateKeyContent;

  AuthType _authType = AuthType.password;
  bool _obscurePassword = true;
  bool _obscureKeyPassphrase = true;

  // 跳板机配置
  bool _useJumpHost = false;
  final _jumpHostController = TextEditingController();
  final _jumpPortController = TextEditingController();
  final _jumpUsernameController = TextEditingController();
  final _jumpPasswordController = TextEditingController();
  AuthType _jumpAuthType = AuthType.password;

  // SOCKS5 代理配置
  bool _useSocks5Proxy = false;
  final _socks5HostController = TextEditingController();
  final _socks5PortController = TextEditingController();
  final _socks5UsernameController = TextEditingController();
  final _socks5PasswordController = TextEditingController();

  // SSH Config 主机选择
  List<SshConfigEntry> _sshConfigEntries = [];
  String? _selectedSshConfigHost;

  @override
  void initState() {
    super.initState();
    // 加载 SSH config 文件中的主机列表
    _loadSshConfigEntries();
    if (widget.connection != null) {
      _loadConnection(widget.connection!);
    } else {
      _portController.text = '22';
      _jumpPortController.text = '22';
    }
  }

  void _loadSshConfigEntries() {
    _sshConfigEntries = SshConfigService.readConfigFile();
  }

  void _loadConnection(SshConnection connection) {
    _nameController.text = connection.name;
    _hostController.text = connection.host;
    _portController.text = connection.port.toString();
    _usernameController.text = connection.username;
    _authType = connection.authType;
    _keyPathController.text = connection.privateKeyPath ?? '';
    _privateKeyContent = connection.privateKeyContent;
    _notesController.text = connection.notes ?? '';

    if (connection.jumpHost != null) {
      _useJumpHost = true;
      _jumpHostController.text = connection.jumpHost!.host;
      _jumpPortController.text = connection.jumpHost!.port.toString();
      _jumpUsernameController.text = connection.jumpHost!.username;
      _jumpAuthType = connection.jumpHost!.authType;
    }

    // 加载 SOCKS5 代理配置
    if (connection.socks5Proxy != null) {
      _useSocks5Proxy = true;
      _socks5HostController.text = connection.socks5Proxy!.host;
      _socks5PortController.text = connection.socks5Proxy!.port.toString();
      _socks5UsernameController.text = connection.socks5Proxy!.username ?? '';
      _socks5PasswordController.text = connection.socks5Proxy!.password ?? '';
    }

    // 加载 SSH Config 设置
    if (connection.sshConfigHost != null) {
      _selectedSshConfigHost = connection.sshConfigHost;
    }
  }

  // 选择私钥文件
  Future<void> _pickPrivateKeyFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // 检查文件是否存在且可读
        final file = File(filePath);
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('文件不存在或无法访问')));
          return;
        }

        // 读取文件内容
        String fileContent;
        try {
          fileContent = await file.readAsString();
        } catch (e, stackTrace) {
          if (!mounted) return;
          showErrorDialog(
            context,
            title: '读取文件失败',
            error: e,
            stackTrace: stackTrace,
          );
          return;
        }

        // 验证私钥格式
        if (!_isValidPrivateKey(fileContent)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '选择的文件不是有效的私钥格式。\n'
                '请确保选择的是标准的SSH私钥文件，\n'
                '例如 ~/.ssh/id_rsa、~/.ssh/id_ed25519 等',
              ),
            ),
          );
          return;
        }

        setState(() {
          _keyPathController.text = filePath;
          _privateKeyContent = fileContent;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('私钥文件已加载: ${filePath.split('/').last}')),
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      showErrorDialog(
        context,
        title: '选择文件失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 从路径加载私钥文件
  Future<void> _loadPrivateKeyFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在或无法访问')),
      );
      return;
    }

    String fileContent;
    try {
      fileContent = await file.readAsString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取文件失败: $e')),
      );
      return;
    }

    if (!_isValidPrivateKey(fileContent)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '文件不是有效的私钥格式。\n'
            '请确保选择的是标准的SSH私钥文件',
          ),
        ),
      );
      return;
    }

    setState(() {
      _keyPathController.text = filePath;
      _privateKeyContent = fileContent;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('私钥文件已加载: ${filePath.split('/').last}')),
    );
  }

  // 验证私钥格式
  bool _isValidPrivateKey(String content) {
    final trimmed = content.trim();

    // 支持多种私钥格式
    // 1. PEM格式 (-----BEGIN/END PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('PRIVATE KEY-----') &&
        trimmed.endsWith('-----END PRIVATE KEY-----')) {
      return true;
    }

    // 2. OpenSSH格式 (-----BEGIN/END OPENSSH PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('OPENSSH PRIVATE KEY-----') &&
        trimmed.endsWith('-----END OPENSSH PRIVATE KEY-----')) {
      return true;
    }

    // 3. RSA格式 (-----BEGIN/END RSA PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('RSA PRIVATE KEY-----') &&
        trimmed.endsWith('-----END RSA PRIVATE KEY-----')) {
      return true;
    }

    // 4. DSA格式 (-----BEGIN/END DSA PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('DSA PRIVATE KEY-----') &&
        trimmed.endsWith('-----END DSA PRIVATE KEY-----')) {
      return true;
    }

    // 5. EC格式 (-----BEGIN/END EC PRIVATE KEY-----)
    if (trimmed.startsWith('-----BEGIN') &&
        trimmed.contains('EC PRIVATE KEY-----') &&
        trimmed.endsWith('-----END EC PRIVATE KEY-----')) {
      return true;
    }

    return false;
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ConnectionProvider>(context, listen: false);

    try {
      // 创建跳板机配置
      JumpHostConfig? jumpHost;
      if (_useJumpHost) {
        jumpHost = JumpHostConfig(
          host: _jumpHostController.text,
          port: int.tryParse(_jumpPortController.text) ?? 22,
          username: _jumpUsernameController.text,
          authType: _jumpAuthType,
          password: _jumpPasswordController.text.isNotEmpty
              ? _jumpPasswordController.text
              : null,
        );
      }

      // 创建 SOCKS5 代理配置
      Socks5ProxyConfig? socks5Proxy;
      if (_useSocks5Proxy) {
        socks5Proxy = Socks5ProxyConfig(
          host: _socks5HostController.text,
          port: int.tryParse(_socks5PortController.text) ?? 1080,
          username: _socks5UsernameController.text.isNotEmpty
              ? _socks5UsernameController.text
              : null,
          password: _socks5PasswordController.text.isNotEmpty
              ? _socks5PasswordController.text
              : null,
        );
      }

      // 创建连接配置
      final connection = SshConnection(
        id: widget.connection?.id ?? const Uuid().v4(),
        name: _nameController.text,
        host: _hostController.text,
        port: int.tryParse(_portController.text) ?? 22,
        username: _usernameController.text,
        authType: _authType,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        privateKeyPath: _keyPathController.text.isNotEmpty
            ? _keyPathController.text
            : null,
        privateKeyContent: _privateKeyContent,
        keyPassphrase: _keyPassphraseController.text.isNotEmpty
            ? _keyPassphraseController.text
            : null,
        jumpHost: jumpHost,
        socks5Proxy: socks5Proxy,
        sshConfigHost: _authType == AuthType.sshConfig ? _selectedSshConfigHost : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: widget.connection?.createdAt,
        updatedAt: DateTime.now(),
        version: widget.connection?.version ?? 1,
      );

      if (widget.connection != null) {
        await provider.updateConnection(connection);
      } else {
        await provider.addConnection(connection);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.connection != null ? '连接已更新' : '连接已添加')),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      showErrorDialog(
        context,
        title: '保存失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.connection != null ? '编辑连接' : '添加连接')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(LinearSpacing.spacing16),
          children: [
            // 基本信息
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '连接名称',
                labelStyle: const TextStyle(color: LinearColors.textSecondary),
                hintText: '例如：生产服务器',
                hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                filled: true,
                fillColor: LinearColors.fillSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入连接名称';
                }
                return null;
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: '主机地址',
                      labelStyle: const TextStyle(color: LinearColors.textSecondary),
                      hintText: '例如：192.168.1.100',
                      hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: BorderSide(color: LinearColors.borderStandard),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: BorderSide(color: LinearColors.borderStandard),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主机地址';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: LinearSpacing.spacing16),
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: '端口',
                      labelStyle: const TextStyle(color: LinearColors.textSecondary),
                      hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                      filled: true,
                      fillColor: LinearColors.fillSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: BorderSide(color: LinearColors.borderStandard),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: BorderSide(color: LinearColors.borderStandard),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LinearRadius.standard),
                        borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return '端口号无效';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: LinearSpacing.spacing16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '用户名',
                labelStyle: const TextStyle(color: LinearColors.textSecondary),
                hintText: '例如：root',
                hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                filled: true,
                fillColor: LinearColors.fillSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),

            // 认证方式
            DropdownButtonFormField<AuthType>(
              initialValue: _authType,
              decoration: InputDecoration(
                labelText: '认证方式',
                labelStyle: const TextStyle(color: LinearColors.textSecondary),
                hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                filled: true,
                fillColor: LinearColors.fillSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                ),
              ),
              items: [
                const DropdownMenuItem(value: AuthType.password, child: Text('密码认证')),
                const DropdownMenuItem(value: AuthType.key, child: Text('密钥认证')),
                const DropdownMenuItem(
                  value: AuthType.keyWithPassword,
                  child: Text('密钥+密码认证'),
                ),
                DropdownMenuItem(
                  value: AuthType.sshConfig,
                  child: Row(
                    children: [
                      const Text('SSH Config'),
                      const SizedBox(width: LinearSpacing.spacing8),
                      if (_sshConfigEntries.isEmpty)
                        const Tooltip(
                          message: '未找到 ~/.ssh/config 文件',
                          child: Icon(
                            Icons.info_outline,
                            color: LinearColors.textQuaternary,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _authType = value!;
                });
              },
            ),
            const SizedBox(height: LinearSpacing.spacing16),

            // 密码输入（如果是密码认证）
            if (_authType == AuthType.password)
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '密码',
                  labelStyle: const TextStyle(color: LinearColors.textSecondary),
                  hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                  filled: true,
                  fillColor: LinearColors.fillSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),

            // 私钥文件（如果是密钥认证）
            if (_authType == AuthType.key ||
                _authType == AuthType.keyWithPassword) ...[
              const SizedBox(height: LinearSpacing.spacing16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('私钥文件'),
                  const SizedBox(height: LinearSpacing.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _keyPathController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(color: LinearColors.textSecondary),
                            hintText: _privateKeyContent != null
                                ? '已选择私钥文件'
                                : '点击右侧按钮选择私钥文件',
                            hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                            filled: true,
                            fillColor: LinearColors.fillSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LinearRadius.standard),
                              borderSide: BorderSide(color: LinearColors.borderStandard),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LinearRadius.standard),
                              borderSide: BorderSide(color: LinearColors.borderStandard),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LinearRadius.standard),
                              borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                            ),
                            suffixIcon: _privateKeyContent != null
                                ? const Icon(
                                    Icons.check_circle,
                                    color: LinearColors.success,
                                  )
                                : null,
                          ),
                          validator: (value) {
                            if (_authType == AuthType.key ||
                                _authType == AuthType.keyWithPassword) {
                              if (_privateKeyContent == null) {
                                return '请选择私钥文件';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: LinearSpacing.spacing8),
                      ElevatedButton.icon(
                        onPressed: _pickPrivateKeyFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择文件'),
                      ),
                      const SizedBox(width: LinearSpacing.spacing8),
                      Tooltip(
                        message: '由于 macOS 沙箱限制，无法选择 ~/.ssh 目录中的文件，请手动输入路径',
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // 提示用户手动输入路径
                            final path = await showDialog<String>(
                              context: context,
                              builder: (context) => _ManualPathDialog(
                                initialPath: _keyPathController.text,
                              ),
                            );
                            if (path != null && mounted) {
                              setState(() {
                                _keyPathController.text = path;
                              });
                              await _loadPrivateKeyFromPath(path);
                            }
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('输入路径'),
                        ),
                      ),
                    ],
                  ),
                  if (_privateKeyContent != null) ...[
                    const SizedBox(height: LinearSpacing.spacing4),
                    Text(
                      '私钥已加载: ${_keyPathController.text.isNotEmpty ? _keyPathController.text.split('/').last : "未知文件"}',
                      style: const TextStyle(
                        color: LinearColors.success,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // 密钥密码（如果是密钥+密码认证）
            if (_authType == AuthType.keyWithPassword) ...[
              const SizedBox(height: LinearSpacing.spacing16),
              TextFormField(
                controller: _keyPassphraseController,
                decoration: InputDecoration(
                  labelText: '密钥密码',
                  labelStyle: const TextStyle(color: LinearColors.textSecondary),
                  hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                  filled: true,
                  fillColor: LinearColors.fillSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKeyPassphrase
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureKeyPassphrase = !_obscureKeyPassphrase;
                      });
                    },
                  ),
                ),
                obscureText: _obscureKeyPassphrase,
              ),
            ],

            // SSH Config 主机选择（如果是 sshConfig 认证）
            if (_authType == AuthType.sshConfig) ...[
              const SizedBox(height: LinearSpacing.spacing16),
              if (_sshConfigEntries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(LinearSpacing.spacing12),
                  decoration: BoxDecoration(
                    color: LinearColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(LinearRadius.card),
                    border: Border.all(color: LinearColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: LinearColors.warning),
                      SizedBox(width: LinearSpacing.spacing12),
                      Expanded(
                        child: Text(
                          '未找到 ~/.ssh/config 文件。请确保文件存在且包含主机配置。',
                          style: TextStyle(color: LinearColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_sshConfigEntries.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSshConfigHost,
                  decoration: InputDecoration(
                    labelText: '选择 SSH Config 主机',
                    labelStyle: const TextStyle(color: LinearColors.textSecondary),
                    hintText: '从 ~/.ssh/config 中选择',
                    hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                    filled: true,
                    fillColor: LinearColors.fillSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: BorderSide(color: LinearColors.borderStandard),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: BorderSide(color: LinearColors.borderStandard),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- 选择主机 --'),
                    ),
                    ..._sshConfigEntries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.hostName,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.hostName),
                            if (entry.actualHost != null || entry.user != null)
                              Text(
                                '${entry.actualHost ?? entry.hostName}${entry.user != null ? ' (@${entry.user})' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: LinearColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSshConfigHost = value;
                      // 自动填充主机信息
                      if (value != null) {
                        final entry = _sshConfigEntries
                            .firstWhere((e) => e.hostName == value);
                        _hostController.text = entry.getConnectHost();
                        if (entry.port != null) {
                          _portController.text = entry.port.toString();
                        }
                        if (entry.user != null) {
                          _usernameController.text = entry.user!;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: LinearSpacing.spacing8),
                const Text(
                  '将使用 ~/.ssh/config 中定义的主机配置（主机名、端口、用户、身份文件等）。',
                  style: TextStyle(
                    color: LinearColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: LinearSpacing.spacing8),
              ElevatedButton.icon(
                onPressed: () {
                  _loadSshConfigEntries();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('刷新列表'),
              ),
            ],

            const SizedBox(height: LinearSpacing.spacing24),

            // 跳板机配置
            CheckboxListTile(
              title: const Text('使用跳板机', style: TextStyle(color: LinearColors.textPrimary)),
              value: _useJumpHost,
              onChanged: (value) {
                setState(() {
                  _useJumpHost = value ?? false;
                });
              },
            ),

            if (_useJumpHost) ...[
              const SizedBox(height: LinearSpacing.spacing16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _jumpHostController,
                      decoration: InputDecoration(
                        labelText: '跳板机地址',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: LinearSpacing.spacing16),
                  Expanded(
                    child: TextFormField(
                      controller: _jumpPortController,
                      decoration: InputDecoration(
                        labelText: '端口',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LinearSpacing.spacing16),
              TextFormField(
                controller: _jumpUsernameController,
                decoration: InputDecoration(
                  labelText: '跳板机用户名',
                  labelStyle: const TextStyle(color: LinearColors.textSecondary),
                  hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                  filled: true,
                  fillColor: LinearColors.fillSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: LinearSpacing.spacing16),
              DropdownButtonFormField<AuthType>(
                initialValue: _jumpAuthType,
                decoration: InputDecoration(
                  labelText: '跳板机认证方式',
                  labelStyle: const TextStyle(color: LinearColors.textSecondary),
                  hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                  filled: true,
                  fillColor: LinearColors.fillSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: BorderSide(color: LinearColors.borderStandard),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadius.standard),
                    borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AuthType.password,
                    child: Text('密码认证'),
                  ),
                  DropdownMenuItem(value: AuthType.key, child: Text('密钥认证')),
                ],
                onChanged: (value) {
                  setState(() {
                    _jumpAuthType = value!;
                  });
                },
              ),
              if (_jumpAuthType == AuthType.password) ...[
                const SizedBox(height: LinearSpacing.spacing16),
                TextFormField(
                  controller: _jumpPasswordController,
                  decoration: InputDecoration(
                    labelText: '跳板机密码',
                    labelStyle: const TextStyle(color: LinearColors.textSecondary),
                    hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                    filled: true,
                    fillColor: LinearColors.fillSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: BorderSide(color: LinearColors.borderStandard),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: BorderSide(color: LinearColors.borderStandard),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LinearRadius.standard),
                      borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                    ),
                  ),
                  obscureText: true,
                ),
              ],
            ],

            const SizedBox(height: LinearSpacing.spacing24),

            // SOCKS5 代理配置
            CheckboxListTile(
              title: const Text('使用 SOCKS5 代理', style: TextStyle(color: LinearColors.textPrimary)),
              value: _useSocks5Proxy,
              onChanged: (value) {
                setState(() {
                  _useSocks5Proxy = value ?? false;
                });
              },
            ),

            if (_useSocks5Proxy) ...[
              const SizedBox(height: LinearSpacing.spacing16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _socks5HostController,
                      decoration: InputDecoration(
                        labelText: '代理主机',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintText: '例如：127.0.0.1',
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (_useSocks5Proxy &&
                            (value == null || value.isEmpty)) {
                          return '请输入代理主机';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: LinearSpacing.spacing16),
                  Expanded(
                    child: TextFormField(
                      controller: _socks5PortController,
                      decoration: InputDecoration(
                        labelText: '端口',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintText: '默认 1080',
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_useSocks5Proxy &&
                            (value == null || value.isEmpty)) {
                          return '请输入端口';
                        }
                        final port = int.tryParse(value ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '端口号无效';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LinearSpacing.spacing16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _socks5UsernameController,
                      decoration: InputDecoration(
                        labelText: '用户名',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintText: '可选',
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: LinearSpacing.spacing16),
                  Expanded(
                    child: TextFormField(
                      controller: _socks5PasswordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        labelStyle: const TextStyle(color: LinearColors.textSecondary),
                        hintText: '可选',
                        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                        filled: true,
                        fillColor: LinearColors.fillSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: BorderSide(color: LinearColors.borderStandard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LinearRadius.standard),
                          borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                        ),
                      ),
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LinearSpacing.spacing8),
              const Text(
                '提示：用户名和密码为可选配置，如果代理服务器不需要认证请留空。',
                style: TextStyle(
                  color: LinearColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: LinearSpacing.spacing24),

            // 备注
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '备注',
                labelStyle: const TextStyle(color: LinearColors.textSecondary),
                hintText: '可选',
                hintStyle: const TextStyle(color: LinearColors.textQuaternary),
                filled: true,
                fillColor: LinearColors.fillSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: BorderSide(color: LinearColors.borderStandard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                  borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
                ),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: LinearSpacing.spacing32),

            // 保存按钮
            ElevatedButton(
              onPressed: _saveConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: LinearColors.accent,
                foregroundColor: LinearColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.spacing24,
                  vertical: LinearSpacing.spacing12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LinearRadius.standard),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手动输入路径对话框
class _ManualPathDialog extends StatefulWidget {
  final String initialPath;

  const _ManualPathDialog({this.initialPath = ''});

  @override
  State<_ManualPathDialog> createState() => _ManualPathDialogState();
}

class _ManualPathDialogState extends State<_ManualPathDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入私钥文件路径'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '文件路径',
              labelStyle: const TextStyle(color: LinearColors.textSecondary),
              hintText: '例如: /Users/lbp/.ssh/id_rsa',
              hintStyle: const TextStyle(color: LinearColors.textQuaternary),
              prefixIcon: const Icon(Icons.edit),
              filled: true,
              fillColor: LinearColors.fillSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LinearRadius.standard),
                borderSide: BorderSide(color: LinearColors.borderStandard),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LinearRadius.standard),
                borderSide: BorderSide(color: LinearColors.borderStandard),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LinearRadius.standard),
                borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: LinearSpacing.spacing12),
          const Text(
            '提示：由于 macOS 沙箱限制，无法直接选择 ~/.ssh 目录中的文件，请手动输入完整路径。',
            style: TextStyle(
              fontSize: 12,
              color: LinearColors.textTertiary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final path = _controller.text.trim();
            if (path.isNotEmpty) {
              Navigator.of(context).pop(path);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
