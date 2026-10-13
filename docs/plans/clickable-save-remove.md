# Clickable save and remove

## Request

Make templates (and quick nav) save/remove clickable, not only `=` / `−`.

## Decisions

- `+` next to the "Templates" heading does the same as `=`; shown only while the dimmed draft is shown (so never a duplicate).
- `×` on each template row, shown on pointer hover, does the same as `−` for that row; deletes immediately, no confirmation.
- Same hover `×` on quick nav rows.
- Keyboard keys unchanged; buttons are pointer extras.
- Separate PR on `feat/clickable-save-remove`; this file is deleted in the last commit.

## Tasks

- [x] 1. Switcher: keys to remove template N and quick nav item N from any non-list mode (save already has `.saveTemplate`), with `@Test(arguments:)` tests. Check: `make test` passes, zero warnings.
- [ ] 2. Panel: `+` by the Templates heading, hover `×` on template and quick nav rows sending those keys; delete this plan. Check: `make lint && make test`; manual: `+` saves and disappears, `×` appears on hover and removes the right row, keys unchanged.
