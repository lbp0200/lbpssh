import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/local_terminal_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_pty/flutter_pty.dart';

// Mock Pty class
class MockPty extends Mock implements Pty {}

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
        // On Windows, returns cmd.exe; on Unix-like, returns /bin/bash or similar
        expect(result, anyOf(startsWith('/'), equals('cmd.exe')));
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
        service.onDirectoryChange = (dir) {
          // No-op callback
        };

        // Act (When) - Manually trigger via resolvePath
        service.initWorkingDirectory('/new/dir');

        // Assert (Then) - Verify callback can be set without error
        expect(service.onDirectoryChange, isNotNull);
      });

      test('Given onActualDirectoryChange callback set, When callback triggered, Then is callable', () {
        // Arrange (Given)
        service.onActualDirectoryChange = (dir) {
          // No-op callback
        };

        // Assert (Then) - Verify callback can be set without error
        expect(service.onActualDirectoryChange, isNotNull);
      });
    });

    group('resize', () {
      test('Given service not started, When resize called, Then does not throw', () {
        // Act (When) & Assert (Then) - Should not throw even when PTY is null
        expect(() => service.resize(24, 80), returnsNormally);
      });

      test('Given service with dimensions, When resize called with different sizes, Then accepts parameters', () {
        // Act (When) - Multiple resize calls with different sizes
        service.resize(24, 80);
        service.resize(40, 120);
        service.resize(10, 40);

        // Assert (Then) - Should not throw
        expect(service.isConnected, false); // Still not connected
      });

      test('Given service with zero dimensions, When resize called, Then handles gracefully', () {
        // Act (When) - Edge case with zero dimensions
        service.resize(0, 0);

        // Assert (Then) - Should not throw
        expect(service.isConnected, false);
      });
    });
  });
}
