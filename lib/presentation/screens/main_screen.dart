import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/ssh_connection.dart';
import '../providers_riverpod/terminal_provider_riverpod.dart';
import '../screens/sftp_browser_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/terminal_view.dart';

/// 主界面
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalNotifier = ref.read(terminalProvider.notifier);
      terminalNotifier.initialize();
    });
  }

  /// 显示错误详情对话框
  void _showErrorDialog(
    BuildContext context,
    SshConnection connection,
    String errorMessage,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          ErrorDetailDialog(connection: connection, errorMessage: errorMessage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LinearColors.background,
      body: Row(
        children: [
          // Connection list sidebar
          CollapsibleSidebar(
            onConnectionTap: (connection) async {
              final terminalNotifier = ref.read(terminalProvider.notifier);
              // 每次点击都创建新的终端会话（即使已存在也创建新的）
              try {
                await terminalNotifier.createSession(connection);
              } catch (e) {
                if (context.mounted) {
                  _showErrorDialog(context, connection, e.toString());
                }
              }
            },
            onSftpTap: (connection) async {
              final terminalNotifier = ref.read(terminalProvider.notifier);
              // 检查是否已经存在终端会话
              final existingSession = terminalNotifier.getSession(
                connection.id,
              );
              if (existingSession == null) {
                // 不存在会话，创建新的终端会话
                await terminalNotifier.createSession(connection);
              }
              // 然后打开 SFTP 页面
              if (context.mounted) {
                Navigator.push<Object?>(
                  context,
                  MaterialPageRoute<Object?>(
                    builder: (context) =>
                        SftpBrowserScreen(connection: connection),
                  ),
                );
              }
            },
          ),
          Container(width: 1, color: LinearColors.borderStandard),
          // Terminal view
          const Expanded(child: TerminalTabsView()),
        ],
      ),
    );
  }
}
