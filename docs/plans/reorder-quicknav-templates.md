# Reorder quick nav and templates

## Request

PER-22: "ziran: Be able to reorder quick nav and templates via drag&drop and shortcuts"

## Decisions

1. Shortcuts reorder only inside the quick nav / templates boxes (after → / ←); never in plain strip or dropdown. Drag works on box rows wherever the boxes are visible. Preferences Quick Nav table also gets drag.
2. Shortcut: ⌘↑ / ⌘↓ (⌥ held) moves selected row; selection follows; no wrap at edges; box hints show `⌘↑↓ reorder`.
3. Switcher box drag: drop row onto another row's position; plain click still opens/applies but fires on mouse-up when pointer didn't move; order persists on drop.
4. No Preferences Templates tab.
5. Branch `feat/reorder-quicknav-templates`, one commit per task, PR, no merge. README updated.
6. PER-22 moved to In Progress; comment PR link at end.
7. Delete this plan file in the last task's commit.

## Tasks

- [x] 1. `Switcher`: `moveQuickNav(from:to:)` / `moveTemplate(from:to:)` keys return reorder effects, box row follows moved item, ignored in list mode and out of range; `SwitcherTap` persists to `Settings` and re-sends changed lists. Check: new `SwitcherTests` cases pass in `make format && make lint && make test`.
- [x] 2. ⌘↑ / ⌘↓ in quick nav and templates modes send move keys; ⌘↑↓ in strip/dropdown do nothing; box hints updated. Check: `make test` passes; manual: ⌥Tab → → ⌘↓ moves bookmark, ⌘1 opens new first; ⌥Tab ⌘↓ in strip does nothing.
- [ ] 3. Drag to reorder rows in switcher quick nav and templates boxes; row click fires on mouse-up without drag. Check: manual: drag bookmark and template rows, reopen switcher, order kept; click still opens/applies; `make lint && make test` pass.
- [ ] 4. Drag to reorder rows in Preferences Quick Nav table. Check: manual: drag row, ⌘ numbers in table labels and switcher follow new order.
- [ ] 5. README Usage updated for reorder keys and drag; plan file deleted. Check: `make format && make lint && make test` pass; PR opened with what/why/how to test.
