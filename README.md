# Ziran

Ziran is a macOS window switcher and keyboard-driven window snap tool with saved layouts.

## Requirements

- macOS 14+
- Swift 6 Command Line Tools
- Accessibility permission

## Build

```sh
make build
make test
make bundle
open dist/Ziran.app
```

Grant Accessibility in **System Settings → Privacy & Security → Accessibility**. Ad-hoc signing resets this grant after each rebuild. Create self-signed certificate **Ziran Dev** in Keychain Access → Certificate Assistant, then use `SIGN_IDENTITY="Ziran Dev" make bundle`.

## Keymap

| Feature | Keys |
| --- | --- |
| Switcher | Option-Tab, Tab, Shift-Tab, Down, Up, Enter, Escape |
| Snap | Control-Option + Left/Right/Up/Down halves, Return maximize, C center, D/F/G thirds, E/T two-thirds, U/I/J/K quarters |
| Displays | Control-Option-Command + Left/Right |
| Layouts | Control-Option-Shift + 1…9 |

Quit Rectangle before using Ziran's snap keys.

Layouts are stored at `~/Library/Application Support/Ziran/layouts.json`.

## Limitations

Only current Space is supported. Apps that are not running are skipped during restore.
