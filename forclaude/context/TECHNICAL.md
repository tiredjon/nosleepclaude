# Technical context

## Purpose

This file stores research and implementation facts about macOS power management. Confirmed 2026-09-14 against: Apple's shipped `IOPMLib.h` header (IOKit.framework, macOS SDK), `SMAppService.h` (ServiceManagement.framework, macOS SDK), `man caffeinate`, live `pmset -g` / `pmset -g assertions` output on this Mac (macOS 26.6.2, arm64/Apple Silicon), and corroborating web sources for clamshell-mode requirements.

## caffeinate vs native IOPM assertions — decision basis

`caffeinate` (man page, `/usr/bin/caffeinate`) is a thin CLI wrapper that itself creates IOPM assertions on behalf of a spawned process or itself, and releases them on exit/timeout. Flags: `-d` (no display sleep), `-i` (no idle system sleep), `-m` (no disk idle), `-s` (no system sleep, AC-only), `-u` (declare user active), `-t <secs>` (timeout), `-w <pid>` (release when pid exits).

For a persistent menu-bar GUI app, wrapping `caffeinate` as a subprocess would mean: managing a child process's lifecycle, no structured error reporting (only exit codes), no way to query "is my assertion still alive" except by re-parsing `pmset -g assertions` text, and an extra process the user has to reconcile with Activity Monitor. Calling the same underlying `IOKit/pwr_mgt` assertion API in-process (`IOPMAssertionCreateWithName` / `IOPMAssertionRelease`) gives direct success/failure codes (`IOReturn`), a retained `IOPMAssertionID`, and no subprocess. **Decision: call IOPM assertion APIs directly; do not shell out to `caffeinate`.**

## Which assertion type

From `IOPMLib.h` (verbatim, source of truth):

- `kIOPMAssertPreventUserIdleSystemSleep` ("PreventUserIdleSystemSleep") — "Prevents the system from sleeping automatically due to a lack of user activity... The display may dim and idle sleep while [this assertion] is enabled, but the system may not idle sleep. **The system may still sleep for lid close, Apple menu, low battery, or other sleep reasons.** This assertion has no effect if the system is in Dark Wake." This is exactly what `caffeinate -i` uses.
- `kIOPMAssertPreventUserIdleDisplaySleep` ("PreventUserIdleDisplaySleep") — prevents display dimming/idle sleep; note "the display may still sleep for other reasons, like a user closing a portable's lid." Stronger than needed for our case (also keeps the screen lit, costing more battery) — not used by default.
- `kIOPMAssertionTypePreventSystemSleep` ("PreventSystemSleep") — **`@deprecated Deprecated in 10.9. This assertion is not supported in any OS X releases.`** per the header itself. Confirms it must not be used, despite being named in the research brief as something to investigate.
- `kIOPMAssertionTypeNoIdleSleep` / `NoDisplaySleepAssertion` — deprecated string aliases from 10.7, superseded by the two assertions above.

**Decision: the app creates exactly one assertion, `kIOPMAssertPreventUserIdleSystemSleep`, at `kIOPMAssertionLevelOn`, via `IOPMAssertionCreateWithName`.** This matches `caffeinate -i` semantics: prevents idle system sleep, allows the display to sleep normally (saving battery), and is the currently-supported, documented mechanism.

## Closed-lid reality (critical honesty finding)

Apple's own header text is unambiguous: an IOPM idle-sleep assertion does **not** override lid-close sleep. Closing the lid on a MacBook triggers a hardware/firmware-level forced sleep that user-space power assertions cannot block. The only documented way to keep a Mac fully running with the lid closed is **clamshell mode**, which is a separate macOS/firmware behavior, not something this app enables or controls:

