# Claude Keep Awake

A tiny native macOS menu-bar utility that prevents idle system sleep while it's active, so long-running local workloads (Claude Code, Codex, a build, a training job, a download, a server) keep running.

**Read the "Closed lid" section below before relying on this for a closed-lid workflow — it is not what you probably assume.**

## What it actually does

When you enable Keep Awake, the app creates one macOS power-management assertion — `PreventUserIdleSystemSleep` (the same mechanism `caffeinate -i` uses) — via the public IOKit `IOPMAssertionCreateWithName` API. This tells macOS not to sleep the system due to user inactivity. The display is still allowed to dim/sleep normally, which saves battery; only *system* idle sleep is prevented.

It does **not**:
- read, parse, or touch Claude Code (or any other program) in any way;
- inject input, send signals, or manipulate any process;
- touch the network, telemetry, or any account;
- require sudo;
- weaken any macOS security feature.

## Closed lid — read this

**Enabling Keep Awake does not guarantee your Mac stays awake with the lid closed.**

Apple's own documentation for the assertion this app uses states plainly: *"the system may still sleep for lid close... or other sleep reasons."* Closing a MacBook's lid triggers a hardware/firmware-level forced sleep that no app's power assertion — this one, `caffeinate`, or anything else — can override.

The only way to keep a Mac running with the lid closed is **clamshell mode**, which is a separate macOS/firmware behavior this app does not enable, control, or verify:
- the Mac connected to AC power;
- an external display connected and active;
- (classically also an external keyboard/mouse, though not strictly required just to keep a background compute job running).

If you close the lid without those conditions, the Mac will sleep — Keep Awake or not. This app's status only ever reports "System Sleep: PREVENTED (idle)," meaning idle sleep specifically; it never claims to guarantee closed-lid operation, and there is deliberately no "Lid: Open/Closed" indicator in the UI, because there is no public macOS API to read that reliably (see `context/TECHNICAL.md` for the research behind this).

**Practical takeaway:** if you want to close the lid and keep a long-running job going, set up real clamshell mode (power + external display) — Keep Awake alone will not do it. If you just want to leave the lid open and step away without the Mac sleeping, Keep Awake alone is sufficient.

## Requirements

- macOS 13 (Ventura) or later.
- Apple Silicon (tested) or Intel (should work — uses no Apple Silicon–specific APIs).

## Build

```
cd ClaudeKeepAwake
./build.sh
```

This runs `swift build -c release`, then assembles `ClaudeKeepAwake.app` (a real bundle with `Info.plist`, `LSUIElement=true` so it never shows a Dock icon, ad-hoc codesigned so Gatekeeper and `SMAppService` are happy locally).

You can also just build without bundling, e.g. to run tests or iterate:
```
swift build      # debug build, .build/debug/ClaudeKeepAwake (bare executable, not a bundle)
swift test       # run the automated test suite
```

Xcode also opens the package directly: `open Package.swift`.

## Install

```
cp -R ClaudeKeepAwake.app /Applications/
open /Applications/ClaudeKeepAwake.app
```

Installing to `/Applications` first matters for **Launch at Login**: `SMAppService` registers the app at its *current* path, so if you enable Launch at Login before moving the app, then move it, re-toggle the setting off and back on afterward.

## Uninstall

1. Quit the app (menu bar icon > Quit).
2. If Launch at Login was enabled, either turn it off in the app first, or remove it afterward via System Settings > General > Login Items.
3. `rm -rf /Applications/ClaudeKeepAwake.app`
4. Optional: clear saved settings — `defaults delete dev.tiredjon.ClaudeKeepAwake`

Nothing else is installed: no daemons, no login helper binary, no files outside `/Applications` and your normal `~/Library/Preferences` plist.

## Usage

Click the menu bar icon (`⚡ ACTIVE` / `⚡ INACTIVE`):
- **Enable/Disable Keep Awake** — toggles the assertion.
- **Status** — System Sleep (PREVENTED (idle) / Not prevented), Display Sleep (Awake/Asleep), Power (AC Power / Battery, with percentage on battery).
- **Launch at Login** — registers the app to start at login via `SMAppService` (macOS 13+ API; replaces the old, deprecated login-item mechanisms). If macOS reports "Needs approval," open System Settings > General > Login Items and approve it there — this is a macOS-imposed step the app cannot skip.
- **Start Active** — if on, Keep Awake is enabled automatically each time the app launches.
- **Warn when on Battery** — if on (default), a dismissible banner appears whenever Keep Awake is active while running on battery, since preventing sleep can noticeably increase battery drain. The feature is never silently disabled on battery — you decide.

## Diagnostics / troubleshooting

- `pmset -g assertions` — shows every live power assertion system-wide, grouped by owning process. Look for a `PreventUserIdleSystemSleep` line owned by `ClaudeKeepAwake` named `"Claude Keep Awake: user-enabled Keep Awake"`.
- `pmset -g` — overall power settings, including whether `sleep` is currently being prevented and by what.
- `pmset -g batt` — current AC/battery state, for cross-checking what the app shows.
- Unified logging: `log stream --predicate 'subsystem == "dev.tiredjon.ClaudeKeepAwake"'` while the app runs, to see lifecycle events (launch, assertion created/released, wake, verification/recreation, errors). No sensitive data is ever logged.

**The Mac slept even though Keep Awake showed ACTIVE.** This is almost always the lid-close/clamshell limitation above, not a bug — check whether the lid was closed without clamshell-mode conditions met. If the lid was open and it still slept, check `pmset -g assertions` for a competing `SleepServicesTask`/low-battery/thermal condition, and file what you saw.

**"Needs approval in System Settings" won't go away.** Open System Settings > General > Login Items and approve `ClaudeKeepAwake` there; macOS requires this explicit human approval step for any newly-registered login item and no API can bypass it.

**Battery drains fast with Keep Awake on.** Expected — preventing idle sleep keeps the CPU/system awake continuously. Disable it when not needed, or plug in.

## Architecture

```
ClaudeKeepAwake/
├── Package.swift
├── build.sh
├── Sources/ClaudeKeepAwake/
│   ├── App/            ClaudeKeepAwakeApp.swift (SwiftUI @main, MenuBarExtra), AppDelegate.swift (lifecycle)
│   ├── Core/            SleepManager (IOPM assertion), PowerMonitor (AC/battery), SystemEvents (sleep/wake notifications), Logging
│   ├── Services/        LaunchAtLoginManager (SMAppService)
│   ├── Models/           AppState (ObservableObject coordinating everything)
│   └── UI/                MenuBarView, StatusView, SettingsView
├── Tests/ClaudeKeepAwakeTests/
└── Resources/Info.plist
```

No database, network layer, backend, or account system — none needed. See `../forclaude/context/` for the full research and decision record behind these choices, including why `caffeinate` isn't shelled out to, why `PreventSystemSleep` is not used (deprecated, unsupported), and why there's no lid-state indicator.

## Testing

See `../forclaude/context/TESTING.md` for exactly what has and hasn't been verified so far, including real `pmset -g assertions` verification of assertion lifecycle on the built `.app`, and what's explicitly left for physical closed-lid / multi-hour testing on real hardware.

Run the automated suite:
```
swift test
```

## Safety

This app never disables SIP, modifies `/System` or the kernel, installs kernel extensions or hidden/root daemons, alters FileVault or firewall/network settings, or requires sudo. It uses only public, documented Apple APIs (`IOKit/pwr_mgt`, `IOKit/ps`, `ServiceManagement`/`SMAppService`, `NSWorkspace`). All state is local; nothing is sent anywhere.
