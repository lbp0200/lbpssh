import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import '../screens/app_settings_screen.dart';
import 'connection_list.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Function(SshConnection)? onConnectionTap;
  final Function(SshConnection)? onSftpTap;

  const CollapsibleSidebar({super.key, this.onConnectionTap, this.onSftpTap});

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 60.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _widthAnimation = Tween<double>(begin: _collapsedWidth, end: _expandedWidth)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _showSearch = false;
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleSearch() {
    final provider = context.read<ConnectionProvider>();
    setState(() {
      if (_isExpanded) {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
          provider.clearSearch();
        }
      } else {
        _isExpanded = true;
        _animationController.forward();
        _showSearch = true;
      }
    });
  }

  void _openSettings() {
    setState(() {
      _isExpanded = true;
      _showSearch = false;
      _animationController.forward();
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final currentWidth = _widthAnimation.value;
        final isCompactMode = currentWidth < 200;

        return Container(
          width: currentWidth,
          decoration: const BoxDecoration(
            color: LinearColors.panel,
          ),
          child: Column(
            children: [
              _buildHeader(theme, isCompactMode),
              Expanded(
                child: ConnectionList(
                  isCompact: isCompactMode,
                  onConnectionTap: widget.onConnectionTap,
                  onSftpTap: widget.onSftpTap,
                ),
              ),
              _buildBottomBar(theme, isCompactMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isCompactMode) {
    return Padding(
      padding: const EdgeInsets.all(LinearSpacing.spacing12),
      child: !isCompactMode
          ? Column(
              children: [
                if (_showSearch)
                  _buildSearchField(theme)
                else
                  _buildExpandedHeader(theme),
              ],
            )
          : _buildCollapsedHeader(theme),
    );
  }

  Widget _buildExpandedHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIconButton(
          icon: Icons.search,
          onPressed: _toggleSearch,
          tooltip: '搜索',
          theme: theme,
        ),
        _buildIconButton(
          icon: Icons.settings,
          onPressed: _openSettings,
          tooltip: '设置',
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: LinearColors.textPrimary),
      decoration: InputDecoration(
        hintText: '搜索连接...',
        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
        prefixIcon: Icon(Icons.search, color: LinearColors.textQuaternary.withValues(alpha: 0.6)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSearch,
          color: LinearColors.textQuaternary,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.spacing12,
          vertical: LinearSpacing.spacing8 + 2,
        ),
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
          borderSide: const BorderSide(color: LinearColors.accentInteractive),
        ),
        filled: true,
        fillColor: const Color(0x05ffffff),
      ),
      onChanged: (value) {
        context.read<ConnectionProvider>().setSearchQuery(value);
      },
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme) {
    return _buildIconButton(
      icon: Icons.chevron_right,
      onPressed: _toggleExpanded,
      tooltip: '展开',
      theme: theme,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(LinearRadius.standard),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(LinearRadius.standard),
          hoverColor: LinearColors.accentInteractive.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(LinearSpacing.spacing8),
            child: Icon(
              icon,
              color: LinearColors.textSecondary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isCompactMode) {
    if (!isCompactMode) {
      return Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing12),
        child: _buildIconButton(
          icon: Icons.chevron_left,
          onPressed: _toggleExpanded,
          tooltip: '折叠',
          theme: theme,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(LinearSpacing.spacing8),
        child: Column(
          children: [
            _buildIconButton(
              icon: Icons.search,
              onPressed: _toggleSearch,
              tooltip: '搜索',
              theme: theme,
            ),
            const SizedBox(height: LinearSpacing.spacing4),
            _buildIconButton(
              icon: Icons.settings,
              onPressed: _openSettings,
              tooltip: '设置',
              theme: theme,
            ),
          ],
        ),
      );
    }
  }
}
