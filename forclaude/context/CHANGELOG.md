# Changelog

Keep this concise. Record meaningful milestones only.

## 2026-09-14
- Initialized project specification.
- Added modular Claude Code context architecture.
- Added session handoff and technical research files.
- Phase 1/2: researched macOS power-management APIs directly from Apple's shipped headers (`IOPMLib.h`, `SMAppService.h`) and `man caffeinate`; recorded 5 durable decisions (assertion type, closed-lid honesty, no lid-state detection, SMAppService/macOS 13 floor, SwiftPM+build.sh).
- Phase 3: implemented `ClaudeKeepAwake` as a Swift Package — menu-bar SwiftUI app with `SleepManager`, `PowerMonitor`, `SystemEvents`, `LaunchAtLoginManager`, `AppState`, and a small UI layer.
- Phase 4: 26 passing XCTest cases; manually verified real assertion lifecycle via `pmset -g assertions` on hardware.
- Phase 5: `build.sh` assembles and ad-hoc codesigns `ClaudeKeepAwake.app`; verified the built app end-to-end (launch, Start Active, assertion visible while active, clean release on quit, no Dock icon, no stray login-item registration).
- Phase 6: wrote `ClaudeKeepAwake/README.md` with install/usage/build/uninstall/troubleshooting and a prominent closed-lid limitations section.
