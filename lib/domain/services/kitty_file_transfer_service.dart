import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../../data/models/file_item.dart';
import 'file_list_parser.dart';
import 'kitty_file_transfer_encoder.dart';
import 'kitty_service_base.dart';
import 'ssh_service.dart';

export 'kitty_file_transfer_encoder.dart';
export 'kitty_file_transfer_models.dart';

/// Kitty 文件传输服务
///
/// 通过 SSH 终端发送 OSC 5113 控制序列实现文件传输
class KittyFileTransferService extends KittyServiceBase {
  /// 转义双引号 shell 参数中的特殊字符（\、"、$、`），防止远程文件名/路径里的
  /// 反引号、$(...)、内嵌引号在回退终端命令中触发注入或破坏。
  String _escapeForDoubleQuotes(String s) {
    return s
        .replaceAll(r'\', r'\\') // \ → \\
        .replaceAll('"', r'\"') // " → \"
        .replaceAll(r'$', r'\$') // $ → \$
        .replaceAll('`', r'\`'); // ` → \`
  }

  final KittyFileTransferEncoder _encoder = const KittyFileTransferEncoder();
  String _currentPath;
  SftpClient? _sftpClient;
  IOSink? _activeDownloadSink;

  KittyFileTransferService({super.session, String initialPath = '/'})
    : _currentPath = initialPath;

  /// 当前路径
  String get currentPath => _currentPath;

  /// 是否支持 Kitty 协议
  bool get supportsKittyProtocol => false;

  /// 获取 SFTP 客户端
  Future<SftpClient?> _getSftpClient() async {
    if (_sftpClient != null) return _sftpClient;

    // 尝试从 inputService 获取 SFTP 客户端
    final inputService = sessionOrNull?.inputService;
    if (inputService == null) return null;

    // 检查是否是 SshService
    if (inputService is SshService) {
      _sftpClient = await inputService.getSftpClient();
    }
    return _sftpClient;
  }

  /// 获取当前目录文件列表
  Future<List<FileItem>> listCurrentDirectory() async {
    // 尝试使用 SFTP 协议获取文件列表
    final sftp = await _getSftpClient();
    if (sftp != null) {
      try {
        final items = <FileItem>[];
        final entries = await sftp.listdir(_currentPath);
        for (final entry in entries) {
          // 跳过 . 和 ..
          if (entry.filename == '.' || entry.filename == '..') continue;

          final attr = entry.attr;
          final isDir = attr.isDirectory;

          items.add(
            FileItem(
              name: entry.filename,
              path: _currentPath == '/'
                  ? '/${entry.filename}'
                  : '$_currentPath/${entry.filename}',
              isDirectory: isDir,
              size: attr.size ?? 0,
              modified: attr.modifyTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(attr.modifyTime! * 1000)
                  : null,
              permissions: _formatPermissions(attr.mode?.value),
            ),
          );
        }
        return items;
      } catch (e) {
        // SFTP 失败，回退到 shell 命令
      }
    }

    // 使用 shell 命令作为回退方案
    const lsCommand = 'ls -la';
    final output = await session.inputService.executeCommand(
      'cd "${_escapeForDoubleQuotes(_currentPath)}" && $lsCommand',
      silent: true,
    );

    // 解析输出
    final items = FileListParser.parse(output, _currentPath);
    return items;
  }

  String _formatPermissions(int? mode) {
    if (mode == null) return '';
    // 将 mode 转换为权限字符串（如 drwxr-xr-x）
    final buffer = StringBuffer();

    // 文件类型
    if ((mode & 0x4000) != 0) {
      buffer.write('d');
    } else if ((mode & 0xF000) == 0xA000) {
      buffer.write('l');
    } else {
      buffer.write('-');
    }

    // 所有者权限
    buffer.write((mode & 0x100) != 0 ? 'r' : '-');
    buffer.write((mode & 0x080) != 0 ? 'w' : '-');
    buffer.write((mode & 0x040) != 0 ? 'x' : '-');

    // 组权限
    buffer.write((mode & 0x020) != 0 ? 'r' : '-');
    buffer.write((mode & 0x010) != 0 ? 'w' : '-');
    buffer.write((mode & 0x008) != 0 ? 'x' : '-');

    // 其他用户权限
    buffer.write((mode & 0x004) != 0 ? 'r' : '-');
    buffer.write((mode & 0x002) != 0 ? 'w' : '-');
    buffer.write((mode & 0x001) != 0 ? 'x' : '-');

    return buffer.toString();
  }

  /// 进入目录
  Future<void> changeDirectory(String path) async {
    if (sessionOrNull == null) {
      throw Exception('未连接到终端');
    }

    final newPath = path.startsWith('/')
        ? path
        : (_currentPath == '/' ? '/$path' : '$_currentPath/$path');

    // 直接更新路径，不需要执行 cd 命令
    // 因为我们使用绝对路径来访问文件
    _currentPath = newPath;
  }

  /// 返回上级目录
  Future<void> goUp() async {
    if (sessionOrNull == null) {
      throw Exception('未连接到终端');
    }
    if (_currentPath == '/') return;

    // 直接更新路径，不需要执行 cd 命令
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.join('/');
    if (_currentPath.isEmpty) _currentPath = '/';
  }

  /// 创建目录
  Future<void> createDirectory(String name) async {
    final sftp = await _getSftpClient();
    if (sftp != null) {
      final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
      await sftp.mkdir(path);
      return;
    }

    // 回退到 shell 命令
    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    await session.executeCommand('mkdir "${_escapeForDoubleQuotes(path)}"');
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    final sftp = await _getSftpClient();
    if (sftp != null) {
      await sftp.remove(path);
      return;
    }

    // 回退到 shell 命令
    await session.executeCommand('rm "${_escapeForDoubleQuotes(path)}"');
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    final sftp = await _getSftpClient();
    if (sftp != null) {
      await sftp.rmdir(path);
      return;
    }

    // 回退到 shell 命令
    await session.executeCommand('rmdir "${_escapeForDoubleQuotes(path)}"');
  }

  /// 下载文件
  ///
  /// [remotePath] - 远程文件路径
  /// [localPath] - 本地保存路径
  /// [onProgress] - 进度回调（可选）
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    TransferProgressCallback? onProgress,
  }) async {
    if (sessionOrNull == null) {
      throw Exception('未连接到终端，无法下载文件。请确保已建立 SSH 连接。');
    }

    final transferId = 'dl_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = remotePath.split('/').last;

    // 先写入临时文件，成功后原子重命名为最终路径；失败时删除临时文件，
    // 避免在目标路径留下截断/损坏的文件（覆盖已有本地文件时尤其危险）
    final partFile = File('$localPath.part');
    _activeDownloadSink = partFile.openWrite();
    final sink = _activeDownloadSink!;

    int transferred = 0;
    int totalSize = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // 创建 Completer 等待传输完成
    final completer = Completer<void>();

    // 监听文件传输事件
    final subscription = session.fileTransferStream.listen(
      (event) async {
        switch (event.type) {
          case 'start':
            totalSize = event.fileSize ?? 0;
            break;
          case 'chunk':
            if (event.data != null) {
              sink.add(event.data!);
              transferred += event.data!.length;

              if (onProgress != null) {
                final elapsed =
                    (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
                final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

                onProgress(
                  TransferProgress(
                    fileName: fileName,
                    transferredBytes: transferred,
                    totalBytes: totalSize,
                    percent: totalSize > 0 ? transferred / totalSize * 100 : 0,
                    bytesPerSecond: speed,
                  ),
                );
              }
            }
            break;
          case 'end':
            await sink.close();
            // 传输完整结束：将临时文件原子重命名为最终路径
            if (partFile.existsSync()) {
              await partFile.rename(localPath);
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
        }
      },
      onError: (Object error) async {
        await sink.close();
        // 失败：删除临时文件，避免残留截断内容
        _deletePartFile(partFile);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // 发送接收会话请求
    writeRaw('\x1b]5113;ac=recv;id=$transferId;f=$remotePath\x1b\\');

    // 等待传输完成或超时
    try {
      await completer.future.timeout(const Duration(minutes: 5));
    } catch (e) {
      // 超时/失败：关闭文件流并删除临时文件，避免残留截断内容
      await sink.close();
      _deletePartFile(partFile);
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  /// 检查远程是否支持 Kitty 协议
  Future<ProtocolSupportResult> checkProtocolSupport() async {
    if (sessionOrNull == null) {
      return ProtocolSupportResult(isSupported: false, errorMessage: '未连接到终端');
    }

    // 尝试执行 ki version 命令
    // 如果不支持，将返回 "command not found" 或类似错误
    try {
      final output = await session.inputService.executeCommand(
        'ki version',
        silent: true,
      );

      // 检查输出中是否包含版本信息
      if (output.contains('ki version') || output.contains('kitty')) {
        return ProtocolSupportResult(isSupported: true);
      }

      return ProtocolSupportResult(
        isSupported: false,
        errorMessage: '远程服务器不支持 Kitty 文件传输协议。请确保远程已安装 Kitty 的 ki 工具。',
      );
    } catch (e) {
      return ProtocolSupportResult(
        isSupported: false,
        errorMessage: '远程服务器不支持 Kitty 文件传输协议。请确保远程已安装 Kitty 的 ki 工具。',
      );
    }
  }

  /// 发送文件到终端（发送模式）
  ///
  /// [localPath] - 本地文件路径
  /// [remoteFileName] - 远程文件名
  /// [onProgress] - 进度回调
  /// [compression] - 压缩类型
  /// [bypass] - 预共享密码 (SHA256 哈希)
  /// [quiet] - 静默模式 (0=详细, 1=仅错误, 2=完全静默)
  Future<void> sendFile({
    required String localPath,
    required String remoteFileName,
    required TransferProgressCallback onProgress,
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) async {
    if (sessionOrNull == null) {
      throw Exception('未连接到终端，无法发送文件。请确保已建立 SSH 连接。');
    }

    // 检查远程是否支持 Kitty 协议
    final support = await checkProtocolSupport();
    if (!support.isSupported) {
      throw Exception(
        '远程服务器不支持 Kitty 文件传输协议。\n${support.errorMessage}\n\n请使用 SCP 命令手动上传文件。',
      );
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 2. 发送文件元数据
    writeRaw(
      _encoder.createFileMetadata(
        sessionId: transferId,
        fileId: fileId,
        fileName: remoteFileName,
        fileSize: fileSize,
      ),
    );

    // 3. 分块发送数据
    final stream = file.openRead();
    int transferred = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    await for (final chunk in stream) {
      writeRaw(
        _encoder.createDataChunk(
          sessionId: transferId,
          fileId: fileId,
          data: chunk,
        ),
      );

      transferred += chunk.length;
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
      final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

      onProgress(
        TransferProgress(
          fileName: fileName,
          transferredBytes: transferred,
          totalBytes: fileSize,
          percent: transferred / fileSize * 100,
          bytesPerSecond: speed,
        ),
      );
    }

    // 4. 结束会话
    writeRaw(_encoder.createFinishSession(transferId));
  }

  /// 发送符号链接
  Future<void> sendSymlink({
    required String localPath,
    required String remoteFileName,
    required TransferProgressCallback onProgress,
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) async {
    final link = Link(localPath);
    if (!await link.exists()) {
      throw Exception('符号链接不存在: $localPath');
    }

    final target = await link.target();
    final fileName = p.basename(localPath);
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 2. 发送符号链接元数据
    writeRaw(
      _encoder.createFileMetadata(
        sessionId: transferId,
        fileId: fileId,
        fileName: remoteFileName,
        fileSize: 0,
        fileType: FileType.symlink,
        linkTarget: target,
      ),
    );

    // 3. 发送结束
    writeRaw(_encoder.createEndData(transferId, fileId));

    // 4. 结束会话
    writeRaw(_encoder.createFinishSession(transferId));

    onProgress(
      TransferProgress(
        fileName: fileName,
        transferredBytes: 0,
        totalBytes: 0,
        percent: 100,
        bytesPerSecond: 0,
      ),
    );
  }

  /// 发送目录（递归）
  Future<void> sendDirectory({
    required String localPath,
    required String remotePath,
    required TransferProgressCallback onProgress,
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) async {
    final dir = Directory(localPath);
    if (!await dir.exists()) {
      throw Exception('目录不存在: $localPath');
    }

    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 递归发送文件和目录
    Future<void> sendEntity(
      FileSystemEntity entity,
      String remoteEntityPath,
    ) async {
      switch (entity) {
        case File f:
          final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
          final fileSize = await f.length();

          writeRaw(
            _encoder.createFileMetadata(
              sessionId: transferId,
              fileId: fileId,
              fileName: remoteEntityPath,
              fileSize: fileSize,
            ),
          );

          final stream = f.openRead();
          int transferred = 0;
          await for (final chunk in stream) {
            writeRaw(
              _encoder.createDataChunk(
                sessionId: transferId,
                fileId: fileId,
                data: chunk,
              ),
            );
            transferred = transferred + chunk.length;
          }

          onProgress(
            TransferProgress(
              fileName: p.basename(remoteEntityPath),
              transferredBytes: transferred,
              totalBytes: fileSize,
              percent: 0,
              bytesPerSecond: 0,
            ),
          );

        case Directory d:
          final dirId = 'd${DateTime.now().millisecondsSinceEpoch}';
          writeRaw(
            _encoder.createDirectoryMetadata(
              sessionId: transferId,
              fileId: dirId,
              dirName: remoteEntityPath,
            ),
          );

          final children = await d.list().toList();
          for (final child in children) {
            final childName = p.basename(child.path);
            final childRemotePath = '$remoteEntityPath/$childName';
            await sendEntity(child, childRemotePath);
          }

        case Link l:
          final target = await l.target();
          final linkId = 'l${DateTime.now().millisecondsSinceEpoch}';
          writeRaw(
            _encoder.createFileMetadata(
              sessionId: transferId,
              fileId: linkId,
              fileName: remoteEntityPath,
              fileSize: 0,
              fileType: FileType.symlink,
              linkTarget: target,
            ),
          );
      }
    }

    // 发送根目录
    final dirName = p.basename(localPath);
    writeRaw(
      _encoder.createDirectoryMetadata(
        sessionId: transferId,
        fileId: 'root',
        dirName: remotePath,
      ),
    );

    // 发送所有内容
    final children = await dir.list().toList();
    for (final child in children) {
      final childName = p.basename(child.path);
      final childRemotePath = '$remotePath/$childName';
      await sendEntity(child, childRemotePath);
    }

    // 结束会话
    writeRaw(_encoder.createFinishSession(transferId));

    onProgress(
      TransferProgress(
        fileName: dirName,
        transferredBytes: 0,
        totalBytes: 0,
        percent: 100,
        bytesPerSecond: 0,
      ),
    );
  }

  /// 发送文件带元数据
  Future<void> sendFileWithMetadata({
    required String localPath,
    required String remoteFileName,
    required TransferProgressCallback onProgress,
    CompressionType compression = CompressionType.none,
    TransmissionType transmissionType = TransmissionType.simple,
    int? permissions,
    int? mtime,
    String? bypass,
    int quiet = 0,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 开始发送会话
    writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 发送文件元数据（带权限和时间）
    writeRaw(
      _encoder.createFileMetadata(
        sessionId: transferId,
        fileId: fileId,
        fileName: remoteFileName,
        fileSize: fileSize,
        transmissionType: transmissionType,
        permissions: permissions,
        mtime: mtime,
      ),
    );

    // 分块发送数据
    final stream = file.openRead();
    int transferred = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    await for (final chunk in stream) {
      writeRaw(
        _encoder.createDataChunk(
          sessionId: transferId,
          fileId: fileId,
          data: chunk,
        ),
      );

      transferred += chunk.length;
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
      final speed = elapsed > 0 ? (transferred / elapsed).round() : 0;

      onProgress(
        TransferProgress(
          fileName: fileName,
          transferredBytes: transferred,
          totalBytes: fileSize,
          percent: transferred / fileSize * 100,
          bytesPerSecond: speed,
        ),
      );
    }

    // 结束会话
    writeRaw(_encoder.createFinishSession(transferId));
  }

  /// 取消传输
  Future<void> cancelTransfer(String transferId) async {
    writeRaw(_encoder.createCancelSession(transferId));
  }

  /// 删除下载临时文件（失败时清理）；目标可能已被重命名或不存在，静默处理
  void _deletePartFile(File partFile) {
    try {
      if (partFile.existsSync()) {
        partFile.deleteSync();
      }
    } catch (e) {
      // 目标可能已被重命名或不存在，静默处理（不上报）
      debugPrint('[KittyFileTransferService] _deletePartFile failed: $e');
    }
  }

  /// 清理资源（关闭活动文件流）
  Future<void> dispose() async {
    await _activeDownloadSink?.close();
    _activeDownloadSink = null;
  }
}
