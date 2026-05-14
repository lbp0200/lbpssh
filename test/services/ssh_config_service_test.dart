import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import 'package:lbp_ssh/domain/services/ssh_config_service.dart';

void main() {
  group('SshConfigEntry', () {
    group('parse', () {
      test(
        'Given valid SSH config content, When parsing, Then returns correct entries',
        () {
          const config = '''
Host server1
    HostName 192.168.1.1
    User admin
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host server2
    HostName server2.example.com
    User ubuntu
    Port 2222
''';

          final entries = SshConfigEntry.parse(config);

          expect(entries.length, 2);
          expect(entries[0].hostName, 'server1');
          expect(entries[0].actualHost, '192.168.1.1');
          expect(entries[0].user, 'admin');
          expect(entries[0].port, 22);
          expect(entries[0].identityFiles, isNotNull);
          expect(entries[0].identityFiles!.first, contains('id_rsa'));

          expect(entries[1].hostName, 'server2');
          expect(entries[1].actualHost, 'server2.example.com');
          expect(entries[1].user, 'ubuntu');
          expect(entries[1].port, 2222);
        },
      );

      test(
        'Given empty config content, When parsing, Then returns empty list',
        () {
          const config = '';

          final entries = SshConfigEntry.parse(config);

          expect(entries, isEmpty);
        },
      );

      test(
        'Given config with comments and empty lines, When parsing, Then skips them',
        () {
          const config = '''
# This is a comment

Host server1
    # Another comment
    HostName 192.168.1.1
    User admin

    # Empty line above
Host server2
    HostName server2.example.com
''';

          final entries = SshConfigEntry.parse(config);

          expect(entries.length, 2);
          expect(entries[0].hostName, 'server1');
          expect(entries[1].hostName, 'server2');
        },
      );

      test(
        'Given config with IdentityOnly, When parsing, Then sets identityOnly correctly',
        () {
          const config = '''
Host keyonly
    HostName 192.168.1.1
    User admin
    IdentityOnly yes
''';

          final entries = SshConfigEntry.parse(config);

          expect(entries.length, 1);
          expect(entries[0].identityOnly, isTrue);
        },
      );

      test(
        'Given config with ProxyCommand, When parsing, Then parses proxy command',
        () {
          const config = '''
Host jump
    HostName jump.example.com
    ProxyCommand ssh -W %h:%p jumphost
''';

          final entries = SshConfigEntry.parse(config);

          expect(entries.length, 1);
          expect(entries[0].proxyCommand, contains('ssh -W'));
        },
      );

      test(
        'Given config with multiple IdentityFiles, When parsing, Then parses all files',
        () {
          const config = '''
Host multi
    HostName 192.168.1.1
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_ecdsa
''';

          final entries = SshConfigEntry.parse(config);

          expect(entries.length, 1);
          expect(entries[0].identityFiles!.length, 3);
        },
      );
    });

    group('getConnectHost', () {
      test(
        'Given entry with actualHost, When getConnectHost called, Then returns actualHost',
        () {
          final entry = SshConfigEntry(
            hostName: 'alias',
            actualHost: '192.168.1.1',
          );

          expect(entry.getConnectHost(), '192.168.1.1');
        },
      );

      test(
        'Given entry without actualHost, When getConnectHost called, Then returns hostName',
        () {
          final entry = SshConfigEntry(hostName: 'server1');

          expect(entry.getConnectHost(), 'server1');
        },
      );
    });
  });

  group('SshConfigService', () {
    group('getDefaultConfigPath', () {
      test(
        'When getDefaultConfigPath called, Then returns path with .ssh/config',
        () {
          final path = SshConfigService.getDefaultConfigPath();

          expect(path, contains('.ssh'));
          expect(path, contains('config'));
        },
      );
    });

    group('readConfigFile', () {
      test(
        'Given non-existent file path, When reading config, Then returns empty list',
        () {
          final entries = SshConfigService.readConfigFile(
            filePath: '/nonexistent/config/file',
          );

          expect(entries, isEmpty);
        },
      );

      test(
        'Given existing file with valid config, When reading config, Then returns parsed entries',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host myserver
    HostName 10.0.0.1
    User testuser
    Port 2222
''');

          final entries = SshConfigService.readConfigFile(
            filePath: configFile.path,
          );

          expect(entries.length, 1);
          expect(entries[0].hostName, 'myserver');
          expect(entries[0].actualHost, '10.0.0.1');
        },
      );

      test(
        'Given directory path instead of file, When reading config, Then returns empty list (catch block)',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          // Passing a directory path causes readAsStringSync to throw FileSystemException
          final entries = SshConfigService.readConfigFile(
            filePath: tempDir.path,
          );

          expect(entries, isEmpty);
        },
      );

      test(
        'Given unreadable file, When reading config, Then returns empty list (catch block)',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('Host test\n    HostName 10.0.0.1\n');
          // Make file unreadable to trigger a readAsStringSync exception
          Process.runSync('chmod', ['000', configFile.path]);

          final entries = SshConfigService.readConfigFile(
            filePath: configFile.path,
          );

          // Reset permissions so temp directory can be cleaned up
          Process.runSync('chmod', ['644', configFile.path]);
          expect(entries, isEmpty);
        },
      );
    });

    group('configFileExists', () {
      test(
        'Given non-existent file path, When configFileExists called, Then returns false',
        () {
          final exists = SshConfigService.configFileExists(
            filePath: '/nonexistent/path/config',
          );

          expect(exists, isFalse);
        },
      );

      test(
        'Given existing file, When configFileExists called, Then returns true',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('Host test\n    HostName 10.0.0.1\n');

          final exists = SshConfigService.configFileExists(
            filePath: configFile.path,
          );

          expect(exists, isTrue);
        },
      );
    });

    group('findHostEntry', () {
      test(
        'Given config file with matching host, When finding existing host, Then returns entry',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host myserver
    HostName 192.168.1.100
    User admin
''');

          final entry = SshConfigService.findHostEntry(
            'myserver',
            filePath: configFile.path,
          );

          expect(entry, isNotNull);
          expect(entry!.hostName, 'myserver');
          expect(entry.actualHost, '192.168.1.100');
        },
      );

      test(
        'Given config file without matching host, When finding non-existing host, Then returns null',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host server1
    HostName 192.168.1.1
''');

          final entry = SshConfigService.findHostEntry(
            'nonexistent',
            filePath: configFile.path,
          );

          expect(entry, isNull);
        },
      );

      test(
        'Given config file with wildcard entries, When finding host with wildcard, Then returns matching entry',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host *.example.com
    HostName 10.0.0.1
    User admin

Host specific
    HostName 10.0.0.2
''');

          final entry = SshConfigService.findHostEntry(
            '*.example.com',
            filePath: configFile.path,
          );

          expect(entry, isNotNull);
          expect(entry!.hostName, '*.example.com');
          expect(entry.actualHost, '10.0.0.1');
        },
      );
    });

    group('_globToRegex', () {
      test(
        'Given host pattern with asterisk, When finding host, Then matches wildcard pattern',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host web.example.com
    HostName 10.0.0.1
''');

          // findHostEntry('web.*') converts search pattern to regex ^web\..*$
          final result1 = SshConfigService.findHostEntry(
            'web.*',
            filePath: configFile.path,
          );
          expect(result1, isNotNull);
          expect(result1!.hostName, 'web.example.com');

          final result2 = SshConfigService.findHostEntry(
            '*.example.com',
            filePath: configFile.path,
          );
          expect(result2, isNotNull);
          expect(result2!.hostName, 'web.example.com');

          final result3 = SshConfigService.findHostEntry(
            'other.*',
            filePath: configFile.path,
          );
          expect(result3, isNull);
        },
      );

      test(
        'Given host pattern with question mark, When finding host, Then matches single character',
        () {
          final tempDir = Directory.systemTemp.createTempSync();
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final configFile = File('${tempDir.path}/config');
          configFile.writeAsStringSync('''
Host host1
    HostName 10.0.0.1
''');

          final result1 = SshConfigService.findHostEntry(
            'host?',
            filePath: configFile.path,
          );
          expect(result1, isNotNull);

          final result3 = SshConfigService.findHostEntry(
            'host??',
            filePath: configFile.path,
          );
          expect(result3, isNull);
        },
      );
    });
  });
}
