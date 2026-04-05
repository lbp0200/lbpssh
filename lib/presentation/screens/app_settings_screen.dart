import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_config.dart';
import '../../data/models/ssh_connection.dart';
import '../../data/models/terminal_config.dart';
import '../providers/app_config_provider.dart';
import '../providers/connection_provider.dart';
import 'connection_form.dart';
import 'import_export_settings.dart';
import 'sync_settings.dart';

class _LinearNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LinearNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LinearNavItem> createState() => _LinearNavItemState();
}

class _LinearNavItemState extends State<_LinearNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: LinearDuration.fast,
          margin: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing8,
            vertical: LinearSpacing.spacing4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing12,
            vertical: LinearSpacing.spacing8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0x0Dffffff)
                : (_isHovered ? const Color(0x05ffffff) : Colors.transparent),
            borderRadius: BorderRadius.circular(LinearRadius.standard),
            border: widget.isSelected
                ? Border(
                    left: BorderSide(
                      color: LinearColors.accentInteractive,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected
                    ? LinearColors.accentInteractive
                    : LinearColors.textSecondary,
              ),
              const SizedBox(width: LinearSpacing.spacing12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isSelected
                      ? LinearColors.textPrimary
                      : LinearColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  int _selectedIndex = 0;

  final List<String> _tabs = ['终端设置', '连接管理', '导入导出', '同步设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Row(
        children: [
          Container(
          width: 200,
          decoration: BoxDecoration(
            color: LinearColors.panel,
            border: Border(
              right: BorderSide(color: LinearColors.borderSubtle),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: LinearSpacing.spacing16),
              ...List.generate(_tabs.length, (index) {
                final isSelected = _selectedIndex == index;
                return _LinearNavItem(
                  icon: _getTabIcon(_tabs[index]),
                  label: _tabs[index],
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedIndex = index),
                );
              }),
            ],
          ),
        ),
        Container(
          width: 1,
          color: LinearColors.borderSubtle,
        ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const TerminalSettingsPage(),
                const ConnectionManagementPage(),
                const ImportExportSettingsScreen(),
                const SyncSettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case '终端设置':
        return Icons.terminal;
      case '连接管理':
        return Icons.settings;
      case '导入导出':
        return Icons.file_upload;
      case '同步设置':
        return Icons.cloud_sync;
      default:
        return Icons.settings;
    }
  }
}

class TerminalSettingsPage extends StatefulWidget {
  const TerminalSettingsPage({super.key});

  @override
  State<TerminalSettingsPage> createState() => _TerminalSettingsPageState();
}

class _TerminalSettingsPageState extends State<TerminalSettingsPage> {
  late TerminalConfig _config;
  late SshConfig _sshConfig;
  final _fontSizeController = TextEditingController();
  final _fontWeightController = TextEditingController();
  final _letterSpacingController = TextEditingController();
  final _lineHeightController = TextEditingController();
  final _paddingController = TextEditingController();
  final _fontFamilyController = TextEditingController();
  final _keepaliveController = TextEditingController();

  // 预设字体大小
  final List<int> _presetFontSizes = [10, 12, 14, 16, 18, 20, 24, 28, 32];

  // 扩展常用字体列表（跨平台支持）
  final List<String> _popularFonts = [
    // Nerd Fonts（内置，支持 eza --icons 等图标显示）
    'JetBrainsMonoNerdFontMono',
    'JetBrainsMonoNerdFont',
    // 等宽编程字体
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Source Code Pro',
    'Ubuntu Mono',
    'Hack',
    'Iosevka',
    'Consolas',
    'Monaco',
    'Menlo',
    'DejaVu Sans Mono',
    'Cascadia Code',
    'Cousine',
    'Droid Sans Mono',
    'Inconsolata',
    'Lato Mono',
    'Office Code Pro',
    'Open Sans Mono',
    'Oxygen Mono',
    'PT Mono',
    'Roboto Mono',
    'SF Mono',
    'Terminus',
    'Ubuntu',
    'Victor Mono',
    // 系统通用字体
    'Arial',
    'Helvetica',
    'Verdana',
    'Courier New',
    'Georgia',
    'Times New Roman',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final provider = Provider.of<AppConfigProvider>(context, listen: false);
    _config = provider.terminalConfig;
    _sshConfig = provider.sshConfig;
    _fontSizeController.text = _config.fontSize.toInt().toString();
    _fontWeightController.text = _config.fontWeight.toString();
    _letterSpacingController.text = _config.letterSpacing.toString();
    _lineHeightController.text = _config.lineHeight.toString();
    _paddingController.text = _config.padding.toString();
    _fontFamilyController.text = _config.fontFamily;
    _keepaliveController.text = (_sshConfig.keepaliveInterval ~/ 1000).toString();
  }

