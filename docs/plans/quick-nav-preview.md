# Quick nav preview

## Request

looks great! I would LOVE to see that preview in the quick nav as well! Instead of having the label from quick nav changing, it'd be nice to have a new row as preview

## Decisions

- The changing quick nav footer (`− bookmark · Name`) is replaced by a dimmed row at the top of the quick nav box: the icon and name of what `−` would save, with `− bookmark` (or `− remove` when already saved) under it. It follows the selection and is hidden when there is nothing to bookmark.
- Finder folders: generic folder icon plus the window title; no AppleScript on redraw.
- Separate PR on `feat/quick-nav-preview`; this file is deleted in the last commit.

## Tasks

- [x] 1. Tap: replace the `bookmarkHint` string passed to the panel with the bookmark candidate (name, icon, saved). Check: `make build` zero warnings, `make test` passes.
- [ ] 2. Panel: dimmed preview row at the top of quick nav, footer hint removed; delete this plan. Check: `make lint && make test`; manual: row follows selection, `− bookmark`/`− remove` correct, Finder folder shows folder icon.
