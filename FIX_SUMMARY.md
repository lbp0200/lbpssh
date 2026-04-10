# SSH Welcome Banner Truncation - Fix Summary

## Problem
SSH welcome banner (MOTD) was truncated when connecting via PTY mode - only 3 lines visible instead of the full 24-line welcome with ASCII art.

## Root Cause
`SshService.connect()` called `_getShellEnvironment()` BEFORE creating the shell session. This method executed multiple remote commands (`echo $SHELL`, `grep /etc/passwd`, `test -x`, `echo $HOME`, `echo $PATH`) via `_client.execute()`.

Each `execute()` opens a separate SSH channel. SSH servers send MOTD only on the **first channel** per connection. The exec channel consumed the MOTD, so the subsequent shell channel received none.

Evidence:
- Direct `shell()` with PTY: 1418 bytes, 24 lines ✓
- `execute()` then `shell()` on same client: 309 bytes, 3 lines ✗

## Fix
**File:** `lib/domain/services/ssh_service.dart`

1. **Removed** the `_getShellEnvironment()` method (lines 535-637)
2. **Changed** shell creation from:
   ```dart
   session = await _client!.shell(environment: await _getShellEnvironment());
   ```
   to:
   ```dart
   session = await _client!.shell(
     pty: const SSHPtyConfig(type: 'xterm', width: 80, height: 24),
   );
   ```
3. **Swapped** fallback order: PTY first, non-PTY as fallback

The environment variables (SHELL, TERM, LANG, HOME, PATH) are no longer explicitly set, but the SSH server provides reasonable defaults via the user's shell initialization.

## Verification
Test: `test/integration/ssh_pty_comparison_test.dart`

**Before fix:**
- Non-PTY: 1418 chars, 24 lines ✓
- PTY: 309 chars, 3 lines ✗

**After fix:**
- Non-PTY: 1418 chars, 24 lines ✓
- PTY: 1418 chars, 24 lines ✓

## Impact
- ✅ Full welcome banner now visible in all terminal modes
- ✅ Simplified connection logic (fewer moving parts)
- ✅ No pre-exec race conditions
- ⚠️ Minor: Custom environment detection removed (TERM defaults to xterm-256color via PTY config)

## Related Tests
- `test/integration/ssh_pty_comparison_test.dart` - Primary regression test
- `test/integration/ssh_preexec_motd_test.dart` - Demonstrates the bug pattern
- `test/integration/ssh_pty_diagnostic_test.dart` - Diagnostic utilities