  void _onFontSizeChanged(double value) {
    setState(() {
      _config = _config.copyWith(fontSize: value);
      _fontSizeController.text = value.toInt().toString();
    });
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _fontWeightController.dispose();
    _letterSpacingController.dispose();
    _lineHeightController.dispose();
    _paddingController.dispose();
    _fontFamilyController.dispose();
    _keepaliveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '终端显示设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFontFamilySelector(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('字体大小'),
                        Text(
                          '${_config.fontSize.toInt()}px',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _config.fontSize,
                      min: 8,
                      max: 32,
                      divisions: 24,
                      onChanged: _onFontSizeChanged,
                    ),
                    // 预设按钮
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _presetFontSizes.map((size) {
                          final isSelected = _config.fontSize.toInt() == size;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text('${size}px'),
                              onSelected: (_) => _onFontSizeChanged(size.toDouble()),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _fontWeightController,
                  decoration: const InputDecoration(
                    labelText: '字重',
                    suffixText: '100-900',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final fontWeight = int.tryParse(value);
                    if (fontWeight != null &&
                        fontWeight >= 100 &&
                        fontWeight <= 900) {
                      _config = _config.copyWith(fontWeight: fontWeight);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _letterSpacingController,
                  decoration: const InputDecoration(
                    labelText: '字母间距',
                    suffixText: 'em',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final letterSpacing = double.tryParse(value);
                    if (letterSpacing != null) {
                      _config = _config.copyWith(letterSpacing: letterSpacing);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lineHeightController,
                  decoration: const InputDecoration(
                    labelText: '行高',
                    suffixText: '倍',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final lineHeight = double.tryParse(value);
                    if (lineHeight != null) {
                      _config = _config.copyWith(lineHeight: lineHeight);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paddingController,
            decoration: const InputDecoration(
              labelText: '内边距',
              suffixText: 'px',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              final padding = int.tryParse(value);
              if (padding != null && padding >= 0) {
                _config = _config.copyWith(padding: padding);
              }
            },
          ),
          const SizedBox(height: 24),
          // 实时预览区域
          _buildTerminalPreview(),
          const SizedBox(height: 24),
          const Text(
            '颜色设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _config.backgroundColor,
                  decoration: const InputDecoration(labelText: '背景颜色'),
                  onChanged: (value) {
                    _config = _config.copyWith(backgroundColor: value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _config.foregroundColor,
                  decoration: const InputDecoration(labelText: '前景颜色'),
                  onChanged: (value) {
                    _config = _config.copyWith(foregroundColor: value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _config.cursorColor,
            decoration: const InputDecoration(labelText: '光标颜色'),
            onChanged: (value) {
              _config = _config.copyWith(cursorColor: value);
            },
          ),
          const SizedBox(height: 32),
          const Text(
            '终端兼容性设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('启用 Kitty 协议'),
            subtitle: const Text(
              '发送终端设备属性查询 (\\x1b[>1u)，让支持 Kitty 协议的应用（如 Neovim）自动启用高级特性。关闭此选项可兼容老旧终端设备。',
            ),
            value: _config.enableKittyProtocol,
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(enableKittyProtocol: value);
              });
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _loadConfig();
                  setState(() {});
                },
                child: const Text('重置'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                      context,
                    );
                    if (scaffoldMessenger == null) return;

                    try {
                      final provider = Provider.of<AppConfigProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveTerminalConfig(_config);

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('设置已保存')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('保存失败: $e')),
                      );
                    }
                  },
                  child: const Text('保存显示设置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            '默认终端应用',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择执行 SSH 连接时打开的终端应用',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildDefaultTerminalSettings(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'SSH 连接设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _keepaliveController,
                  decoration: const InputDecoration(
                    labelText: 'Keepalive 间隔',
                    suffixText: '秒',
                    helperText: '定期发送保活数据包，防止连接因空闲断开',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final seconds = int.tryParse(value);
                    if (seconds != null && seconds > 0) {
                      _sshConfig = _sshConfig.copyWith(
                        keepaliveInterval: seconds * 1000,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _loadConfig();
                  setState(() {});
                },
                child: const Text('重置'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.maybeOf(
                      context,
                    );
                    if (scaffoldMessenger == null) return;

                    try {
                      final provider = Provider.of<AppConfigProvider>(
                        context,
                        listen: false,
                      );
                      await provider.saveSshConfig(_sshConfig);

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('SSH 设置已保存')),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('保存失败: $e')),
                      );
                    }
                  },
                  child: const Text('保存 SSH 设置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTerminalSettings() {
    // 常用 Shell 列表
    final commonShells = [
      {'name': 'zsh', 'path': '/bin/zsh'},
      {'name': 'bash', 'path': '/bin/bash'},
      {'name': 'fish', 'path': '/usr/local/bin/fish'},
      {'name': 'PowerShell', 'path': '/usr/local/bin/pwsh'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本地终端 Shell',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '选择或输入本地终端使用的 Shell 路径',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: commonShells.any((s) => s['path'] == _config.shellPath)
              ? _config.shellPath
              : null,
          decoration: const InputDecoration(
            labelText: 'Shell',
            hintText: '选择常用 Shell 或输入自定义路径',
          ),
          items: [
            // 自动检测选项
            DropdownMenuItem(
              value: '',
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('自动检测 (系统默认)'),
                ],
              ),
            ),
            const DropdownMenuItem(
              value: '__divider__',
              enabled: false,
              child: Divider(),
            ),
            // 常用 Shell
            ...commonShells.map((shell) {
              return DropdownMenuItem(
                value: shell['path'],
                child: Text('${shell['name']} (${shell['path']})'),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null && value != '__divider__') {
              setState(() {
                _config = _config.copyWith(shellPath: value);
              });
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _config.shellPath,
          decoration: const InputDecoration(
            labelText: '自定义 Shell 路径',
            hintText: '例如：/usr/bin/zsh',
          ),
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(shellPath: value);
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          '提示：空值将自动使用系统默认 Shell (从 \$SHELL 环境变量获取)',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white;
    }
  }

  Widget _buildTerminalPreview() {
    final bgColor = _parseColor(_config.backgroundColor);
    final fgColor = _parseColor(_config.foregroundColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '终端预览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '提示：使用下方按钮或滑块调整字体大小',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: EdgeInsets.all(_config.padding.toDouble()),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 模拟终端内容
                _buildPreviewLine('user@hostname:~\$', fgColor),
                _buildPreviewLine('user@hostname:~\$ ls -la', fgColor),
                _buildPreviewLine('total 24', fgColor.withValues(alpha: 0.7)),
                _buildPreviewLine('drwxr-xr-x  5 user  group  160 Jan 15 10:30 .', fgColor.withValues(alpha: 0.7)),
                _buildPreviewLine('drwxr-xr-x  3 root  root   100 Jan 15 10:30 ..', fgColor.withValues(alpha: 0.7)),
                _buildPreviewLine('-rw-r--r--  1 user  group  220 Jan 15 10:30 .bashrc', fgColor.withValues(alpha: 0.7)),
                _buildPreviewLine('-rw-r--r--  1 user  group  655 Jan 15 10:30 config.json', fgColor.withValues(alpha: 0.7)),
                _buildPreviewLine('user@hostname:~\$ _', fgColor, showCursor: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _onFontSizeChanged(_config.fontSize - 2),
              icon: const Icon(Icons.text_decrease, size: 18),
              label: const Text('缩小'),
            ),
            const SizedBox(width: 16),
            FilledButton.tonal(
              onPressed: () => _onFontSizeChanged(14),
              child: const Text('默认 (14px)'),
            ),
            const SizedBox(width: 16),
            FilledButton.tonalIcon(
              onPressed: () => _onFontSizeChanged(_config.fontSize + 2),
              icon: const Icon(Icons.text_increase, size: 18),
              label: const Text('放大'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewLine(String text, Color color, {bool showCursor = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: _config.fontFamily.isNotEmpty ? _config.fontFamily : null,
            fontSize: _config.fontSize,
            height: _config.lineHeight,
            color: color,
            letterSpacing: _config.letterSpacing,
          ),
        ),
        if (showCursor)
          Container(
            width: _config.fontSize * 0.6,
            height: _config.fontSize,
            color: _parseColor(_config.cursorColor),
            margin: const EdgeInsets.only(left: 2),
          ),
      ],
    );
  }

  Widget _buildFontFamilySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _popularFonts.contains(_config.fontFamily)
              ? _config.fontFamily
              : null,
          decoration: const InputDecoration(
            labelText: '字体家族',
            hintText: '选择或输入字体',
          ),
          items: [
            // 编程字体分类
            const DropdownMenuItem(
              value: 'programming_header',
              enabled: false,
              child: Text(
                ' - 编程等宽字体 -',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
            ..._popularFonts.take(10).map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(
                  font,
                  style: TextStyle(fontFamily: font),
                ),
              );
            }),
            const DropdownMenuItem(
              value: 'divider_item',
              enabled: false,
              child: Divider(),
            ),
            // 系统字体
            const DropdownMenuItem(
              value: 'system_header',
              enabled: false,
              child: Text(
                ' - 系统字体 -',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
            ..._popularFonts.skip(10).map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(font),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null && value != 'programming_header' && value != 'system_header' && value != 'divider_item') {
              _fontFamilyController.text = value;
              _config = _config.copyWith(fontFamily: value);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fontFamilyController,
                decoration: const InputDecoration(
                  hintText: '输入自定义字体名称',
                ),
                onChanged: (value) {
                  _config = _config.copyWith(fontFamily: value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 字体预览
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '字体预览',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The quick brown fox jumps over the lazy dog.',
                style: TextStyle(
                  fontFamily: _config.fontFamily.isNotEmpty ? _config.fontFamily : null,
                  fontSize: _config.fontSize,
                  fontWeight: FontWeight.values[_config.fontWeight ~/ 100],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1234567890 !@#\$%^&*()',
                style: TextStyle(
                  fontFamily: _config.fontFamily.isNotEmpty ? _config.fontFamily : null,
                  fontSize: _config.fontSize,
                  fontWeight: FontWeight.values[_config.fontWeight ~/ 100],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '提示：确保系统已安装所选字体。推荐使用等宽编程字体以获得最佳终端体验。',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// 连接管理页面
class ConnectionManagementPage extends StatelessWidget {
  const ConnectionManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '已保存的连接',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ConnectionFormScreen(connection: null),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加连接'),
              ),
            ],
          ),
        ),
        const Divider(),
        // 连接列表
        Expanded(
          child: Consumer<ConnectionProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              final connections = provider.connections;

              if (connections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无连接配置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ConnectionFormScreen(connection: null),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加第一个连接'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final connection = connections[index];
                  return _ConnectionManagementItem(connection: connection);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConnectionManagementItem extends StatelessWidget {
  final SshConnection connection;

  const _ConnectionManagementItem({required this.connection});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.vpn_key,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(connection.name),
        subtitle: Text(
          '${connection.username}@${connection.host}:${connection.port}',
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ConnectionFormScreen(connection: connection),
                ),
              );
            } else if (value == 'delete') {
              _showDeleteDialog(context, provider);
            }
          },
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ConnectionFormScreen(connection: connection),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ConnectionProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除连接 "${connection.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接已删除')));
      }
    }
  }
}
