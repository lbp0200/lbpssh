# lbpSSH Project Memory

## Release Process
```bash
# 1. Update version in pubspec.yaml
# 2. Commit: git add pubspec.yaml && git commit -m "release: bump version to X.Y.Z"
# 3. Tag: git tag vX.Y.Z
# 4. Push: git push && git push origin vX.Y.Z
# 5. CI handles: build, release draft, Homebrew cask update
```

## Changelog
- `.github/workflows/changelog.yml` auto-generates CHANGELOG.md on push to main using `git log <prev_tag>..HEAD --no-merges`

## State Management
- flutter_riverpod (migrated from provider)

## Platform Support
- macOS, Linux, Windows (Flutter desktop)
- TUI mode via `bin/lbpssh_tui.dart` (utopia_tui)

## Key Dependencies
- dartssh2 — SSH protocol
- kterm — terminal emulator
- flutter_riverpod — state management
- go_router — navigation
- sentry — error tracking (DSN via `--dart-define=SENTRY_DSN=`)
- utopia_tui — TUI rendering
