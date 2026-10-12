# AGENTS.md

Ziran is a keyboard-first menubar window switcher built with Swift 6, AppKit, SwiftPM, macOS 14+, and no dependencies.

## Keyboard-first

- Every action has a keyboard shortcut; mouse and pointer input are optional extras, never the only way.
- Each view shows hints for the keys that work in it; keep hints in sync when changing key handling.

## Commands

- `make build` - Build debug executable.
- `make test` - Run test suite with Command Line Tools Swift Testing flags; use this instead of bare `swift test`.
- `make lint` - Check Swift formatting across Sources and Tests.
- `make format` - Apply Swift formatting across Sources and Tests.
- `make bundle` - Build release app bundle, ad-hoc sign it, and write `dist/Ziran.app`.
- `make run` - Build and run executable through SwiftPM.
- `make clean` - Remove SwiftPM build artifacts.

`dist/Ziran.app` needs Accessibility permission to install its keyboard event tap and control windows.
`make bundle` uses release configuration by default and signs with the ad-hoc identity unless overridden.
Set `APP_VERSION`, `BUILD_NUMBER`, `ARCHS`, or `SIGN_IDENTITY` when producing a customized bundle.

## Architecture

- `AppDelegate.swift` - Creates menubar status item and menu, requests Accessibility, and starts tracking and event capture.
- `AX.swift` - Wraps Accessibility APIs for window discovery, metadata, geometry, focus, and coordinate conversion.
- `MRU.swift` - Defines `WindowInfo` and pure ordering, app grouping, window filtering, and fuzzy query helpers.
- `PreferencesWindow.swift` - Renders General and About preference tabs, font/icon size controls, and login registration.
- `Settings.swift` - Stores clamped font-size and icon-size preferences in configurable `UserDefaults`.
- `Switcher.swift` - Pure state machine for closed/strip/dropdown/list modes; keys produce state updates or focus/close effects.
- `SwitcherPanel.swift` - Renders `Switcher` state, handles search and pointer input, and sends keys through `onKey`.
- `SwitcherTap.swift` - Maps CGEvent keyboard input to `Switcher.Key`, opens the switcher, and runs produced effects.
- `WindowTracker.swift` - Observes app activation and focused-window changes, maintains AX elements and focus timestamps, and builds MRU snapshots.

All state changes go through `Switcher.handle` or `Switcher.open`; UI and event tap code never mutate switcher state directly.

## Conventions

- Swift format uses 4-space indentation and 160-column lines.
- Use Swift 6 strict concurrency; mark AppKit types `@MainActor`.
- Use `private(set)` for state exposed for reading but controlled by its owner.
- Keep enum cases on one line when practical; omit file headers.
- Add comments only for non-obvious why, not obvious what.
- Prefer minimal code; do not add speculative abstractions.
- Tests use Swift Testing: `@Test`, `#expect`, and `@Test(arguments:)` tables.
- Every behavior change in `Switcher` or `Settings` gets a test.
- Settings tests use `UserDefaults(suiteName: "ZiranTests")` and clean the suite afterward.
- Keep pure state and ordering logic independent from AppKit where practical.
- Keep Accessibility and CGEvent integration at system boundaries.
- Preserve existing access levels unless API exposure has concrete need.
- Use descriptive names and direct control flow over clever compression.

## Workflow

- Before commit, run `make format && make lint && make test`.
- Keep build warnings at zero.
- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `style:`, or `refactor:`.
- Keep formatting-only changes in separate `style:` commits.
- Keep one concern per PR.
- PRs include what changed, why, and how to test it.
- Do not merge without review.
- Releases: use the `release` skill (`.agents/skills/release`); pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`.
- Third-party attribution lives only in `README.md`.
- Verify keyboard and Accessibility behavior manually when changing event handling.
- Verify bundle launch and permission flow when changing app startup or packaging.
