import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart' show TestWidgetsFlutterBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';
import 'package:lbp_ssh/domain/services/terminal_input_service.dart';
import 'package:lbp_ssh/domain/services/ssh_service.dart';
import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';

// ---------------------------------------------------------------------------
// Fakes / Mocks for kterm types
// ---------------------------------------------------------------------------

class FakeTerminal extends Fake implements Terminal {}

class FakeTerminalController extends Fake implements TerminalController {}

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockTerminalSession extends Mock implements TerminalSession {}

class MockSftpClient extends Mock implements SftpClient {}

class MockTerminalInputService extends Mock implements TerminalInputService {}

/// A concrete TerminalInputService stub for tests that need to return canned
/// command responses without triggering mocktail stub-chaining issues.
class StubTerminalInputService implements TerminalInputService {
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  Future<String> Function(String command, {bool silent})? executeCommandImpl;

  @override
  Stream<String> get outputStream => _outputController.stream;

  @override
  Stream<bool> get stateStream => _stateController.stream;

  @override
  Future<String> executeCommand(String command, {bool silent = false}) async {
    if (executeCommandImpl != null) {
      return executeCommandImpl!(command, silent: silent);
    }
    return '';
  }

  @override
  void sendInput(String input) {}

  @override
  void resize(int rows, int columns) {}

  @override
  void dispose() {
    _outputController.close();
    _stateController.close();
  }
}

class MockSshService extends Mock implements SshService {}

// ---------------------------------------------------------------------------
// Fake values for mocktail
// ---------------------------------------------------------------------------

