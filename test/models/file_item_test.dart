import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/file_item.dart';

void main() {
  group('FileItem', () {
    test(
      'Given required fields, When creating FileItem, Then all fields are set correctly',
      () {
        final item = FileItem(
          name: 'test.txt',
          path: '/home/user/test.txt',
          isDirectory: false,
        );

        expect(item.name, 'test.txt');
        expect(item.path, '/home/user/test.txt');
        expect(item.isDirectory, isFalse);
        expect(item.size, 0);
        expect(item.modified, isNull);
        expect(item.permissions, '');
      },
    );

    test(
      'Given directory, When creating FileItem, Then isDirectory is true',
      () {
        final item = FileItem(
          name: 'folder',
          path: '/home/user/folder',
          isDirectory: true,
        );

        expect(item.isDirectory, isTrue);
      },
    );

    test(
      'Given all fields, When creating FileItem, Then all fields are stored',
      () {
        final now = DateTime(2025, 7, 11, 10, 30);
        final item = FileItem(
          name: 'script.sh',
          path: '/tmp/script.sh',
          isDirectory: false,
          size: 4096,
          modified: now,
          permissions: 'rwxr-xr-x',
        );

        expect(item.name, 'script.sh');
        expect(item.path, '/tmp/script.sh');
        expect(item.isDirectory, isFalse);
        expect(item.size, 4096);
        expect(item.modified, now);
        expect(item.permissions, 'rwxr-xr-x');
      },
    );
  });
}
