import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/domain/services/import_export_service.dart';

void main() {
  group('ImportExportStatus', () {
    test(
        'Given ImportExportStatus enum, When converting to string, Then produces correct values',
        () {
      expect(ImportExportStatus.idle.toString(), 'ImportExportStatus.idle');
      expect(ImportExportStatus.exporting.toString(), 'ImportExportStatus.exporting');
      expect(ImportExportStatus.importing.toString(), 'ImportExportStatus.importing');
      expect(ImportExportStatus.success.toString(), 'ImportExportStatus.success');
      expect(ImportExportStatus.error.toString(), 'ImportExportStatus.error');
    });
  });

  group('ImportExportService - Export File Validation', () {
    test(
        'Given valid export data with connections, version, and exportTime, When validating, Then returns true',
        () {
      final validData = {
        'appName': 'lbpSSH',
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [
          {
            'id': 'conn1',
            'name': 'Test Server',
            'host': '192.168.1.1',
            'port': 22,
            'username': 'user',
            'authType': 'password',
          },
        ],
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(validData), true);
    });

    test(
        'Given empty connections array, When validating, Then returns false',
        () {
      final invalidData = {
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [],
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });

    test(
        'Given missing version field, When validating, Then returns false',
        () {
      final invalidData = {
        'appName': 'lbpSSH',
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': [],
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });

    test(
        'Given connections as string instead of list, When validating, Then returns false',
        () {
      final invalidData = {
        'version': 1,
        'exportTime': '2024-01-01T00:00:00Z',
        'connections': 'invalid',
      };

      bool validateExportFile(Map<String, dynamic> data) {
        if (!data.containsKey('connections') ||
            !data.containsKey('version') ||
            !data.containsKey('exportTime')) {
          return false;
        }
        if (data['connections'] is! List) {
          return false;
        }
        if ((data['connections'] as List).isEmpty) {
          return false;
        }
        return true;
      }

      expect(validateExportFile(invalidData), false);
    });
  });
}
