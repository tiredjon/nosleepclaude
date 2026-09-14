# Architecture

## Target shape

Keep the project small. Do not create enterprise-style layers for a tiny utility.

Suggested structure:

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

This is a starting point, not a rigid requirement.

## Responsibilities

### SleepManager
- create the selected sleep-prevention assertion;
- retain assertion ID;
- report errors;
- release assertion;
- verify/recover after wake when required.

### PowerMonitor
- report relevant power source information;
- expose AC/battery state where supported.

### SystemEvents
- observe sleep/wake and other relevant lifecycle notifications.

### LaunchAtLoginManager
- use the current supported macOS login-item mechanism.

### AppState
- own the observable UI state;
- coordinate services without putting low-level power logic in views.

### UI
- remain small and transparent;
- never display guessed system status.

## Architecture principle

Use the minimum number of abstractions necessary to keep system APIs isolated and testable.

Do not introduce a database, network layer, backend, account system, or dependency injection framework unless a real requirement appears.
