import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'connection_management_page.dart';
import 'import_export_settings.dart';
import 'sync_settings.dart';
import 'terminal_settings_page.dart';

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
                ? const Border(
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
      backgroundColor: LinearColors.background,
      appBar: AppBar(
        title: Text(_tabs[_selectedIndex]),
        backgroundColor: LinearColors.panel,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LinearColors.textPrimary,
      ),
      body: Row(
        children: [
          Container(
            width: 200,
            decoration: const BoxDecoration(
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
          Container(width: 1, color: LinearColors.borderSubtle),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                TerminalSettingsPage(),
                ConnectionManagementPage(),
                ImportExportSettingsScreen(),
                SyncSettingsScreen(),
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
