# lbpSSH Project Memory

## Release Process
```bash
# 1. Update version in pubspec.yaml
# 2. Update CHANGELOG.md
# 3. Commit changes
# 4. Create tag
# 5. Push
```

**Important:** `.github/workflows/changelog.yml` is broken - all runs fail. Must fix before releasing.

## Project Structure
- Clean architecture with providers
- dartssh2 for SSH, xterm for terminal, provider for state management

## Key Files
- `lib/domain/services/ssh_service.dart` - SSH connection with SOCKS5 proxy support
- `lib/data/models/ssh_config.dart` - Global SSH settings (keepaliveInterval)
- `lib/presentation/screens/app_settings_screen.dart` - Settings UI with SSH keepalive config
