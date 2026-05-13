import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lbp_ssh/domain/services/kitty_launch_service.dart';
import 'package:lbp_ssh/domain/services/terminal_service.dart';

class _MockTerminalSession extends Mock implements TerminalSession {}

void main() {
  group('KittyLaunchService', () {
    late _MockTerminalSession mockSession;
    late KittyLaunchService service;

    setUp(() {
      mockSession = _MockTerminalSession();
      service = KittyLaunchService(session: mockSession);
    });

    group('isConnected', () {
      test('returns true when session is provided', () {
        expect(service.isConnected, isTrue);
      });

      test('returns false when session is null', () {
        final nullService = KittyLaunchService();
        expect(nullService.isConnected, isFalse);
      });
    });

    group('LaunchType', () {
      test('has all type values', () {
        expect(LaunchType.values, hasLength(5));
        expect(LaunchType.values[0], LaunchType.tab);
        expect(LaunchType.values[1], LaunchType.window);
        expect(LaunchType.values[2], LaunchType.overlay);
        expect(LaunchType.values[3], LaunchType.background);
        expect(LaunchType.values[4], LaunchType.os);
      });
    });

    group('LaunchParams', () {
      test('stores all fields', () {
        const params = LaunchParams(
          program: '/bin/bash',
          arguments: ['-c', 'echo hi'],
          cwd: '/tmp',
          title: 'Test',
          stealFocus: true,
          env: 'ENV=foo',
          hold: true,
        );
        expect(params.program, '/bin/bash');
        expect(params.arguments, ['-c', 'echo hi']);
        expect(params.cwd, '/tmp');
        expect(params.title, 'Test');
        expect(params.stealFocus, isTrue);
        expect(params.env, 'ENV=foo');
        expect(params.hold, isTrue);
      });
    });

    group('launch', () {
      test('sends command with program only', () async {
        await service.launch('/bin/ls');
        verify(
          () => mockSession.writeRaw('\x1b]6;p=/bin/ls;type=tab\x1b\\\\'),
        ).called(1);
      });

      test('includes arguments', () async {
        await service.launch(
          '/bin/ls',
          arguments: ['-la', '/tmp'],
        );
        verify(
          () =>
              mockSession.writeRaw('\x1b]6;p=/bin/ls;a=-la,/tmp;type=tab\x1b\\\\'),
        ).called(1);
      });

      test('includes cwd', () async {
        await service.launch(
          '/bin/sh',
          cwd: '/home/user',
        );
        verify(
          () =>
              mockSession.writeRaw('\x1b]6;p=/bin/sh;c=/home/user;type=tab\x1b\\\\'),
        ).called(1);
      });

      test('includes title', () async {
        await service.launch(
          '/bin/bash',
          title: 'My Terminal',
        );
        verify(
          () =>
              mockSession.writeRaw('\x1b]6;p=/bin/bash;t=My Terminal;type=tab\x1b\\\\'),
        ).called(1);
      });

      for (final entry in [
        (type: LaunchType.tab, str: 'tab'),
        (type: LaunchType.window, str: 'window'),
        (type: LaunchType.overlay, str: 'overlay'),
        (type: LaunchType.background, str: 'background'),
        (type: LaunchType.os, str: 'os'),
      ]) {
        test('includes type=${entry.str}', () async {
          await service.launch('/bin/ls', type: entry.type);
          verify(
            () => mockSession.writeRaw(
              '\x1b]6;p=/bin/ls;type=${entry.str}\x1b\\\\',
            ),
          ).called(1);
        });
      }

      test('includes stealFocus when true', () async {
        await service.launch('/bin/ls', stealFocus: true);
        verify(
          () => mockSession.writeRaw(
            any(that: contains(';s=1')),
          ),
        ).called(1);
      });

      test('includes stealFocus when false', () async {
        await service.launch('/bin/ls', stealFocus: false);
        verify(
          () => mockSession.writeRaw(
            any(that: contains(';s=0')),
          ),
        ).called(1);
      });

      test('includes env', () async {
        await service.launch('/bin/ls', env: 'DISPLAY=:0');
        verify(
          () => mockSession.writeRaw(
            any(that: contains(';e=DISPLAY=:0')),
          ),
        ).called(1);
      });

      test('includes hold when true', () async {
        await service.launch('/bin/ls', hold: true);
        verify(
          () => mockSession.writeRaw(
            any(that: contains(';h=1')),
          ),
        ).called(1);
      });

      test('includes hold when false', () async {
        await service.launch('/bin/ls', hold: false);
        verify(
          () => mockSession.writeRaw(
            any(that: contains(';h=0')),
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyLaunchService();
        expect(
          () => nullService.launch('/bin/ls'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('launchInTab', () {
      test('sends command with tab type', () async {
        await service.launchInTab('/bin/ls');
        verify(
          () => mockSession.writeRaw('\x1b]6;p=/bin/ls;type=tab\x1b\\\\'),
        ).called(1);
      });

      test('forwards arguments', () async {
        await service.launchInTab(
          '/bin/ls',
          arguments: ['-la'],
          cwd: '/tmp',
          title: 'Tab',
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;p=/bin/ls;a=-la;c=/tmp;t=Tab;type=tab\x1b\\\\',
          ),
        ).called(1);
      });
    });

    group('launchInWindow', () {
      test('sends command with window type', () async {
        await service.launchInWindow('/bin/ls');
        verify(
          () =>
              mockSession.writeRaw('\x1b]6;p=/bin/ls;type=window\x1b\\\\'),
        ).called(1);
      });

      test('forwards stealFocus', () async {
        await service.launchInWindow(
          '/bin/ls',
          stealFocus: true,
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;p=/bin/ls;type=window;s=1\x1b\\\\',
          ),
        ).called(1);
      });
    });

    group('openWithSystemDefault', () {
      test('sends command with os type and empty program', () async {
        await service.openWithSystemDefault('/path/to/file');
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;p=;c=/path/to/file;type=os\x1b\\\\',
          ),
        ).called(1);
      });
    });

    group('openUrl', () {
      test('sends URL command', () async {
        await service.openUrl('https://example.com');
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;type=os;u=https://example.com\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyLaunchService();
        expect(
          () => nullService.openUrl('https://example.com'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('openFile', () {
      test('delegates to openWithSystemDefault', () async {
        await service.openFile('/path/to/file.txt');
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;p=;c=/path/to/file.txt;type=os\x1b\\\\',
          ),
        ).called(1);
      });
    });

    group('sendNotification', () {
      test('sends notification with title only', () async {
        await service.sendNotification(title: 'Hello');
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;type=notification;title=Hello\x1b\\\\',
          ),
        ).called(1);
      });

      test('includes body', () async {
        await service.sendNotification(
          title: 'Hello',
          body: 'World',
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;type=notification;title=Hello;b=World\x1b\\\\',
          ),
        ).called(1);
      });

      test('includes sound', () async {
        await service.sendNotification(
          title: 'Alert',
          sound: 'Basso',
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;type=notification;title=Alert;s=Basso\x1b\\\\',
          ),
        ).called(1);
      });

      test('includes body and sound', () async {
        await service.sendNotification(
          title: 'Alert',
          body: 'Time is up',
          sound: 'Basso',
        );
        verify(
          () => mockSession.writeRaw(
            '\x1b]6;type=notification;title=Alert;b=Time is up;s=Basso\x1b\\\\',
          ),
        ).called(1);
      });

      test('throws when session is null', () async {
        final nullService = KittyLaunchService();
        expect(
          () => nullService.sendNotification(title: 'Test'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('window control methods', () {
      test('activateWindow sends command', () async {
        await service.activateWindow();
        verify(
          () => mockSession.writeRaw('\x1b]6;activate=1\x1b\\\\'),
        ).called(1);
      });

      test('minimizeWindow sends command', () async {
        await service.minimizeWindow();
        verify(
          () => mockSession.writeRaw('\x1b]6;minimize=1\x1b\\\\'),
        ).called(1);
      });

      test('maximizeWindow sends command', () async {
        await service.maximizeWindow();
        verify(
          () => mockSession.writeRaw('\x1b]6;maximize=1\x1b\\\\'),
        ).called(1);
      });

      test('setFullscreen(true) sends enable command', () async {
        await service.setFullscreen(true);
        verify(
          () => mockSession.writeRaw('\x1b]6;fullscreen=1\x1b\\\\'),
        ).called(1);
      });

      test('setFullscreen(false) sends disable command', () async {
        await service.setFullscreen(false);
        verify(
          () => mockSession.writeRaw('\x1b]6;fullscreen=0\x1b\\\\'),
        ).called(1);
      });

      test('setWindowTitle sends title command', () async {
        await service.setWindowTitle('My Title');
        verify(
          () => mockSession.writeRaw('\x1b]6;title=My Title\x1b\\\\'),
        ).called(1);
      });

      for (final method in [
        'activateWindow',
        'minimizeWindow',
        'maximizeWindow',
        'setFullscreen',
        'setWindowTitle',
      ]) {
        test('$method throws when session is null', () async {
          final nullService = KittyLaunchService();
          expect(
            () => switch (method) {
              'activateWindow' => nullService.activateWindow(),
              'minimizeWindow' => nullService.minimizeWindow(),
              'maximizeWindow' => nullService.maximizeWindow(),
              'setFullscreen' => nullService.setFullscreen(true),
              'setWindowTitle' => nullService.setWindowTitle('x'),
              _ => Future.value(),
            },
            throwsA(isA<Exception>()),
          );
        });
      }
    });
  });
}