- Requires the Mac connected to AC power (an Apple Silicon Mac can enter clamshell mode on battery too, but Apple's documented/standard behavior — and the one this app will state — is that it requires AC power; battery-only clamshell is not guaranteed and depends on model/settings).
- Requires an external display connected and active.
- Classically also required an external keyboard/mouse/trackpad connected (still commonly required/expected for user interaction, though not strictly what blocks sleep for a headless background compute workload).
- If these clamshell conditions are not met, closing the lid sleeps the machine regardless of any IOPM assertion this app (or any app, including Terminal, Xcode, or caffeinate) holds.

**Consequence for UX/docs: the app must never claim "ACTIVE" guarantees closed-lid operation.** It must state plainly that Keep Awake prevents *idle* sleep while the lid is open, and that closed-lid operation additionally requires the user's own clamshell-mode setup (AC power + external display), which is outside this app's control and not verified by it.

There is also a real, separate System Settings toggle — Battery/Energy: "Prevent automatic sleeping on power adapter when the display is off" — which affects idle sleep-with-display-off on AC power but does **not** override lid-close sleep either. Worth a troubleshooting mention only; not something this app sets.

## Verification/recreation across sleep-wake

Explicit assertions created with `IOPMAssertionCreateWithName` are not automatically dropped by the OS across a sleep/wake cycle (they persist until explicitly released or the owning process exits) — unlike timeout-based assertions. Per MASTER_PROMPT's defensive-engineering requirement, the app still re-verifies its assertion on wake (`NSWorkspace.didWakeNotification`) by checking it against `IOPMCopyAssertionsByProcess` for its own PID, and recreates it if missing, logging a warning either way. This guards against any future/edge-case OS behavior without assuming it, and avoids leaking duplicate assertions (recreate only if actually missing).

## Login Item API

Confirmed via `ServiceManagement.framework/Headers/SMAppService.h`: `SMLoginItemSetEnabled` (older `ServiceManagement.h` API family) is superseded by `SMAppService`, available macOS 13.0+. `SMAppService.mainApp` (`+ mainAppService`) registers/unregisters the running app itself as a login item via `registerAndReturnError:` / `unregisterAndReturnError:`, and exposes `.status` (`SMAppServiceStatusNotRegistered / Enabled / RequiresApproval / NotFound`). This is the correct, modern, non-deprecated mechanism — no separate login-helper target or `LSSharedFileList` needed for a simple "launch this app at login" feature.

**Decision: minimum deployment target is macOS 13.0**, driven jointly by `SMAppService` (13.0+) and SwiftUI `MenuBarExtra` (13.0+, the modern menu-bar-app API replacing manual `NSStatusItem` plumbing).

## Power source (AC/Battery)

`IOKit/ps/IOPowerSources.h` (`IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList`, `IOPSGetProvidingPowerSourceType`) is the public, documented API for AC-vs-battery state and percentage; confirmed present in the SDK. `pmset -g batt` on this machine currently reports `Now drawing from 'Battery Power' ... 50%; discharging`, confirming the CLI surface for manual diagnostics.

## Lid-state detection — deliberately not implemented

There is no public, documented API to read lid open/closed state. The only widely-known technique (reading the `AppleClamshellState` IORegistry property) is undocumented and not part of any public Apple framework. Given the explicit MASTER_PROMPT constraint "Do not display guessed values" and "Lid: Open/Closed only if reliably detectable," and the project-wide preference for official APIs, **the app does not attempt lid-state detection at all** and never shows a Lid status field. This is a deliberate scope decision, recorded in `DECISIONS.md`.

## Verification commands used

- `pmset -g` — confirmed system-wide settings, e.g. `sleep 1 (sleep prevented by powerd, caffeinate)`, `displaysleep 90`.
- `pmset -g assertions` — confirmed live assertion listing format (`PreventUserIdleSystemSleep`, owning pid/process, timeout info), used as the manual verification tool during testing (see `TESTING.md`).
- `man caffeinate` — confirmed flag semantics.
- `sw_vers` — macOS 26.6.2 (BuildVersion 25G83), arm64 (Apple Silicon), Xcode SDK MacOSX26.5, Swift 6.3.3.
