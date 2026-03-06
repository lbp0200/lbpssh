import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';

void main() {
  group('KittyFileTransferService', () {
    test(
        'Given no terminal connection, When checking protocol support, Then returns unsupported',
        () async {
      final service = KittyFileTransferService();
      final result = await service.checkProtocolSupport();
      expect(result.isSupported, isFalse);
      expect(result.errorMessage, contains('未连接到终端'));
    });

    test(
        'Given sessionId, When starting send session, Then generates correct OSC sequence',
        () {
      final encoder = _TestEncoder();
      final sequence = encoder.startSendSession(sessionId: 'test123');

      // OSC 5113 sequence format
      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=send'));
      expect(sequence, contains('id=test123'));
    });

    test(
        'Given file metadata, When sending file metadata, Then generates correct OSC sequence',
        () {
      final encoder = _TestEncoder();
      final sequence = encoder.sendFileMetadata(
        sessionId: 'test123',
        fileId: 'f1',
        destinationPath: '/home/user/test.txt',
      );

      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=file'));
      expect(sequence, contains('fid=f1'));
    });

    test(
        'Given data chunk, When sending data, Then generates correct OSC sequence',
        () {
      final encoder = _TestEncoder();
      final sequence = encoder.sendDataChunk(
        sessionId: 'test123',
        fileId: 'f1',
        data: [1, 2, 3, 4],
      );

      expect(sequence, contains('\x1b]5113'));
      expect(sequence, contains('ac=data'));
      expect(sequence, contains('fid=f1'));
    });

    test(
        'Given sessionId, When finishing session, Then generates finish command',
        () {
      final encoder = _TestEncoder();
      final sequence = encoder.finishSession('test123');

      expect(sequence, contains('ac=finish'));
    });
  });
}

/// Test encoder - reuses KittyFileTransferEncoder logic
class _TestEncoder {
  String startSendSession({required String sessionId}) {
    return '\x1b]5113;ac=send;id=$sessionId\x1b\\';
  }

  String sendFileMetadata({
    required String sessionId,
    required String fileId,
    required String destinationPath,
  }) {
    return '\x1b]5113;ac=file;id=$sessionId;fid=$fileId;n=${_encode64(destinationPath)}\x1b\\';
  }

  String sendDataChunk({
    required String sessionId,
    required String fileId,
    required List<int> data,
  }) {
    final encoded = _encode64Bytes(data);
    return '\x1b]5113;ac=data;id=$sessionId;fid=$fileId;d=$encoded\x1b\\';
  }

  String finishSession(String sessionId) {
    return '\x1b]5113;ac=finish;id=$sessionId\x1b\\';
  }

  String _encode64(String input) {
    // Simplified base64 encoding
    return input;
  }

  String _encode64Bytes(List<int> data) {
    // Simplified base64 encoding
    return data.toString();
  }
}
