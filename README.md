# No Sleep Claude

A tiny native macOS menu-bar utility that stops your Mac from falling asleep while something long-running is going on — a Claude Code session, a build, a download, a training job — without touching Claude Code itself, the network, or anything security-sensitive.

## Why this exists

macOS puts an idle Mac to sleep after a few minutes of no keyboard/mouse activity, which kills any unattended long-running local process. This app just tells macOS "don't do that" using the same public, documented mechanism `caffeinate -i` uses (`IOPMAssertionCreateWithName` / `PreventUserIdleSystemSleep`) — nothing more. No daemons, no kernel extensions, no sudo, no telemetry.

Click the menu bar icon to toggle it on/off. That's the whole app.

## Quick start

**Requirements:** macOS 13 (Ventura) or later, and Xcode Command Line Tools (`xcode-select --install`) — not full Xcode.

```
git clone https://github.com/tiredjon/nosleepclaude.git
cd nosleepclaude/ClaudeKeepAwake
./build.sh
cp -R "No Sleep Claude.app" /Applications/
open "/Applications/No Sleep Claude.app"
```

Building it yourself this way means macOS never flags it as a suspicious download — no security warnings, nothing to bypass. The moon icon in your menu bar means it's off; click it and enable Keep Awake to turn it into a bolt.

**Optional:** in the dropdown, turn on **Launch at Login** so it's always running without you thinking about it.

**If someone sent you a pre-built `.app`/`.zip` instead of you building it:** this project isn't signed by a paid Apple Developer account, so macOS will refuse to open it normally the first time. Right-click the app and choose **Open** (then confirm "Open Anyway") instead of double-clicking — one-time only.

## What it does and doesn't do

- Prevents *system* idle sleep only. The display can still dim/sleep normally to save power.
- Does **not** read, control, or touch Claude Code (or any other app), the network, or any account.
- Does **not** keep the Mac awake with the **lid closed** unless you've separately set up real clamshell mode (AC power + an external display) — closing the lid always force-sleeps the machine regardless of this app. See `ClaudeKeepAwake/README.md` for the full explanation.
- Uses only public Apple APIs (IOKit, ServiceManagement/SMAppService, NSWorkspace). No sudo, no kernel extensions, no SIP changes.

## Full documentation

This root README is just the quick-start. For usage details, diagnostics/troubleshooting commands, uninstall steps, architecture, and the full closed-lid explanation, see **[`ClaudeKeepAwake/README.md`](ClaudeKeepAwake/README.md)**.

## Repo layout

```
ClaudeKeepAwake/   the app itself: Swift package, source, tests, build.sh, full README
forclaude/         internal research/design notes from building this — not needed to use the app
```

This is a personal/friends-shared project, not a published package — build it from source and use it as you like.
