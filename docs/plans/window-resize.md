# Window resize shortcuts

## Request

> feat (shortcuts for resizing windows): do the same as rectangle https://github.com/rxhanson/Rectangle

> can we leave the core resize actions only?

> default, show when clicking ziran icon at the top of the page

## Decisions

- Actions: left/right/top/bottom halves, corners, maximize, center, restore, next/previous display.
- Shortcuts are fixed Rectangle defaults, with no rebinding:
  - ⌃⌥←→↑↓: halves
  - ⌃⌥U/I/J/K: top-left/top-right/bottom-left/bottom-right corners
  - ⌃⌥↩ or ⌃⌥F: maximize (F added at the user's request)
  - ⌃⌥C: center
  - ⌃⌥⌫: restore
  - ⌃⌥⌘←→: next/previous display
- Repeating a left/right half shortcut cycles ½ → ⅔ → ⅓. Repeating top/bottom does nothing new.
- Cycle position is worked out from the window's current frame, so the layout math stores no state.
- Restore returns the window to the frame it had before its first Ziran resize.
- Layouts use the screen's visible frame (no menu bar or Dock) on the screen containing the window's center.
- Preferences → General gets a "Window shortcuts" checkbox, on by default.
- The menu-bar menu gets a "Window" submenu listing each action with its shortcut. Clicking an item applies it to the window that was in front.
- `AX.setFrame` and `AX.flip` already exist and get reused.
- This plan file is deleted in the last task's commit.

## Tasks

- [x] Pure `Layout` geometry: action + visible frame + current frame → target frame, covering halves with cycling, corners, maximize, center, and display moves. Check: `make test` passes with new `LayoutTests` table cases.
- [x] Hotkeys in the event tap apply layouts to the focused window, with restore. Check: manually run every shortcut on a Finder window and a Chrome window, including the display move on two screens.
- [ ] "Window shortcuts" setting, plus the menu-bar "Window" submenu; turning the setting off disables the hotkeys. Check: `make test` passes with a new `Settings` test, and manually confirm the submenu applies actions and the toggle works.
- [ ] Document the shortcuts in `README.md` and delete this plan file. Check: `make format && make lint && make test` passes.
