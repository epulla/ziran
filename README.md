# Ziran

Keyboard-first window switcher for macOS (menubar app, macOS 14+).

## Install

Build app bundle:

```sh
make bundle
open dist/Ziran.app
```

Grant Accessibility permission in System Settings → Privacy & Security →
Accessibility. The app is ad-hoc signed. After rebuilding, you may need to
remove and re-add Ziran in Accessibility settings.

## Usage

| Key or action | Result |
| --- | --- |
| ⌥Tab | Open app strip |
| ⌥⇧Tab | Select previous app in strip |
| ↓ | Open window dropdown for selected app |
| ↑ | Open filterable list of all windows |
| Release ⌥ or press ↩ | Switch to selected item |
| Esc | Close switcher |
| = | Pin or unpin selected window in strip or dropdown |
| ⌘1–9 | Jump straight to Nth item in current view |
| Hover | Select item |
| Click | Switch to item |
| Scroll | Move selection |
| Pin icon | Pin item |

Pins last until Ziran quits and sort first.

## Preferences

Open menubar icon → Preferences… (⌘,).

- Font size: 11–28 pt
- Icon size: 48–160 pt for strip tiles
- Launch at login

## Development

```sh
make build
make test
make lint
make format
make bundle
make run
```

Swift 6, SwiftPM, no dependencies. See `AGENTS.md` for conventions.

## Acknowledgements

The switcher panel and preferences design are adapted from [AltTab](https://github.com/sr3d/AltTab) by Alex Le, used under the MIT License (Copyright (c) 2026 Alex Le).

## License

MIT — see [LICENSE](LICENSE).
