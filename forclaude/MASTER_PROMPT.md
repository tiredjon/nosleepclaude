# MASTER PROMPT — Claude Keep Awake macOS Utility

You are responsible for building this project from research through a working MVP.

## Read the project context correctly

The repository uses a modular context system to avoid wasting Claude Code session context.

FIRST:
1. Read `CLAUDE.md`.
2. Read `context/PROJECT.md`.
3. Read `context/TECHNICAL.md`.
4. Read `context/DECISIONS.md`.
5. Read `context/SESSION.md`.

After that, DO NOT repeatedly reread every context file. Read only files relevant to the current task. `CLAUDE.md` is deliberately tiny and is an index, not a 1000-line specification.

At the end of meaningful work, update `context/SESSION.md`. Update other context files only when their information changes.

## Goal

Build a lightweight native macOS menu-bar utility called Claude Keep Awake.

The problem:
I run Claude Code in Terminal/iTerm and give it long-running tasks. If I accidentally close my MacBook lid, macOS may sleep and the terminal workload stops or is suspended. I then have to reopen the Mac and recover/continue the session.

The utility should let me enable a mode that prevents ordinary system sleep using supported macOS power-management mechanisms, so long-running local workloads can continue.

Claude Code is the motivating workload, but the app must NOT directly control Claude Code.

## Core workflow

Claude Code running
→ enable Keep Awake
→ close lid if the Mac's supported power-management conditions allow continued operation
→ leave Mac running
→ open lid later
→ workload is still running if macOS was able to remain awake
→ disable Keep Awake when finished

## Critical technical requirement

DO NOT assume that `caffeinate` or an IOPM assertion automatically defeats closed-lid sleep on every MacBook.

Before writing the main implementation, research the current macOS behavior and supported APIs.

Investigate:
- `caffeinate`;
- IOPM assertions;
- `PreventUserIdleSystemSleep`;
- `PreventSystemSleep`;
- `PreventUserIdleDisplaySleep`;
- sleep/wake notifications;
- lid-close behavior;
- clamshell mode;
- AC power requirements;
- external display requirements;
- Apple Silicon;
- Intel Macs;
- modern Login Item APIs.

Compare `caffeinate` with native IOPM assertions.

Choose the solution based on reliability, lifecycle control, correctness, and supported macOS behavior.

If macOS fundamentally prevents an ordinary app from guaranteeing operation with a closed lid in some conditions, say so clearly. Do not fake it and do not use security bypasses.

Use:
`pmset -g`
`pmset -g assertions`
and other appropriate supported diagnostics during research/testing.

## Safety constraints

Never:
- disable SIP;
- modify `/System`;
- modify the kernel;
- install kernel extensions;
- weaken macOS security;
- alter FileVault;
- alter firewall/network settings;
- install hidden root daemons;
- require sudo unless genuinely necessary and justified.

Prefer official Apple APIs.

## Scope

Required:
- native macOS app;
- menu-bar utility;
- ACTIVE/INACTIVE state;
- enable/disable;
- correct assertion lifecycle;
- sleep/wake handling;
- Launch at Login using modern supported APIs;
- optional Start Active setting;
- battery warning;
- useful status/error reporting;
- local-only operation;
- minimal CPU/RAM usage;
- buildable `.app`;
- README;
- troubleshooting;
- tests.

Explicitly do NOT:
- parse Claude Code terminal output;
- read Claude Code sessions;
- manipulate PTYs;
- inject terminal input;
- send SIGSTOP/SIGCONT;
- modify Claude Code files;
- use network/cloud/telemetry/analytics;
- add accounts or backend services.

The utility should also work for Codex, Python jobs, Docker, compilation, servers, training jobs, downloads, etc.

## UX

Keep the UI tiny.

Menu bar:
`Keep Awake`

When active, clearly show:
`ACTIVE`

When inactive:
`INACTIVE`

Provide:
- Enable Keep Awake / Disable Keep Awake
- Launch at Login
- Start Active
- Battery warning
- system/power status only when reliably known

Do not display guessed values.

