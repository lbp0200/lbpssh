import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/presentation/providers/sftp_provider.dart';
import 'package:lbp_ssh/presentation/widgets/transfer_progress_dialog.dart';

/// 远程文件项（用于显示文件列表）
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.permissions = '',
  });
}

/// SFTP 浏览器界面
class SftpBrowserScreen extends StatefulWidget {
  final SshConnection connection;

  const SftpBrowserScreen({super.key, required this.connection});

  @override
  State<SftpBrowserScreen> createState() => _SftpBrowserScreenState();
}

class _SftpBrowserScreenState extends State<SftpBrowserScreen> {
  KittyFileTransferService? _transferService;
  List<FileItem> _items = [];
  bool _loading = false;
  String _currentPath = '/';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<SftpProvider>();
      final tab = await provider.openTab(widget.connection);
      setState(() {
        _transferService = tab.service;
        _currentPath = tab.currentPath;
      });
      await _refresh();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_transferService == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final items = await _transferService!.listCurrentDirectory();
      setState(() {
        _items = items;
        _currentPath = _transferService!.currentPath;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onItemTap(FileItem item) async {
    if (item.isDirectory) {
      await _transferService?.changeDirectory(item.name);
      await _refresh();
    }
  }

  Future<void> _goUp() async {
    await _transferService?.goUp();
    await _refresh();
  }

  Future<void> _createFolder() async {
    final name = await _showNameDialog('新建文件夹', '新建文件夹');
    if (name != null && name.isNotEmpty) {
      try {
        await _transferService?.createDirectory(name);
        await _refresh();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      // TODO: 使用 localPath 调用 KittyFileTransferService
      // ignore: unused_local_variable
      final String localPath = file.path!;
      final fileName = file.name;
      final fileSize = file.size;

      // 创建进度流
      final progressController = StreamController<TransferProgress>();

      if (!mounted) return;

      // 显示进度对话框
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => TransferProgressDialog(
          fileName: fileName,
          totalBytes: fileSize,
          progressStream: progressController.stream,
          onCancel: () {
            progressController.close();
            Navigator.pop(context);
          },
        ),
      );

      try {
        // 调用 KittyFileTransferService 发送文件
        await _transferService?.sendFile(
          localPath: localPath,
          remoteFileName: '$_currentPath/$fileName',
          onProgress: (progress) {
            progressController.add(progress);
          },
        );

        if (mounted) {
          Navigator.pop(context); // 关闭进度对话框
          _showMessage('上传成功');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showError('上传失败: $e');
        }
      }
    }
  }

  Future<void> _downloadFile(FileItem item) async {
    final result = await FilePicker.platform.saveFile(fileName: item.name);
    if (result != null) {
      // 创建进度流
      final progressController = StreamController<TransferProgress>();

      if (!mounted) return;

      // 显示进度对话框
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => TransferProgressDialog(
          fileName: item.name,
          totalBytes: item.size,
          progressStream: progressController.stream,
          onCancel: () {
            progressController.close();
            Navigator.pop(context);
          },
        ),
      );

      try {
        await _transferService?.downloadFile(
          item.path,
          result,
          onProgress: (progress) {
            progressController.add(progress);
          },
        );

        if (mounted) {
          Navigator.pop(context); // 关闭进度对话框
          _showMessage('下载成功');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showError('下载失败: $e');
        }
      }
    }
  }

  Future<void> _deleteItem(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (item.isDirectory) {
          await _transferService?.removeDirectory(item.path);
        } else {
          await _transferService?.removeFile(item.path);
        }
        await _refresh();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentPath != '/' ? _goUp : null,
            ),
            Expanded(
              child: Text(_currentPath, overflow: TextOverflow.ellipsis),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _connect, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('目录为空'));
    }

    // 按目录、文件分组排序
    final dirs = _items.where((i) => i.isDirectory).toList();
    final files = _items.where((i) => !i.isDirectory).toList();
    final sorted = [...dirs, ...files];

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        return ListTile(
          leading: Icon(
            item.isDirectory ? Icons.folder : _getFileIcon(item.name),
          ),
          title: Text(item.name),
          subtitle: item.isDirectory ? null : Text(_formatSize(item.size)),
          onTap: () => _onItemTap(item),
          onLongPress: () => _showItemMenu(item),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _uploadFile,
            tooltip: '上传',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolder,
            tooltip: '新建文件夹',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  void _showItemMenu(FileItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('下载'),
            onTap: () {
              Navigator.pop(context);
              if (!item.isDirectory) _downloadFile(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.description;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
