import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import 'file_list_parser.dart';
import '../../presentation/screens/sftp_browser_screen.dart';
import 'terminal_service.dart';
import 'ssh_service.dart';

/// 压缩类型
enum CompressionType { none, zlib }

/// 文件类型
enum FileType { regular, directory, symlink, link }

/// 传输类型
enum TransmissionType { simple, rsync }

/// 文件元数据
class FileMetadata {
  final String name;
  final FileType fileType;
  final int? size;
  final int? permissions;
  final int? mtime; // 纳秒级时间戳
  final String? linkTarget;

  FileMetadata({
    required this.name,
    this.fileType = FileType.regular,
    this.size,
    this.permissions,
    this.mtime,
    this.linkTarget,
  });
}

/// 传输状态
class TransferStatus {
  final String sessionId;
  final String? fileId;
  final bool isOk;
  final String? errorMessage;
  final int? size;

  TransferStatus({
    required this.sessionId,
    this.fileId,
    required this.isOk,
    this.errorMessage,
    this.size,
  });
}

/// 文件传输进度
class TransferProgress {
  final String fileName;
  final int transferredBytes;
  final int totalBytes;
  final double percent;
  final int bytesPerSecond;

  TransferProgress({
    required this.fileName,
    required this.transferredBytes,
    required this.totalBytes,
    required this.percent,
    required this.bytesPerSecond,
  });
}

/// 文件传输进度回调
typedef TransferProgressCallback = void Function(TransferProgress progress);

/// Kitty 协议支持检测结果
class ProtocolSupportResult {
  final bool isSupported;
  final String? errorMessage;

  ProtocolSupportResult({required this.isSupported, this.errorMessage});
}

/// Kitty 协议文件传输编码器
class KittyFileTransferEncoder {
  /// 编码文件名为 base64
  String encodeFileName(String name) {
    return base64Encode(utf8.encode(name));
  }

