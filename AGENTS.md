# DAW Flutter Web — Agent Instructions

## Project

This is a Flutter Web digital audio workstation.

Main stack:
- Flutter Web
- Riverpod
- go_router
- desktop_drop
- Web Audio API / dart:js_interop
- IndexedDB persistence

This is an existing mature project.
Inspect and extend the current architecture instead of rebuilding features from
scratch.

---

## Architecture Principles

Preserve existing stable systems unless the requested task requires changes.

Important existing architecture includes:
- stable Track / Clip / Audio Source IDs
- shared timeline coordinate system
- horizontal and vertical scrolling
- Web Audio playback scheduling
- per-track mixer routing
- Track FX rack
- offline WAV export
- Undo / Redo
- .fldawproj Save / Open
- IndexedDB autosave / recovery
- project dirty-state tracking

Prefer stable IDs over list indexes.

New persistent entities must use the existing centralized collision-safe ID
generator.

Do not regenerate valid persistent IDs when loading projects.

Do not place large new feature implementations entirely inside editor_page.dart
when a dedicated model/controller/service/widget would be clearer.

Reuse existing helpers and architecture before creating parallel systems.

---

## Audio Architecture

Preserve the current Web Audio graph unless the task explicitly requires a
routing change.

Runtime Web Audio objects must not be serialized.

Persistent project state and runtime audio state must remain separated.

Do not decode or duplicate audio unnecessarily.

Shared clips may reference the same Audio Source.

Live playback and offline WAV export should use equivalent processing semantics.

Web Audio timing must use the audio clock, not Dart Timer-based audio scheduling.

---

## UI Direction

The UI should feel like a compact desktop DAW.

Prefer:
- compact controls
- thin borders
- restrained surfaces
- small border radius
- anchored floating panels
- DAW-style knobs and mixer controls
- clear active/bypass states

Avoid:
- oversized Material UI
- excessive rounded cards
- mobile-style control layouts
- unnecessary permanent controls in track headers

Do not block the native browser context menu unless explicitly required.

---

## Persistent Feature Requirements

When adding new persistent project state, integrate it with:

- authoritative project model
- Undo / Redo where appropriate
- dirty state
- IndexedDB autosave / recovery
- .fldawproj Save / Open
- backward-compatible defaults for older projects

Runtime state, selection, hover state, Web Audio nodes, meters, and temporary drag
previews must not be serialized.

---

## Validation Efficiency

Use focused validation appropriate to the change.

Do not repeatedly retry validation methods that are already known to fail
deterministically because of this project's environment or tooling.

If validation method A is a known environment/tooling failure and method B is
the established working equivalent, use method B directly on future tasks.

Do not claim method A passed.

It may be reported as:

"Known environment limitation — not retried; equivalent validation performed
with <method B>."

Retry a failed command only when:
- the failure may be caused by the current code change, or
- something was changed that could fix that exact failure.

Do not repeatedly rerun an unchanged failing command.

Preferred validation order:

1. Targeted tests for changed logic when useful and available.
2. flutter analyze --no-pub
3. Browser runtime validation when Web Audio, JS interop, pointer interaction,
   or browser behavior changed.
4. flutter build web --no-pub only when build-level verification is genuinely
   useful.

Do not automatically run the entire Flutter test suite for every small feature.

Do not weaken tests, add skips, suppress real errors, or change assertions just
to produce green output.

If something cannot be verified using a working method, report it as BLOCKED,
not PASSED.

Avoid unrelated environment troubleshooting and retry loops.

---

## Browser Testing Cleanup

Browser testing must not leave generated artifacts in the repository.

Do not leave:
- Chrome profile directories
- .meter-chrome-profile-* directories
- temporary .fldawproj files
- generated WAV test files
- screenshots
- logs
- disposable browser test artifacts

Use a system temporary directory for browser profiles when possible.

Do not run flutter clean unless explicitly requested.

Before finishing:

git status --short

Do not delete source files, project assets, user audio, Pub cache, FVM, or the
Flutter SDK as cleanup.

---

## Task Scope

Work only on the requested task.

Before implementation, inspect the minimum relevant existing architecture.

Avoid broad refactoring unless it is necessary to implement or fix the requested
behavior.

Preserve stable existing behavior and avoid regressions.

Keep the final report concise:
- important files changed
- implementation approach
- validation performed
- anything blocked or not verified