Possible status:
- System Sleep: PREVENTED / not reliably known
- Display Sleep: actual state if relevant
- Power: AC/Battery
- Lid: Open/Closed only if reliably detectable

## Assertion lifecycle

When enabling:
1. create exactly the required supported assertion;
2. retain its identifier;
3. expose success/failure;
4. avoid duplicate assertions.

When disabling:
1. release the assertion;
2. clear stored state;
3. confirm/report errors.

On sleep/wake:
- verify the assertion if necessary;
- recreate it if the chosen API requires that;
- avoid leaks and duplicate assertions.

On app termination:
- release resources correctly;
- rely on documented OS cleanup behavior where applicable.

## Battery

If active on battery, show a clear warning that preventing sleep can significantly increase battery use.

Do not silently disable the feature.

## Logging

Minimal local debug logs:
- launch;
- enable;
- assertion created;
- wake;
- verification/recreation;
- disable;
- assertion released;
- errors.

No sensitive data.

## Architecture

Keep the project small. Suggested structure:

ClaudeKeepAwake/
├── App/
│   ├── ClaudeKeepAwakeApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── SleepManager.swift
│   ├── PowerMonitor.swift
│   └── SystemEvents.swift
├── UI/
│   ├── MenuBarView.swift
│   ├── StatusView.swift
│   └── SettingsView.swift
├── Services/
│   └── LaunchAtLoginManager.swift
├── Models/
│   └── AppState.swift
└── Resources/

You may simplify or change this if research shows a better structure. Do not overengineer.

Responsibilities:
- SleepManager: sleep-prevention API and lifecycle.
- PowerMonitor: power source state.
- SystemEvents: sleep/wake/lifecycle notifications.
- LaunchAtLoginManager: login item.
- AppState: observable application state.
- UI: presentation only.

No database, backend, network layer, or unnecessary framework.

## Testing

Test:
1. inactive behavior;
2. active open-lid behavior;
3. enable/disable repeatedly;
4. assertion release;
5. sleep/wake;
6. Launch at Login;
7. Start Active;
8. AC power;
9. battery;
10. physical closed-lid behavior;
11. several-hour long-running terminal workload.

For closed-lid testing, record:
- Mac model;
- macOS version;
- AC/battery;
- external display;
- exact observed behavior.

Do not claim universal closed-lid support from an open-lid test.

## Build

Prefer Swift + AppKit/SwiftUI.

Support Apple Silicon first; Intel if practical.

Provide:
- Xcode build;
- CLI build if practical;
- `.app` output;
- installation instructions;
- uninstall instructions.

If useful, add `build.sh`.

## Required workflow

### Phase 1 — Research
Research the current macOS APIs and closed-lid behavior.

### Phase 2 — Design
Choose the API and architecture. Record durable decisions in `context/DECISIONS.md`.

### Phase 3 — Implementation
Create the actual working app.

### Phase 4 — Testing
Run automated tests and all tests possible without physical lid interaction.

### Phase 5 — Build
Produce a runnable `.app`.

### Phase 6 — Documentation
Write README covering installation, usage, diagnostics, limitations, and troubleshooting.

Do not stop at pseudocode or a mockup.

## Working style

Do not ask me questions when you can make a reasonable technical decision yourself.

Do not spend the entire session explaining what you could do. Actually do the work.

Before large implementation:
- inspect the repository;
- inspect existing files;
- research the platform behavior;
- make a concrete decision.

After each meaningful milestone:
- update `context/SESSION.md`;
- keep context files concise;
- do not dump the entire project history into `CLAUDE.md`.

When starting a new session after `/clear`:
- read `CLAUDE.md`;
- inspect `context/SESSION.md`;
- read only the context relevant to the next task;
- continue from the recorded phase.

## Final definition of done

The project is done when:
- the app builds;
- the menu-bar UI works;
- Keep Awake can be enabled and disabled;
- the selected macOS sleep-prevention mechanism is implemented correctly;
- wake/lifecycle handling is correct;
- Launch at Login works if implemented;
- diagnostics/documentation exist;
- tests have been run;
- closed-lid limitations are explicitly documented;
- the result is an actual usable `.app`, not a concept.

Start with Phase 1 now.