  /// 创建发送会话开始序列
  String createSendSession(
    String sessionId, {
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) {
    String cmd = '\x1b]5113;ac=send;id=$sessionId';
    if (compression == CompressionType.zlib) {
      cmd += ';zip=zlib';
    }
    if (bypass != null) {
      cmd += ';pw=$bypass';
    }
    if (quiet > 0) {
      cmd += ';q=$quiet';
    }
    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建接收会话开始序列
  String createReceiveSession(
    String sessionId, {
    CompressionType compression = CompressionType.none,
    String? bypass,
    int quiet = 0,
  }) {
    String cmd = '\x1b]5113;ac=recv;id=$sessionId';
    if (compression == CompressionType.zlib) {
      cmd += ';zip=zlib';
    }
    if (bypass != null) {
      cmd += ';pw=$bypass';
    }
    if (quiet > 0) {
      cmd += ';q=$quiet';
    }
    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建文件元数据序列
  String createFileMetadata({
    required String sessionId,
    required String fileId,
    required String fileName,
    required int fileSize,
    FileType fileType = FileType.regular,
    TransmissionType transmissionType = TransmissionType.simple,
    int? permissions,
    int? mtime,
    String? linkTarget,
  }) {
    final encodedName = encodeFileName(fileName);
    String cmd =
        '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;size=$fileSize';

    // 文件类型
    switch (fileType) {
      case FileType.directory:
        cmd += ';ft=directory';
        break;
      case FileType.symlink:
        cmd += ';ft=symlink';
        break;
      case FileType.link:
        cmd += ';ft=link';
        break;
      default:
        break;
    }

    // 传输类型
    if (transmissionType == TransmissionType.rsync) {
      cmd += ';tt=rsync';
    }

    // 权限
    if (permissions != null) {
      cmd += ';prm=$permissions';
    }

    // 修改时间 (纳秒级时间戳)
    if (mtime != null) {
      cmd += ';mod=$mtime';
    }

    // 符号链接目标
    if (linkTarget != null) {
      cmd += ';n=${encodeFileName(linkTarget)}';
    }

    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建目录元数据序列
  String createDirectoryMetadata({
    required String sessionId,
    required String fileId,
    required String dirName,
    int? permissions,
    int? mtime,
  }) {
    final encodedName = encodeFileName(dirName);
    String cmd =
        '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=$encodedName;ft=directory';

    if (permissions != null) {
      cmd += ';prm=$permissions';
    }
    if (mtime != null) {
      cmd += ';mod=$mtime';
    }

    cmd += '\x1b\\';
    return cmd;
  }

  /// 创建数据块序列
  String createDataChunk({
    required String sessionId,
    required String fileId,
    required List<int> data,
  }) {
    final encoded = base64Encode(data);
    return '\x1b]5113;ac=data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
  }

  /// 创建数据结束序列
  String createEndData(String sessionId, String fileId, {List<int>? data}) {
    if (data != null) {
      final encoded = base64Encode(data);
      return '\x1b]5113;ac=end_data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
    }
    return '\x1b]5113;ac=end_data;id=$sessionId;fid=$fileId\x1b\\';
  }

  /// 创建传输结束序列
  String createFinishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }

  /// 创建取消传输序列
  String createCancelSession(String sessionId) {
    return '\x1b]5113;ac=cancel;id=$sessionId\x1b\\';
  }

  /// 解析状态响应
  TransferStatus? parseStatusResponse(String response) {
    // 解析 OSC 5113 响应
    // 格式: ac=status;id=xxx;st=OK 或 ac=status;id=xxx;st=ERROR:message
    try {
      final regex = RegExp(r'ac=status;id=([^;]+);st=([^:;]+)(?::(.*))?');
      final match = regex.firstMatch(response);
      if (match != null) {
        final sessionId = match.group(1)!;
        final status = match.group(2)!;
        final message = match.group(3);
        final isOk = status == 'OK';

        // 提取 size 参数
        int? size;
        final sizeRegex = RegExp(r'sz=(\d+)');
        final sizeMatch = sizeRegex.firstMatch(response);
        if (sizeMatch != null) {
          size = int.tryParse(sizeMatch.group(1)!);
        }

        return TransferStatus(
          sessionId: sessionId,
          isOk: isOk,
          errorMessage: message,
          size: size,
        );
      }
    } catch (e) {
      // 忽略解析错误
    }
    return null;
  }
}

/// Kitty 文件传输服务
///
/// 通过 SSH 终端发送 OSC 5113 控制序列实现文件传输
class KittyFileTransferService {
  final KittyFileTransferEncoder _encoder = KittyFileTransferEncoder();
  final TerminalSession? _session;
  String _currentPath;
  SftpClient? _sftpClient;
  IOSink? _activeDownloadSink;

  // ignore: prefer_const_constructors
  KittyFileTransferService({TerminalSession? session, String initialPath = '/'})
    : _session = session,
      _currentPath = initialPath;

  /// 当前路径
  String get currentPath => _currentPath;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 是否支持 Kitty 协议
  bool get supportsKittyProtocol => false;

  /// 获取 SFTP 客户端
  Future<SftpClient?> _getSftpClient() async {
    if (_sftpClient != null) return _sftpClient;

    // 尝试从 inputService 获取 SFTP 客户端
    final inputService = _session?.inputService;
    if (inputService == null) return null;

    // 检查是否是 SshService
    if (inputService is SshService) {
      _sftpClient = await inputService.getSftpClient();
    }
    return _sftpClient;
  }

  /// 获取当前目录文件列表
  Future<List<FileItem>> listCurrentDirectory() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

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
    final output = await _session.inputService.executeCommand(
      'cd "$_currentPath" && $lsCommand',
      silent: true,
    );

    // 解析输出
    final items = FileListParser.parse(output, _currentPath, osType: 'linux');
    return items;
  }

  String _formatPermissions(int? mode) {
    if (mode == null) return '';
    // 将 mode 转换为权限字符串（如 drwxr-xr-x）
    final buffer = StringBuffer();

    // 文件类型
    if ((mode & 0x4000) != 0) {
      buffer.write('d');
    } else if ((mode & 0xA000) != 0) {
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
    if (_session == null) {
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
    if (_session == null) {
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
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    await _session.executeCommand('mkdir "$path"');
  }

  /// 删除文件
  Future<void> removeFile(String path) async {
    final sftp = await _getSftpClient();
    if (sftp != null) {
      await sftp.remove(path);
      return;
    }

    // 回退到 shell 命令
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    await _session.executeCommand('rm "$path"');
  }

  /// 删除目录
  Future<void> removeDirectory(String path) async {
    final sftp = await _getSftpClient();
    if (sftp != null) {
      await sftp.rmdir(path);
      return;
    }

    // 回退到 shell 命令
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    await _session.executeCommand('rmdir "$path"');
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
    if (_session == null) {
      throw Exception('未连接到终端，无法下载文件。请确保已建立 SSH 连接。');
    }

    final transferId = 'dl_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = remotePath.split('/').last;

    // 创建本地文件
    final file = File(localPath);
    _activeDownloadSink = file.openWrite();
    final sink = _activeDownloadSink!;

    int transferred = 0;
    int totalSize = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // 创建 Completer 等待传输完成
    final completer = Completer<void>();

    // 监听文件传输事件
    final subscription = _session.fileTransferStream.listen(
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
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
        }
      },
      onError: (Object error) async {
        await sink.close();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // 发送接收会话请求
    _session.writeRaw('\x1b]5113;ac=recv;id=$transferId;f=$remotePath\x1b\\');

    // 等待传输完成或超时
    try {
      await completer.future.timeout(const Duration(minutes: 5));
    } catch (e) {
      // 超时
      await sink.close();
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  /// 检查远程是否支持 Kitty 协议
  Future<ProtocolSupportResult> checkProtocolSupport() async {
    if (_session == null) {
      return ProtocolSupportResult(isSupported: false, errorMessage: '未连接到终端');
    }

    // 尝试执行 ki version 命令
    // 如果不支持，将返回 "command not found" 或类似错误
    try {
      final output = await _session.inputService.executeCommand(
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
    if (_session == null) {
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
    _session.writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 2. 发送文件元数据
    _session.writeRaw(
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
      _session.writeRaw(
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
    _session.writeRaw(_encoder.createFinishSession(transferId));
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
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final link = Link(localPath);
    if (!await link.exists()) {
      throw Exception('符号链接不存在: $localPath');
    }

    final target = await link.target();
    final fileName = p.basename(localPath);
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    _session.writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 2. 发送符号链接元数据
    _session.writeRaw(
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
    _session.writeRaw(_encoder.createEndData(transferId, fileId));

    // 4. 结束会话
    _session.writeRaw(_encoder.createFinishSession(transferId));

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
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final dir = Directory(localPath);
    if (!await dir.exists()) {
      throw Exception('目录不存在: $localPath');
    }

    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 1. 开始发送会话
    _session.writeRaw(
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
      if (entity is File) {
        final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
        final fileSize = await entity.length();

        _session.writeRaw(
          _encoder.createFileMetadata(
            sessionId: transferId,
            fileId: fileId,
            fileName: remoteEntityPath,
            fileSize: fileSize,
          ),
        );

        final stream = entity.openRead();
        int transferred = 0;
        await for (final chunk in stream) {
          _session.writeRaw(
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
            percent: 0, // 目录传输不计算百分比
            bytesPerSecond: 0,
          ),
        );
      } else if (entity is Directory) {
        final dirId = 'd${DateTime.now().millisecondsSinceEpoch}';
        _session.writeRaw(
          _encoder.createDirectoryMetadata(
            sessionId: transferId,
            fileId: dirId,
            dirName: remoteEntityPath,
          ),
        );

        // 递归处理子目录
        final children = entity.listSync();
        for (final child in children) {
          final childName = p.basename(child.path);
          final childRemotePath = '$remoteEntityPath/$childName';
          await sendEntity(child, childRemotePath);
        }
      } else if (entity is Link) {
        final target = await entity.target();
        final linkId = 'l${DateTime.now().millisecondsSinceEpoch}';
        _session.writeRaw(
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
    _session.writeRaw(
      _encoder.createDirectoryMetadata(
        sessionId: transferId,
        fileId: 'root',
        dirName: remotePath,
      ),
    );

    // 发送所有内容
    final children = dir.listSync();
    for (final child in children) {
      final childName = p.basename(child.path);
      final childRemotePath = '$remotePath/$childName';
      await sendEntity(child, childRemotePath);
    }

    // 结束会话
    _session.writeRaw(_encoder.createFinishSession(transferId));

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
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    final fileId = 'f${DateTime.now().millisecondsSinceEpoch}';
    final transferId = 't${DateTime.now().millisecondsSinceEpoch}';

    // 开始发送会话
    _session.writeRaw(
      _encoder.createSendSession(
        transferId,
        compression: compression,
        bypass: bypass,
        quiet: quiet,
      ),
    );

    // 发送文件元数据（带权限和时间）
    _session.writeRaw(
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
      _session.writeRaw(
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
    _session.writeRaw(_encoder.createFinishSession(transferId));
  }

  /// 取消传输
  Future<void> cancelTransfer(String transferId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    _session.writeRaw(_encoder.createCancelSession(transferId));
  }

  /// 从终端接收文件（接收模式）- 已废弃，使用 downloadFile
  @Deprecated('请使用 downloadFile 方法')
  Future<void> receiveFile(String sessionId, String remotePath) async {
    // 已由 downloadFile 实现
    throw UnimplementedError('请使用 downloadFile 方法');
  }

  /// 清理资源（关闭活动文件流）
  Future<void> dispose() async {
    await _activeDownloadSink?.close();
    _activeDownloadSink = null;
  }
}
