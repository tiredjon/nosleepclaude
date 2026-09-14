# Testing

## Automated

26 XCTest cases, all passing (`swift test`), covering:
- state transitions (enable/disable/toggle, repeated cycles);
- assertion creation success/failure (via an injected `IOPMAssertionProviding` fake for the failure paths — see `SleepManagerTests.swift`);
- assertion release success/failure;
- wake handling (`verifyAfterWake`: no-op when the assertion is still valid, recreates without duplicating when it's missing, reports inactive if recreation itself fails);
- deinit safety net (releases if a `SleepManager` is deallocated while still active);
- error handling (`AppState.lastErrorMessage` set on failure, cleared on success);
- settings persistence (`startActiveSetting`, `batteryWarningEnabled` round-trip through an injected `UserDefaults` instance across separate `AppState` instances);
- `Start Active` actually calling `enableKeepAwake()` from `start()`, and not doing so when the setting is off;
- `stop()` releasing an active assertion;
- `PowerMonitor.refresh()`/`start()` returning a defined, non-crashing state;
- `LaunchAtLoginManager.status`/`isEnabled` not crashing (register/unregister are deliberately NOT exercised by the automated suite — see below).

Run with: `cd ClaudeKeepAwake && swift test`

**Deliberately not automated:** `LaunchAtLoginManagerTests` never calls `enable()`/`disable()`. Doing so from a test run would register a real login item (pointing at the test binary) in the user's System Settings > Login Items — a real, user-visible side effect a test suite must not cause. Login-item registration was instead verified manually (see below).

## Manual verification performed this session (2026-09-14, macOS 26.6.2, Apple Silicon, on Battery Power)

### Real IOPM assertion visible via `pmset -g assertions`
Compiled a standalone binary that creates `kIOPMAssertPreventUserIdleSystemSleep` (the same call `SleepManager` makes), synchronized with a marker file, and while it held the assertion ran `pmset -g assertions`. Confirmed the exact line:
```
pid <pid>(assertion_check2): [...] PreventUserIdleSystemSleep named: "ClaudeKeepAwake manual verification"
```
Released the assertion and re-ran `pmset -g assertions`: the line was gone, no leak.

### Built `.app` end-to-end
- `./build.sh` produced `ClaudeKeepAwake.app`, ad-hoc codesigned (`codesign -dv` confirms `Signature=adhoc`, valid bundle, `Info.plist entries=14`).
- Launched via `open ClaudeKeepAwake.app`: process runs (confirmed via `ps aux`), and is background-only / no Dock icon (confirmed via System Events: `background only` reported `true`), i.e. `LSUIElement` took effect.
- With `Start Active` off (default): launched the app, confirmed via `pmset -g assertions` that **no** Keep Awake assertion was created — matches spec (optional Start Active setting, off by default, no silent auto-enable).
- Set `Start Active` on (`defaults write dev.tiredjon.ClaudeKeepAwake startActive -bool true`), relaunched: confirmed via `pmset -g assertions` the app's own PID now holds `PreventUserIdleSystemSleep named: "Claude Keep Awake: user-enabled Keep Awake"`.
- Quit the app (`System Events quit` + fallback `pkill`): confirmed via `pmset -g assertions` the assertion was released immediately (no orphaned assertion left behind by `applicationWillTerminate` → `AppState.stop()` → `SleepManager.disable()`).
- Confirmed no login item was ever registered during any of this testing (`sfltool dumpbtm` shows nothing for the app) — `LaunchAtLoginManager.enable()` was never called outside of a human deliberately choosing "Launch at Login" in the running UI.
- Cleaned up: removed the test `UserDefaults` domain afterward.

## Manual macOS tests — NOT yet performed (require physical hardware interaction / time)

These require a human physically closing a MacBook lid, or leaving the Mac unattended for hours, and were correctly out of scope for this automated Claude Code session. Do not claim these are done until actually run.

### Closed lid
Physically close the lid with Keep Awake ACTIVE, on battery and on AC, with and without an external display, and record:
- Mac model;
- macOS version;
- AC/battery;
- external display state;
- exact observed behavior;
- whether the workload continued.

Expected outcome per research (`context/TECHNICAL.md`): without clamshell-mode conditions (AC + external display), the Mac WILL sleep on lid close regardless of Keep Awake being ACTIVE — this is the documented, honest limitation the app states, not a bug to "fix."

### Launch at Login
Enable the setting via the running app's UI (not via `defaults write`, so the real `SMAppService.mainApp.register()` path is exercised and the user sees the System Settings > Login Items approval flow if `requiresApproval` is returned), restart, and confirm the app launches automatically.

### Several-hour long-running terminal workload
Run Claude Code (or any long job) with Keep Awake ACTIVE for several hours on AC power, lid open, and confirm the Mac never idle-sleeps and the job completes uninterrupted.

## Rule

Do not mark the closed-lid scenario as universally solved based only on an open-lid test or a simulated notification. It has not been marked solved; see the section above.
