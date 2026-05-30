import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'terminal_service.dart';

/// 图像位置
enum ImagePlacement {
  any, // 由终端决定
  cursor, // 光标位置
  absolute, // 绝对位置
}

/// 图像数据
class GraphicsImage {
  final int id;
  final String? path;
  final int? width;
  final int? height;
  final int? x;
  final int? y;
  final bool toBuffer;

  GraphicsImage({
    required this.id,
    this.path,
    this.width,
    this.height,
    this.x,
    this.y,
    this.toBuffer = false,
  });
}

/// 图像传输进度
class GraphicsTransferProgress {
  final int imageId;
  final int transmittedBytes;
  final int totalBytes;

  GraphicsTransferProgress({
    required this.imageId,
    required this.transmittedBytes,
    required this.totalBytes,
  });
}

/// 图像回调
typedef GraphicsProgressCallback =
    void Function(GraphicsTransferProgress progress);

/// Graphics Protocol 服务
///
/// 通过终端发送图像控制序列实现图像显示
class KittyGraphicsService {
  final TerminalSession? _session;
  int _nextImageId = 1;
  final Map<int, GraphicsProgressCallback> _progressCallbacks = {};

  KittyGraphicsService({TerminalSession? session}) : _session = session;

  /// 是否已连接
  bool get isConnected => _session != null;

  /// 加载图像
  ///
  /// [imageData] - 图像数据 (PNG/JPEG/GIF/WebP)
  /// [width] - 宽度 (像素或字符)
  /// [height] - 高度 (像素或字符)
  /// [x] - X 坐标
  /// [y] - Y 坐标
  /// [placement] - 位置类型
  /// [onProgress] - 进度回调
  Future<int> loadImage(
    Uint8List imageData, {
    int? width,
    int? height,
    int? x,
    int? y,
    ImagePlacement placement = ImagePlacement.any,
    GraphicsProgressCallback? onProgress,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final imageId = _nextImageId++;
    if (onProgress != null) {
      _progressCallbacks[imageId] = onProgress;
    }

    // 构建图像加载命令
    // 格式: OSC 71 ; a=i ; d=base64_image_data
    final encoded = base64Encode(imageData);

    String cmd = '\x1b]71;a=i;id=$imageId';
    if (width != null) cmd += ';w=$width';
    if (height != null) cmd += ';h=$height';
    if (x != null) cmd += ';x=$x';
    if (y != null) cmd += ';y=$y';
    switch (placement) {
      case ImagePlacement.cursor:
        cmd += ';p=cursor';
        break;
      case ImagePlacement.absolute:
        cmd += ';p=absolute';
        break;
      default:
        break;
    }
    cmd += ';d=$encoded';
    cmd += '\x1b\\';

    _session.writeRaw(cmd);
    return imageId;
  }

  /// 从路径加载图像
  Future<int> loadImageFromPath(
    String path, {
    int? width,
    int? height,
    int? x,
    int? y,
    ImagePlacement placement = ImagePlacement.any,
  }) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    final imageId = _nextImageId++;

    String cmd = '\x1b]71;a=i;id=$imageId';
    if (width != null) cmd += ';w=$width';
    if (height != null) cmd += ';h=$height';
    if (x != null) cmd += ';x=$x';
    if (y != null) cmd += ';y=$y';
    if (placement == ImagePlacement.cursor) {
      cmd += ';p=cursor';
    } else if (placement == ImagePlacement.absolute) {
      cmd += ';p=absolute';
    }
    cmd += ';f=${base64Encode(utf8.encode(path))}';
    cmd += '\x1b\\';

    _session.writeRaw(cmd);
    return imageId;
  }

  /// 删除图像
  Future<void> deleteImage(int imageId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=d ; id=image_id
    final cmd = '\x1b]71;a=d;id=$imageId\x1b\\';
    _session.writeRaw(cmd);
    _progressCallbacks.remove(imageId);
  }

  /// 删除所有图像
  Future<void> deleteAllImages() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=d ; a=*
    final cmd = '\x1b]71;a=d;a=*\x1b\\';
    _session.writeRaw(cmd);
    _progressCallbacks.clear();
  }

  /// 查询图像位置
  Future<void> queryImageLocation(int imageId) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=q ; id=image_id
    final cmd = '\x1b]71;a=q;id=$imageId\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 转储图像到文件
  Future<void> dumpImage(int imageId, String filePath) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=t ; id=image_id ; f=filepath
    final cmd = '\x1b]71;a=t;id=$imageId;f=${base64Encode(utf8.encode(filePath))}\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 移动图像位置
  Future<void> moveImage(int imageId, int x, int y) async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=m ; id=image_id ; x=x ; y=y
    final cmd = '\x1b]71;a=m;id=$imageId;x=$x;y=$y\x1b\\';
    _session.writeRaw(cmd);
  }

  /// 获取图像列表
  Future<void> listImages() async {
    if (_session == null) {
      throw Exception('未连接到终端');
    }

    // 格式: OSC 71 ; a=l
    final cmd = '\x1b]71;a=l\x1b\\';
    _session.writeRaw(cmd);
  }


}
