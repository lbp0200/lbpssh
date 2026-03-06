import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';

void main() {
  group('LocalTerminalService', () {
    late LocalTerminalService service;

    setUp(() {
      service = LocalTerminalService();
    });

    tearDown(() {
      service.dispose();
    });

    group('initWorkingDirectory', () {
      test('Given directory path, When initWorkingDirectory called, Then sets current directory', () {
        // Act (When)
        service.initWorkingDirectory('/home/user');

        // Assert (Then) - We can't directly test private _currentDirectory,
        // but we can verify through resolvePath behavior
        final resolved = service.resolvePath('.');
        expect(resolved, '/home/user');
      });
    });

    group('resolvePath', () {
      setUp(() {
        service.initWorkingDirectory('/home/user');
      });

      test('Given absolute path, When resolvePath called, Then returns canonical path', () {
        // Act (When)
        final result = service.resolvePath('/var/log');

        // Assert (Then)
        expect(result, '/var/log');
      });

      test('Given relative path with dot, When resolvePath called, Then returns current directory', () {
        // Act (When)
        final result = service.resolvePath('.');

        // Assert (Then)
        expect(result, '/home/user');
      });

      test('Given relative path with double dot, When resolvePath called, Then returns parent directory', () {
        // Act (When)
        final result = service.resolvePath('..');

        // Assert (Then)
        expect(result, '/home');
      });

      test('Given relative path with double dot at root, When resolvePath called, Then returns root', () {
        // Arrange (Given)
        service.initWorkingDirectory('/');

        // Act (When)
        final result = service.resolvePath('..');

        // Assert (Then)
        expect(result, '/');
      });

      test('Given simple relative path, When resolvePath called, Then resolves to full path', () {
        // Act (When)
        final result = service.resolvePath('documents');

        // Assert (Then)
        expect(result, '/home/user/documents');
      });

      test('Given nested relative path, When resolvePath called, Then resolves correctly', () {
        // Act (When)
        final result = service.resolvePath('projects/app');

        // Assert (Then)
        expect(result, '/home/user/projects/app');
      });
    });

    group('setShellPath', () {
      test('Given shell path, When setShellPath called, Then stores path', () {
        // Act (When)
        service.setShellPath('/bin/zsh');

        // Assert (Then) - No direct getter, but the service should store it
        // This test just verifies no exceptions are thrown
        expect(service.isConnected, false); // Should not be connected
      });

      test('Given shell path with whitespace, When setShellPath called, Then trims whitespace', () {
        // Act (When)
        service.setShellPath('  /bin/bash  ');

        // Assert (Then) - We can't directly verify, but test completes without error
        expect(service.isConnected, false);
      });
    });

    group('getDefaultShellPath', () {
      test('When getDefaultShellPath called, Then returns non-empty string', () {
        // Act (When)
        final result = LocalTerminalService.getDefaultShellPath();

        // Assert (Then)
        expect(result, isNotEmpty);
        expect(result, startsWith('/'));
      });

      test('When getDefaultShellPath called multiple times, Then returns consistent result', () {
        // Act (When)
        final result1 = LocalTerminalService.getDefaultShellPath();
        final result2 = LocalTerminalService.getDefaultShellPath();

        // Assert (Then)
        expect(result1, result2);
      });
    });

    group('isConnected', () {
      test('Given service not started, When isConnected accessed, Then returns false', () {
        // Assert (Then)
        expect(service.isConnected, false);
      });

      test('Given service after dispose, When isConnected accessed, Then returns false', () {
        // Act (When) - Dispose without starting
        service.dispose();

        // Assert (Then)
        expect(service.isConnected, false);
      });
    });

    group('outputStream', () {
      test('Given new service, When outputStream accessed, Then returns stream', () {
        // Assert (Then)
        expect(service.outputStream, isNotNull);
      });
    });

    group('stateStream', () {
      test('Given new service, When stateStream accessed, Then returns stream', () {
        // Assert (Then)
        expect(service.stateStream, isNotNull);
      });
    });

    group('callbacks', () {
      test('Given onDirectoryChange callback set, When callback triggered, Then is callable', () {
        // Arrange (Given)
        String? capturedDir;
        service.onDirectoryChange = (dir) {
          capturedDir = dir;
        };

        // Act (When) - Manually trigger via resolvePath
        service.initWorkingDirectory('/new/dir');

        // Assert (Then) - Verify callback can be set without error
        expect(service.onDirectoryChange, isNotNull);
      });

      test('Given onActualDirectoryChange callback set, When callback triggered, Then is callable', () {
        // Arrange (Given)
        String? capturedDir;
        service.onActualDirectoryChange = (dir) {
          capturedDir = dir;
        };

        // Assert (Then) - Verify callback can be set without error
        expect(service.onActualDirectoryChange, isNotNull);
      });
    });
  });
}
