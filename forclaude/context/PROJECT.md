# Project specification

## Goal

Build a lightweight native macOS menu-bar utility called Claude Keep Awake.

The utility should let the user enable a mode that prevents macOS from entering ordinary system sleep so long-running local workloads can continue. Claude Code is the motivating workload, but the utility must remain independent of Claude Code.

## Core workflow

1. User starts Claude Code or another long-running process.
2. User enables Keep Awake.
3. User may close the MacBook lid.
4. The Mac should remain awake whenever the supported macOS power-management rules permit it.
5. User opens the lid later and finds the workload still running if the system was able to remain awake.
6. User disables Keep Awake when finished.

## Scope

### Required
- Native macOS app.
- Menu-bar utility.
- Active/inactive state.
- Enable/disable control.
- Correct sleep-prevention assertion lifecycle.
- Sleep/wake handling.
- Launch at Login using a modern supported API.
- Optional Start Active setting.
- Battery warning/status.
- Clear status/error reporting.
- Local-only operation.
- Minimal resource usage.
- Buildable `.app`.
- README and troubleshooting.
- Tests for assertion lifecycle and relevant app behavior.

### Explicitly NOT required
Do not directly control Claude Code.
Do not read Claude Code sessions.
Do not parse terminal output.
Do not inject terminal input.
Do not use PTY manipulation.
Do not send SIGSTOP/SIGCONT to Claude Code.
Do not modify Claude Code files.
Do not require cloud services, telemetry, analytics, accounts, or external APIs.

The utility should work equally well for Claude Code, Codex, Python jobs, Docker workloads, compilers, servers, training jobs, and other local processes.

## macOS safety constraints

Do not:
- disable SIP;
- modify `/System`;
- modify the kernel;
- install kernel extensions;
- install hidden/root daemons without a compelling supported requirement;
- weaken system security;
- alter FileVault;
- alter firewall/network configuration;
- use root privileges unless genuinely required and justified.

Prefer official Apple APIs.

## Important closed-lid requirement

Do not assume that a sleep assertion defeats every kind of MacBook lid-close sleep.

Research and document:
- system sleep;
- display sleep;
- idle sleep;
- lid-close behavior;
- clamshell mode;
- AC power requirements;
- external display requirements;
- Apple Silicon behavior;
- Intel behavior where relevant.

If macOS imposes a limitation that prevents ordinary third-party software from guaranteeing closed-lid operation, state it explicitly. Never fake a successful status.

## UX

Menu-bar utility with a very small UI.

Example states:

ACTIVE:
- Keep Awake: ACTIVE
- System Sleep: PREVENTED / status actually known
- Display Sleep: actual status
- Power: AC / Battery
- Lid: actual status if reliably detectable

INACTIVE:
- Keep Awake: INACTIVE

Primary action toggles:
- Enable Keep Awake
- Disable Keep Awake

Settings:
- Launch at Login
- Start Active
- Battery warning

## Logging

Use minimal local debug logging only.
Never log sensitive data.
Logging should be disableable if practical.

Example:
- app launched
- mode enabled
- assertion created
- wake detected
- assertion verified/recreated
- mode disabled
- assertion released
- errors

## Build

Prefer Swift + AppKit/SwiftUI as appropriate, with a native macOS app.
Support Apple Silicon first and Intel if practical.
Avoid Electron unless there is a compelling reason.

Provide CLI build instructions and, if useful, a simple build script producing:
`ClaudeKeepAwake.app`

## Deliverable

A working MVP, not a mockup or pseudocode, plus:
- source code;
- build/install instructions;
- usage instructions;
- technical limitations;
- troubleshooting;
- testing results.
