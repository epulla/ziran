---
name: ui-separator
description: Ziran's rule for joining pieces of text shown in the UI - use " · " (middle dot) as the only separator. Use whenever adding or changing any user-visible string in Ziran that combines two or more parts, such as key hints, the strip app/title label, window rows, bookmark hints, menu items, or Preferences labels, even if the user doesn't mention separators.
---

# UI separator

Ziran joins parts of a user-visible string with a middle dot surrounded by single spaces: `" · "` (U+00B7). The key hints already use it (`⇥ next app · ↑ search · ↓ windows`), and every other combined label should read the same way so the panel looks like one design rather than a mix of styles.

## Use

- Between app name and window title: `Chrome · Inbox`
- Between an action and its target: `− bookmark · Downloads`
- Between hint items: `↑↓ move · ↩ switch · esc close`

## Avoid as separators

- Hyphen `-`, en dash `–`, em dash `—`
- Parentheses around the second part: `bookmark (Downloads)`
- Pipes `|`, slashes `/`, colons `:`

## Not separators

- Parentheses that qualify a single item stay: `Downloads (folder)`.
- `−` (U+2212) in hints is the minus key glyph, not a separator; leave it.
- `⌘`, `⌥`, `⇧`, `⇥`, `↩` and arrows are key glyphs.

## Checklist when touching UI strings

1. Search `Sources/` for `" — "`, `" - "`, `" – "` and `(\(` in string literals near the change.
2. The Preferences preview label in `PreferencesWindow.swift` mirrors the window row format in `SwitcherPanel.row`; change both together.
3. Keep hints in sync with key handling (see `AGENTS.md`).