class FakeSftpName extends Fake implements SftpName {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(<int>[]);
    registerFallbackValue(MockTerminalSession());
    registerFallbackValue(MockSftpClient());
    registerFallbackValue(MockTerminalInputService());
    registerFallbackValue(FakeSftpName());
  });

  // ==========================================================================
  // KittyFileTransferEncoder Tests (pure logic)
  // ==========================================================================
  group('KittyFileTransferEncoder', () {
    late KittyFileTransferEncoder encoder;

    setUp(() {
      encoder = KittyFileTransferEncoder();
    });

    // -------------------------------------------------------------------------
    // encodeFileName
    // -------------------------------------------------------------------------
    group('encodeFileName', () {
      test(
          'Given simple filename, When encoding, Then returns base64 encoded string',
          () {
        final result = encoder.encodeFileName('test.txt');
        expect(result, base64Encode(utf8.encode('test.txt')));
      });

      test(
          'Given filename with unicode characters, When encoding, Then returns base64 encoded string',
          () {
        final result = encoder.encodeFileName('文件.txt');
        expect(result, base64Encode(utf8.encode('文件.txt')));
      });
    });

    // -------------------------------------------------------------------------
    // createSendSession
    // -------------------------------------------------------------------------
    group('createSendSession', () {
      test(
          'Given sessionId, When creating send session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createSendSession('test123');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=send'));
        expect(sequence, contains('id=test123'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given sessionId with zlib compression, When creating send session, Then includes compression',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          compression: CompressionType.zlib,
        );

        expect(sequence, contains('zip=zlib'));
      });

      test(
          'Given sessionId with bypass password, When creating send session, Then includes password',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          bypass: 'secret',
        );

        expect(sequence, contains('pw=secret'));
      });

      test(
          'Given quiet mode > 0, When creating send session, Then includes quiet parameter',
          () {
        final sequence = encoder.createSendSession(
          'test123',
          quiet: 2,
        );

        expect(sequence, contains('q=2'));
      });
    });

    // -------------------------------------------------------------------------
    // createReceiveSession
    // -------------------------------------------------------------------------
    group('createReceiveSession', () {
      test(
          'Given sessionId, When creating receive session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createReceiveSession('test123');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=recv'));
        expect(sequence, contains('id=test123'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given sessionId with compression and bypass, When creating receive session, Then includes all params',
          () {
        final sequence = encoder.createReceiveSession(
          'test123',
          compression: CompressionType.zlib,
          bypass: 'mypw',
          quiet: 1,
        );

        expect(sequence, contains('zip=zlib'));
        expect(sequence, contains('pw=mypw'));
        expect(sequence, contains('q=1'));
      });
    });

    // -------------------------------------------------------------------------
    // createFileMetadata
    // -------------------------------------------------------------------------
    group('createFileMetadata', () {
      test(
          'Given required params, When creating file metadata, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=file'));
        expect(sequence, contains('id=s1'));
        expect(sequence, contains('fid=f1'));
        expect(sequence, contains('size=1024'));
        // name is base64 encoded
        expect(
            sequence, contains('n=${base64Encode(utf8.encode('test.txt'))}'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given fileType directory, When creating file metadata, Then includes ft=directory',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'mydir',
          fileSize: 4096,
          fileType: FileType.directory,
        );

        expect(sequence, contains('ft=directory'));
      });

      test(
          'Given fileType symlink with linkTarget, When creating file metadata, Then includes ft=symlink and encoded target',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'link',
          fileSize: 0,
          fileType: FileType.symlink,
          linkTarget: '/real/target',
        );

        expect(sequence, contains('ft=symlink'));
        // linkTarget replaces n= with base64 of target
        expect(sequence,
            contains('n=${base64Encode(utf8.encode('/real/target'))}'));
      });

      test(
          'Given fileType link, When creating file metadata, Then includes ft=link',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'hardlink',
          fileSize: 1024,
          fileType: FileType.link,
        );

        expect(sequence, contains('ft=link'));
      });

      test(
          'Given transmissionType rsync, When creating file metadata, Then includes tt=rsync',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
          transmissionType: TransmissionType.rsync,
        );

        expect(sequence, contains('tt=rsync'));
      });

      test(
          'Given permissions, When creating file metadata, Then includes prm parameter',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
          permissions: 420, // 0o644
        );

        expect(sequence, contains('prm=420'));
      });

      test(
          'Given mtime, When creating file metadata, Then includes mod parameter',
          () {
        final sequence = encoder.createFileMetadata(
          sessionId: 's1',
          fileId: 'f1',
          fileName: 'test.txt',
          fileSize: 1024,
          mtime: 1708800000000000000,
        );

        expect(sequence, contains('mod=1708800000000000000'));
      });
    });

    // -------------------------------------------------------------------------
    // createDirectoryMetadata
    // -------------------------------------------------------------------------
    group('createDirectoryMetadata', () {
      test(
          'Given required params, When creating directory metadata, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createDirectoryMetadata(
          sessionId: 's1',
          fileId: 'd1',
          dirName: 'mydir',
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=file'));
        expect(sequence, contains('ft=directory'));
        expect(sequence, contains('id=s1'));
        expect(sequence, contains('fid=d1'));
        expect(sequence, contains('n=${base64Encode(utf8.encode('mydir'))}'));
      });

      test(
          'Given permissions and mtime, When creating directory metadata, Then includes optional params',
          () {
        final sequence = encoder.createDirectoryMetadata(
          sessionId: 's1',
          fileId: 'd1',
          dirName: 'mydir',
          permissions: 493, // 0o755
          mtime: 1708800000000000000,
        );

        expect(sequence, contains('prm=493'));
        expect(sequence, contains('mod=1708800000000000000'));
      });
    });

    // -------------------------------------------------------------------------
    // createDataChunk
    // -------------------------------------------------------------------------
    group('createDataChunk', () {
      test(
          'Given required params, When creating data chunk, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createDataChunk(
          sessionId: 's1',
          fileId: 'f1',
          data: [1, 2, 3, 4],
        );

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=data'));
        expect(sequence, contains('id=s1'));
        expect(sequence, contains('fid=f1'));
        expect(sequence, contains('d=${base64Encode([1, 2, 3, 4])}'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given empty data, When creating data chunk, Then encodes empty base64 string',
          () {
        final sequence = encoder.createDataChunk(
          sessionId: 's1',
          fileId: 'f1',
          data: [],
        );

        expect(sequence, contains('d='));
        expect(sequence, contains('ac=data'));
      });
    });

    // -------------------------------------------------------------------------
    // createEndData
    // -------------------------------------------------------------------------
    group('createEndData', () {
      test(
          'Given sessionId and fileId without data, When creating end data, Then generates correct sequence',
          () {
        final sequence = encoder.createEndData('s1', 'f1');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=end_data'));
        expect(sequence, contains('id=s1'));
        expect(sequence, contains('fid=f1'));
        expect(sequence, endsWith('\x1b\\'));
      });

      test(
          'Given sessionId, fileId, and data, When creating end data, Then includes encoded data',
          () {
        final sequence = encoder.createEndData('s1', 'f1', data: [1, 2, 3]);

        expect(sequence, contains('d=${base64Encode([1, 2, 3])}'));
      });
    });

    // -------------------------------------------------------------------------
    // createFinishSession
    // -------------------------------------------------------------------------
    group('createFinishSession', () {
      test(
          'Given sessionId, When creating finish session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createFinishSession('test123');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=finish'));
        expect(sequence, contains('id=test123'));
        expect(sequence, endsWith('\x1b\\'));
      });
    });

    // -------------------------------------------------------------------------
    // createCancelSession
    // -------------------------------------------------------------------------
    group('createCancelSession', () {
      test(
          'Given sessionId, When creating cancel session, Then generates correct OSC sequence',
          () {
        final sequence = encoder.createCancelSession('test123');

        expect(sequence, contains('\x1b]5113'));
        expect(sequence, contains('ac=cancel'));
        expect(sequence, contains('id=test123'));
        expect(sequence, endsWith('\x1b\\'));
      });
    });

    // -------------------------------------------------------------------------
    // parseStatusResponse
    // -------------------------------------------------------------------------
    group('parseStatusResponse', () {
      test(
          'Given OK status without message, When parsing, Then returns TransferStatus with isOk true',
          () {
        const response = 'ac=status;id=test123;st=OK';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isTrue);
        expect(result.sessionId, 'test123');
        expect(result.errorMessage, isNull);
        expect(result.size, isNull);
      });

      test(
          'Given OK status with message, When parsing, Then returns TransferStatus with message',
          () {
        const response = 'ac=status;id=test123;st=OK:Transfer complete';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isTrue);
        expect(result.errorMessage, 'Transfer complete');
      });

      test(
          'Given OK status with size, When parsing, Then extracts size',
          () {
        const response = 'ac=status;id=test123;st=OK;sz=1024';
        final result = encoder.parseStatusResponse(response);

        expect(result!.isOk, isTrue);
        expect(result.size, 1024);
      });

      test(
          'Given OK status with message and size, When parsing, Then returns all fields',
          () {
        const response = 'ac=status;id=session1;st=OK:Done;sz=2048';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isTrue);
        expect(result.sessionId, 'session1');
        expect(result.errorMessage, 'Done;sz=2048');
        expect(result.size, 2048);
      });

      test(
          'Given ERROR status, When parsing, Then returns TransferStatus with isOk false and errorMessage',
          () {
        const response = 'ac=status;id=test123;st=ERROR:File not found';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNotNull);
        expect(result!.isOk, isFalse);
        expect(result.sessionId, 'test123');
        expect(result.errorMessage, 'File not found');
      });

      test(
          'Given invalid response format, When parsing, Then returns null',
          () {
        const response = 'not a status response';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNull);
      });

      test(
          'Given empty string, When parsing, Then returns null',
          () {
        const response = '';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNull);
      });

      test(
          'Given partial match response, When parsing, Then returns null',
          () {
        const response = 'ac=status;';
        final result = encoder.parseStatusResponse(response);

        expect(result, isNull);
      });
    });
  });

  // ==========================================================================
  // KittyFileTransferService Tests
  // ==========================================================================
  group('KittyFileTransferService', () {
    // -------------------------------------------------------------------------
    // Properties (no session)
    // -------------------------------------------------------------------------
    group('properties without session', () {
      test(
          'Given no terminal connection, When accessing isConnected, Then returns false',
          () {
        final service = KittyFileTransferService();
        expect(service.isConnected, isFalse);
      });

      test(
          'Given no terminal connection, When accessing supportsKittyProtocol, Then returns false',
          () {
        final service = KittyFileTransferService();
        expect(service.supportsKittyProtocol, isFalse);
      });

      test(
          'Given initial path, When creating service, Then sets currentPath',
          () {
        final service = KittyFileTransferService(initialPath: '/home/user');
        expect(service.currentPath, '/home/user');
      });

      test(
          'Given default initial path, When creating service, Then currentPath is /',
          () {
        final service = KittyFileTransferService();
        expect(service.currentPath, '/');
      });
    });

    // -------------------------------------------------------------------------
    // listCurrentDirectory - throws when no session
    // -------------------------------------------------------------------------
    group('listCurrentDirectory throws when no session', () {
      test(
          'Given no terminal connection, When listCurrentDirectory called, Then throws Exception',
          () {
        final service = KittyFileTransferService();

        expect(
          () => service.listCurrentDirectory(),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // listCurrentDirectory - with session, shell fallback (no SFTP)
    // -------------------------------------------------------------------------
    group('listCurrentDirectory with shell fallback', () {
      late MockTerminalSession mockSession;
      late MockTerminalInputService mockInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        mockInputService = MockTerminalInputService();
        when(() => mockSession.inputService).thenReturn(mockInputService);
      });

      test(
          'Given shell fallback (inputService not SshService), When listCurrentDirectory called, Then uses shell ls',
          () async {
        // inputService is NOT an SshService -> no SFTP -> shell fallback
        when(() => mockInputService.executeCommand(
              any(),
              silent: any(named: 'silent'),
            )).thenAnswer(
          (_) async => '''total 12
drwxr-xr-x  2 user user 4096 2024-02-24 20:08 dir1
-rw-r--r--  1 user user 1024 2024-02-24 20:08 file1.txt''',
        );

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        final items = await service.listCurrentDirectory();

        expect(items.length, 2);
        expect(items[0].name, 'dir1');
        expect(items[0].isDirectory, true);
        expect(items[1].name, 'file1.txt');
        expect(items[1].isDirectory, false);
        expect(items[1].size, 1024);
      });

      test(
          'Given shell fallback, When listCurrentDirectory called, Then parses ls output correctly',
          () async {
        when(() => mockInputService.executeCommand(
              any(),
              silent: any(named: 'silent'),
            )).thenAnswer(
          (_) async =>
              'total 4\ndrwxr-xr-x  1 user user 4096 2024-01-01 12:00 mydir',
        );

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/tmp',
        );

        final items = await service.listCurrentDirectory();

        expect(items.length, 1);
        expect(items[0].name, 'mydir');
        expect(items[0].isDirectory, true);
      });
    });

    // -------------------------------------------------------------------------
    // changeDirectory - throws when no session
    // -------------------------------------------------------------------------
    group('changeDirectory throws when no session', () {
      test(
          'Given no terminal connection, When changeDirectory called, Then throws Exception',
          () {
        final service = KittyFileTransferService();

        expect(
          () => service.changeDirectory('/home'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // changeDirectory - with session
    // -------------------------------------------------------------------------
    group('changeDirectory with session', () {
      late MockTerminalSession mockSession;

      setUp(() {
        mockSession = MockTerminalSession();
        when(() => mockSession.inputService)
            .thenReturn(StubTerminalInputService());
      });

      test(
          'Given absolute path, When changeDirectory called, Then updates currentPath',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.changeDirectory('/var/log');

        expect(service.currentPath, '/var/log');
      });

      test(
          'Given relative path, When changeDirectory called, Then resolves to absolute path',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.changeDirectory('projects');

        expect(service.currentPath, '/home/user/projects');
      });

      test(
          'Given relative path from root, When changeDirectory called, Then resolves correctly',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/',
        );

        await service.changeDirectory('etc');

        expect(service.currentPath, '/etc');
      });
    });

    // -------------------------------------------------------------------------
    // goUp - throws when no session
    // -------------------------------------------------------------------------
    group('goUp throws when no session', () {
      test(
          'Given no terminal connection, When goUp called, Then throws Exception',
          () {
        final service = KittyFileTransferService();

        expect(
          () => service.goUp(),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // goUp - with session
    // -------------------------------------------------------------------------
    group('goUp with session', () {
      late MockTerminalSession mockSession;

      setUp(() {
        mockSession = MockTerminalSession();
        when(() => mockSession.inputService)
            .thenReturn(StubTerminalInputService());
      });

      test(
          'Given path with multiple segments, When goUp called, Then removes last segment',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user/projects',
        );

        await service.goUp();

        expect(service.currentPath, '/home/user');
      });

      test(
          'Given single segment path, When goUp called, Then goes to /',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home',
        );

        await service.goUp();

        expect(service.currentPath, '/');
      });

      test(
          'Given root path, When goUp called, Then stays at /',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/',
        );

        await service.goUp();

        expect(service.currentPath, '/');
      });
    });

    // -------------------------------------------------------------------------
    // createDirectory - throws when no session (and no SFTP)
    // -------------------------------------------------------------------------
    group('createDirectory throws when no session', () {
      test(
          'Given no session, When createDirectory called, Then throws Exception',
          () async {
        final service = KittyFileTransferService();

        await expectLater(
          service.createDirectory('newdir'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // createDirectory - shell fallback
    // -------------------------------------------------------------------------
    group('createDirectory with shell fallback', () {
      late MockTerminalSession mockSession;
      late MockTerminalInputService mockInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        mockInputService = MockTerminalInputService();
        when(() => mockSession.inputService).thenReturn(mockInputService);
      });

      test(
          'Given shell fallback (no SFTP), When createDirectory called, Then executes mkdir',
          () async {
        // inputService is not SshService -> fallback to shell
        when(() => mockSession.executeCommand(any())).thenAnswer((_) async {});

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.createDirectory('newdir');

        verify(() => mockSession.executeCommand('mkdir "/home/user/newdir"'))
            .called(1);
      });
    });

    // -------------------------------------------------------------------------
    // removeFile - throws when no session (and no SFTP)
    // -------------------------------------------------------------------------
    group('removeFile throws when no session', () {
      test(
          'Given no session, When removeFile called, Then throws Exception',
          () async {
        final service = KittyFileTransferService();

        await expectLater(
          service.removeFile('/home/user/file.txt'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // removeFile - shell fallback
    // -------------------------------------------------------------------------
    group('removeFile with shell fallback', () {
      late MockTerminalSession mockSession;
      late MockTerminalInputService mockInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        mockInputService = MockTerminalInputService();
        when(() => mockSession.inputService).thenReturn(mockInputService);
      });

      test(
          'Given shell fallback, When removeFile called, Then executes rm command',
          () async {
        when(() => mockSession.executeCommand(any())).thenAnswer((_) async {});

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.removeFile('/home/user/file.txt');

        verify(() => mockSession.executeCommand('rm "/home/user/file.txt"'))
            .called(1);
      });
    });

    // -------------------------------------------------------------------------
    // removeDirectory - throws when no session
    // -------------------------------------------------------------------------
    group('removeDirectory throws when no session', () {
      test(
          'Given no session, When removeDirectory called, Then throws Exception',
          () async {
        final service = KittyFileTransferService();

        await expectLater(
          service.removeDirectory('/home/user/mydir'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // removeDirectory - shell fallback
    // -------------------------------------------------------------------------
    group('removeDirectory with shell fallback', () {
      late MockTerminalSession mockSession;
      late MockTerminalInputService mockInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        mockInputService = MockTerminalInputService();
        when(() => mockSession.inputService).thenReturn(mockInputService);
      });

      test(
          'Given shell fallback, When removeDirectory called, Then executes rmdir command',
          () async {
        when(() => mockSession.executeCommand(any())).thenAnswer((_) async {});

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.removeDirectory('/home/user/mydir');

        verify(() => mockSession.executeCommand('rmdir "/home/user/mydir"'))
            .called(1);
      });
    });

    // -------------------------------------------------------------------------
    // downloadFile - throws when no session
    // -------------------------------------------------------------------------
    group('downloadFile throws when no session', () {
      test(
          'Given no terminal connection, When downloadFile called, Then throws Exception',
          () {
        final service = KittyFileTransferService();

        expect(
          () => service.downloadFile('/remote/file.txt', '/tmp/file.txt'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // downloadFile - with session
    // -------------------------------------------------------------------------
    group('downloadFile with session', () {
      late MockTerminalSession mockSession;
      late MockTerminalInputService mockInputService;
      late StreamController<FileTransferEvent> fileTransferController;
      late Directory tempDir;

      setUp(() async {
        mockSession = MockTerminalSession();
        mockInputService = MockTerminalInputService();
        fileTransferController =
            StreamController<FileTransferEvent>.broadcast();

        when(() => mockSession.inputService).thenReturn(mockInputService);
        when(() => mockSession.fileTransferStream)
            .thenAnswer((_) => fileTransferController.stream);
        when(() => mockSession.writeRaw(any())).thenReturn(null);

        tempDir = await Directory.systemTemp.createTemp('kitty_test_');
      });

      tearDown(() async {
        await fileTransferController.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
          'Given session with fileTransferStream, When downloadFile called, Then sends recv OSC sequence',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        // Start the download; it will timeout since we never emit 'end'
        final downloadFuture =
            service.downloadFile('/remote/file.txt', '${tempDir.path}/downloaded.txt');

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify recv OSC sequence was written
        verify(() => mockSession.writeRaw(
            any(that: contains('ac=recv')))).called(1);

        // Cancel the completer by closing the stream
        await fileTransferController.close();
        try {
          await downloadFuture.timeout(const Duration(seconds: 1));
        } catch (_) {
          // Expected to timeout since 'end' event never fires
        }
      });
    });

    // -------------------------------------------------------------------------
    // sendFile - throws when no session
    // -------------------------------------------------------------------------
    group('sendFile throws when no session', () {
      test(
          'Given no terminal connection, When sendFile called, Then throws Exception',
          () {
        final service = KittyFileTransferService();
        final progress = _mockProgressCallback();

        expect(
          () => service.sendFile(
            localPath: '/tmp/file.txt',
            remoteFileName: 'file.txt',
            onProgress: progress,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendFile - protocol not supported
    // -------------------------------------------------------------------------
    group('sendFile protocol not supported', () {
      late MockTerminalSession mockSession;
      late StubTerminalInputService stubInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        stubInputService = StubTerminalInputService();
        stubInputService.executeCommandImpl =
            (command, {bool silent = false}) async {
          return 'bash: ki: command not found';
        };
        when(() => mockSession.inputService).thenReturn(stubInputService);
      });

      test(
          'Given ki version returns unknown output, When sendFile called, Then throws with not supported message',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );
        final progress = _mockProgressCallback();

        await expectLater(
          service.sendFile(
            localPath: '/tmp/nonexistent.txt',
            remoteFileName: 'file.txt',
            onProgress: progress,
          ),
          throwsA(
            predicate<Exception>((e) =>
                e.toString().contains('不支持') ||
                e.toString().contains('not supported')),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendSymlink - throws when no session
    // -------------------------------------------------------------------------
    group('sendSymlink throws when no session', () {
      test(
          'Given no terminal connection, When sendSymlink called, Then throws Exception',
          () {
        final service = KittyFileTransferService();
        final progress = _mockProgressCallback();

        expect(
          () => service.sendSymlink(
            localPath: '/tmp/mylink',
            remoteFileName: 'mylink',
            onProgress: progress,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendSymlink - with session
    // -------------------------------------------------------------------------
    group('sendSymlink with session', () {
      late MockTerminalSession mockSession;
      late Directory tempDir;
      late Link tempLink;

      setUp(() async {
        mockSession = MockTerminalSession();
        when(() => mockSession.inputService)
            .thenReturn(StubTerminalInputService());
        when(() => mockSession.writeRaw(any())).thenReturn(null);

        tempDir = await Directory.systemTemp.createTemp('kitty_symlink_test_');
        tempLink =
            await Link('${tempDir.path}/mylink').create('${tempDir.path}/target');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
          'Given session and valid symlink, When sendSymlink called, Then writes symlink metadata',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );
        final progress = _mockProgressCallback();

        await service.sendSymlink(
          localPath: tempLink.path,
          remoteFileName: 'mylink',
          onProgress: progress,
        );

        verify(() => mockSession.writeRaw(
            any(that: contains('ac=send')))).called(1);
        verify(() => mockSession.writeRaw(
            any(that: contains('ft=symlink')))).called(1);
        verify(() => mockSession.writeRaw(
            any(that: contains('ac=end_data')))).called(1);
        verify(() => mockSession.writeRaw(
            any(that: contains('ac=finish')))).called(1);
      });

      test(
          'Given nonexistent symlink path, When sendSymlink called, Then throws Exception',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );
        final progress = _mockProgressCallback();

        await expectLater(
          service.sendSymlink(
            localPath: '/tmp/nonexistent_link_xyz',
            remoteFileName: 'bad',
            onProgress: progress,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendDirectory - throws when no session
    // -------------------------------------------------------------------------
    group('sendDirectory throws when no session', () {
      test(
          'Given no terminal connection, When sendDirectory called, Then throws Exception',
          () {
        final service = KittyFileTransferService();
        final progress = _mockProgressCallback();

        expect(
          () => service.sendDirectory(
            localPath: '/tmp/mydir',
            remotePath: '/home/user/mydir',
            onProgress: progress,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendDirectory - with session
    // -------------------------------------------------------------------------
    group('sendDirectory with session', () {
      late MockTerminalSession mockSession;
      late Directory tempDir;

      setUp(() async {
        mockSession = MockTerminalSession();
        when(() => mockSession.inputService)
            .thenReturn(StubTerminalInputService());
        when(() => mockSession.writeRaw(any())).thenReturn(null);

        tempDir = await Directory.systemTemp.createTemp('kitty_dir_test_');
        await Directory('${tempDir.path}/subdir').create();
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
          'Given session and valid directory, When sendDirectory called, Then writes directory metadata',
          () async {
        final dirName = tempDir.path.split('/').last;
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );
        final progress = _mockProgressCallback();

        await service.sendDirectory(
          localPath: tempDir.path,
          remotePath: '/home/user/$dirName',
          onProgress: progress,
        );

        verify(() => mockSession.writeRaw(
            any(that: contains('ac=send')))).called(1);
        verify(() => mockSession.writeRaw(
            any(that: contains('ft=directory')))).called(greaterThanOrEqualTo(1));
        verify(() => mockSession.writeRaw(
            any(that: contains('ac=finish')))).called(1);
      });

      test(
          'Given nonexistent directory path, When sendDirectory called, Then throws Exception',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );
        final progress = _mockProgressCallback();

        await expectLater(
          service.sendDirectory(
            localPath: '/tmp/nonexistent_dir_xyz_abc',
            remotePath: '/home/user/nonexistent',
            onProgress: progress,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // sendFileWithMetadata - throws when no session
    // -------------------------------------------------------------------------
    group('sendFileWithMetadata throws when no session', () {
      test(
          'Given no terminal connection, When sendFileWithMetadata called, Then throws Exception',
          () {
        final service = KittyFileTransferService();
        final progress = _mockProgressCallback();

        expect(
          () => service.sendFileWithMetadata(
            localPath: '/tmp/file.txt',
            remoteFileName: 'file.txt',
            onProgress: progress,
            permissions: 420,
            mtime: 1708800000000000000,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // cancelTransfer - throws when no session
    // -------------------------------------------------------------------------
    group('cancelTransfer throws when no session', () {
      test(
          'Given no terminal connection, When cancelTransfer called, Then throws Exception',
          () {
        final service = KittyFileTransferService();

        expect(
          () => service.cancelTransfer('transfer123'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // cancelTransfer - with session
    // -------------------------------------------------------------------------
    group('cancelTransfer with session', () {
      late MockTerminalSession mockSession;

      setUp(() {
        mockSession = MockTerminalSession();
        when(() => mockSession.inputService)
            .thenReturn(StubTerminalInputService());
        when(() => mockSession.writeRaw(any())).thenReturn(null);
      });

      test(
          'Given session, When cancelTransfer called, Then writes cancel sequence',
          () async {
        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        await service.cancelTransfer('transfer123');

        verify(() => mockSession.writeRaw(
            any(that: allOf(contains('ac=cancel'), contains('id=transfer123'))))).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // checkProtocolSupport - throws when no session
    // -------------------------------------------------------------------------
    group('checkProtocolSupport throws when no session', () {
      test(
          'Given no terminal connection, When checkProtocolSupport called, Then returns unsupported result',
          () async {
        final service = KittyFileTransferService();
        final result = await service.checkProtocolSupport();

        expect(result.isSupported, isFalse);
        expect(result.errorMessage, contains('未连接到终端'));
      });
    });

    // -------------------------------------------------------------------------
    // checkProtocolSupport - with session
    // -------------------------------------------------------------------------
    group('checkProtocolSupport with session', () {
      late MockTerminalSession mockSession;
      late StubTerminalInputService stubInputService;

      setUp(() {
        mockSession = MockTerminalSession();
        stubInputService = StubTerminalInputService();
        when(() => mockSession.inputService).thenReturn(stubInputService);
      });

      test(
          'Given ki version returns version info, When checkProtocolSupport called, Then returns supported',
          () async {
        stubInputService.executeCommandImpl =
            (command, {bool silent = false}) async {
          return 'kitty File Transfer 1.0';
        };

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        final result = await service.checkProtocolSupport();

        expect(result.isSupported, isTrue);
        expect(result.errorMessage, isNull);
      });

      test(
          'Given ki version not found, When checkProtocolSupport called, Then returns not supported',
          () async {
        stubInputService.executeCommandImpl =
            (command, {bool silent = false}) async {
          return 'bash: ki: command not found';
        };

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        final result = await service.checkProtocolSupport();

        expect(result.isSupported, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test(
          'Given ki version throws exception, When checkProtocolSupport called, Then returns not supported',
          () async {
        stubInputService.executeCommandImpl =
            (command, {bool silent = false}) async {
          throw Exception('connection error');
        };

        final service = KittyFileTransferService(
          session: mockSession,
          initialPath: '/home/user',
        );

        final result = await service.checkProtocolSupport();

        expect(result.isSupported, isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

TransferProgressCallback _mockProgressCallback() {
  return (TransferProgress progress) {
    // No-op callback for tests that verify the method runs without error
  };
}
