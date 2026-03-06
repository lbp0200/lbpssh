import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/file_list_parser.dart';
import 'package:lbp_ssh/presentation/screens/sftp_browser_screen.dart';

void main() {
  group('FileListParser', () {
    group('parse', () {
      test(
          'Given valid Linux ls -la output (long-iso format), When parse called, Then returns file items',
          () {
        // Arrange (Given) - Using --time-style=long-iso format: permissions links user group size date time name
        const output = '''total 24
drwxr-xr-x  5 user user 4096 2024-02-24 20:08 dirname
-rw-r--r--  1 user user  1234 2024-02-24 20:08 file.txt
-rw-r--r--  1 user user  5678 2024-01-15 10:30 another-file.log''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items.length, 3); // Excludes . and ..
        expect(items[0].name, 'dirname');
        expect(items[0].isDirectory, true);
        expect(items[0].size, 4096);
        expect(items[1].name, 'file.txt');
        expect(items[1].isDirectory, false);
        expect(items[1].size, 1234);
        expect(items[2].name, 'another-file.log');
        expect(items[2].isDirectory, false);
        expect(items[2].size, 5678);
      });

      test(
          'Given macOS ls -la output, When parse called, Then returns file items',
          () {
        // Arrange (Given)
        const output = '''total 24
drwxr-xr-x   5 user  staff   160 Feb 24 20:08 .
drwxr-xr-x   1 user  staff   160 Feb 24 20:08 ..
drwxr-xr-x   3 user  staff   96 Dec 24 10:30 Documents
-rw-r--r--   1 user  staff  1234 Feb 24 20:08 test.txt''';

        // Act (When)
        final items = FileListParser.parse(output, '/Users/user', osType: 'darwin');

        // Assert (Then)
        expect(items.length, 2);
        expect(items[0].name, 'Documents');
        expect(items[0].isDirectory, true);
        expect(items[1].name, 'test.txt');
        expect(items[1].isDirectory, false);
      });

      test(
          'Given empty output, When parse called, Then returns empty list',
          () {
        // Arrange (Given)
        const output = '';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items, isEmpty);
      });

      test(
          'Given output with only total line, When parse called, Then returns empty list',
          () {
        // Arrange (Given)
        const output = 'total 0';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items, isEmpty);
      });

      test(
          'Given output with whitespace lines, When parse called, Then skips empty lines',
          () {
        // Arrange (Given)
        const output = '''total 24

drwxr-xr-x  5 user user 4096 Feb 24 20:08 dirname

-rw-r--r--  1 user user 1234 Feb 24 20:08 file.txt
''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items.length, 2);
      });

      test(
          'Given filename with spaces, When parse called, Then preserves filename',
          () {
        // Arrange (Given)
        const output = '''total 24
-rw-r--r--  1 user user 1234 Feb 24 20:08 file with spaces.txt
drwxr-xr-x  3 user user 4096 Feb 24 10:30 dir name''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items.length, 2);
        expect(items[0].name, 'file with spaces.txt');
        expect(items[1].name, 'dir name');
      });

      test(
          'Given symlink, When parse called, Then identifies as file (not directory)',
          () {
        // Arrange (Given)
        const output = '''total 8
lrwxrwxrwx  1 user user   24 Feb 24 20:08 link -> target''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items.length, 1);
        expect(items[0].name, 'link -> target');
        expect(items[0].isDirectory, false); // symlink starts with 'l', not 'd'
      });

      test(
          'Given full path construction, When parse called, Then constructs correct full path',
          () {
        // Arrange (Given)
        const output = '''total 8
-rw-r--r--  1 user user 100 Feb 24 20:08 file.txt''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items[0].path, '/home/user/file.txt');
      });

      test(
          'Given root path, When parse called, Then constructs correct full path',
          () {
        // Arrange (Given)
        const output = '''total 8
drwxr-xr-x  2 root root 4096 Feb 24 20:08 etc''';

        // Act (When)
        final items = FileListParser.parse(output, '/');

        // Assert (Then)
        expect(items[0].path, '/etc');
      });
    });

    group('parse with date formats', () {
      test(
          'Given ISO date format (Linux), When parse called, Then parses date correctly',
          () {
        // Arrange (Given)
        const output = '''total 8
-rw-r--r--  1 user user 1234 2024-01-15 10:30 file.txt''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items[0].modified, isNotNull);
        expect(items[0].modified!.year, 2024);
        expect(items[0].modified!.month, 1);
        expect(items[0].modified!.day, 15);
        expect(items[0].modified!.hour, 10);
        expect(items[0].modified!.minute, 30);
      });

      test(
          'Given macOS date format, When parse called, Then parses date correctly',
          () {
        // Arrange (Given)
        const output = '''total 8
-rw-r--r--  1 user staff 1234 Dec 25 14:30 file.txt''';

        // Act (When)
        final items = FileListParser.parse(output, '/Users/user', osType: 'darwin');

        // Assert (Then)
        expect(items[0].modified, isNotNull);
        expect(items[0].modified!.month, 12);
        expect(items[0].modified!.day, 25);
        expect(items[0].modified!.hour, 14);
        expect(items[0].modified!.minute, 30);
      });

      test(
          'Given invalid date format, When parse called, Then returns null for modified',
          () {
        // Arrange (Given)
        const output = '''total 8
-rw-r--r--  1 user user 1234 unknown date file.txt''';

        // Act (When)
        final items = FileListParser.parse(output, '/home/user');

        // Assert (Then)
        expect(items[0].modified, isNull);
      });
    });
  });
}
