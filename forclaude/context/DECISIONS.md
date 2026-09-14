# Durable technical decisions

Record only decisions that are likely to remain useful across future sessions.

Format:

## YYYY-MM-DD — Decision
**Decision:** ...
**Reason:** ...
**Rejected:** ...
**Consequence:** ...

## Initial constraints

### 2026-09-14 — Native macOS utility
**Decision:** Build as a native macOS utility rather than Electron.
**Reason:** The app is tiny and needs direct, reliable access to macOS power-management APIs with minimal resource use.
**Rejected:** Electron unless a compelling requirement appears.
**Consequence:** Prefer Swift/AppKit/SwiftUI.

### 2026-09-14 — No direct Claude Code integration for MVP
**Decision:** Keep the core utility independent of Claude Code.
**Reason:** The actual problem is system sleep, and independence makes the utility simpler and useful for other workloads.
**Rejected:** Terminal parsing, PTY control, process injection.
**Consequence:** The core state is Keep Awake ON/OFF, not Claude session state.

## Phase 1/2 research decisions

### 2026-09-14 — Use kIOPMAssertPreventUserIdleSystemSleep, called directly via IOKit
**Decision:** Create exactly one IOPM assertion, `kIOPMAssertPreventUserIdleSystemSleep` at `kIOPMAssertionLevelOn`, via `IOPMAssertionCreateWithName`/`IOPMAssertionRelease` called directly in-process. Do not shell out to `caffeinate`.
**Reason:** Confirmed via Apple's shipped `IOPMLib.h` that this is the supported assertion matching `caffeinate -i` semantics (idle system sleep only; display may still sleep normally, saving battery). Direct IOKit calls give structured `IOReturn` errors and a retained `IOPMAssertionID` instead of subprocess/exit-code plumbing.
**Rejected:** `caffeinate` subprocess wrapping; `kIOPMAssertPreventUserIdleDisplaySleep` as the primary assertion (keeps display lit unnecessarily); `kIOPMAssertionTypePreventSystemSleep` (confirmed **deprecated since 10.9 and unsupported on any OS X release** per the header itself — do not use, despite being named in the original research brief).
**Consequence:** `SleepManager` owns a single assertion ID; no subprocess management anywhere in the app.

### 2026-09-14 — Closed-lid honesty
**Decision:** The app must never claim that `ACTIVE` guarantees the Mac stays awake with the lid closed. UI/README state plainly that Keep Awake prevents idle sleep while the lid is open, and closed-lid operation additionally requires the user's own clamshell-mode setup (AC power + external display), which the app does not control or verify.
**Reason:** Apple's own header text says a `PreventUserIdleSystemSleep` assertion does not override lid-close sleep ("the system may still sleep for lid close... or other sleep reasons"). This is a firmware/hardware-level behavior no user-space assertion can defeat. See `TECHNICAL.md`.
**Rejected:** Any UI/copy implying guaranteed closed-lid operation.
**Consequence:** README/troubleshooting carries an explicit, prominent closed-lid limitations section.

### 2026-09-14 — No lid-state detection
**Decision:** The app does not attempt to detect or display lid open/closed state.
**Reason:** No public, documented Apple API exists for this. The only known technique (`AppleClamshellState` IORegistry key) is undocumented/private. Project constraints require official APIs and forbid displaying guessed values.
**Rejected:** Reading `AppleClamshellState` via IORegistry.
**Consequence:** Status UI never shows a "Lid" field.

### 2026-09-14 — SMAppService for Launch at Login; macOS 13.0 minimum
**Decision:** Use `SMAppService.mainApp` (register/unregister/status) for Launch at Login. Minimum deployment target macOS 13.0.
**Reason:** Confirmed via `SMAppService.h` this is the current, non-deprecated login-item API (older `SMLoginItemSetEnabled`/`LSSharedFileList` mechanisms are legacy). SwiftUI `MenuBarExtra` also requires macOS 13.0+, and is the modern replacement for hand-rolled `NSStatusItem` plumbing — using both lets the whole app target one OS floor.
**Rejected:** `SMLoginItemSetEnabled` + separate login-helper target; hand-rolled `NSStatusItem` menu bar UI.
**Consequence:** App requires macOS 13 Ventura or later.

### 2026-09-14 — SwiftPM package + build.sh assembling a real .app bundle
**Decision:** Build as a Swift Package (`Package.swift`, executable target), not a hand-authored `.xcodeproj`. `build.sh` runs `swift build -c release` then assembles a proper `ClaudeKeepAwake.app` bundle (`Contents/MacOS`, `Contents/Info.plist` with `LSUIElement=true`, ad-hoc codesign).
**Reason:** A hand-written `.xcodeproj`/`project.pbxproj` is fragile to author and maintain outside Xcode. SwiftPM is CLI-buildable, reproducible, and still opens directly in Xcode (`open Package.swift`). `SMAppService` and menu-bar-only presentation (`LSUIElement`) need a real `.app` bundle with `Info.plist` and a stable bundle identifier — a bare SwiftPM executable isn't sufficient — so `build.sh` assembles one post-build rather than relying on Xcode project generation.
**Rejected:** Hand-authored `.xcodeproj`; shipping a bare unbundled executable.
**Consequence:** Source lives under `ClaudeKeepAwake/Sources/...` per Swift Package layout; `Info.plist` is a template consumed by `build.sh`, not compiled in as a SwiftPM resource.

## Rule

Do not record temporary implementation details here. Put current work in `SESSION.md`.
