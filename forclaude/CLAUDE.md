# Claude Keep Awake — navigation

## Rule
This file is an INDEX, not a knowledge dump. Keep it short. Do not put large specifications, history, logs, or implementation details here.

## Current project
A small native macOS menu-bar utility that prevents system sleep while enabled, intended to keep long-running terminal workloads such as Claude Code alive. The app must use supported macOS mechanisms and must be honest about closed-lid limitations.

## Context map
- `context/PROJECT.md` — complete product specification and requirements.
- `context/TECHNICAL.md` — macOS sleep/lid behavior, APIs, constraints, research findings.
- `context/ARCHITECTURE.md` — chosen code/project architecture and responsibilities.
- `context/DECISIONS.md` — durable technical decisions and their reasons.
- `context/SESSION.md` — current phase, progress, blockers, next actions.
- `context/TESTING.md` — test plan and observed results.
- `context/CHANGELOG.md` — concise project history.

## Session protocol
1. Read this file first.
2. Read only the context file(s) needed for the current task.
3. Before implementation, read `TECHNICAL.md` and `DECISIONS.md`.
4. After meaningful work, update `SESSION.md`.
5. Do not duplicate large content between files.
6. If a fact belongs in a specific context file, put it there instead of expanding this file.

## Priority
Correctness > macOS compatibility > reliability > simplicity > UX > extra features.

## Workflow
Research → Design → Implement → Test → Build → Document.
Do not declare the closed-lid requirement solved without clearly testing or documenting the actual macOS limitation.
