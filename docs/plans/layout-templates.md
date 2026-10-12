# Layout templates

## Request

- feat (screen manager, placed at the left side of the. strip view): macos screen manager, Ziran can help with managing screens (close, order, create apps and windows). There should be a box for each screen, also
- feat (template in the screen manager) there should be templates for app window resizing (quarter, half-left, etc), for example I have a half left with Chrome and half right with Slack, and the window box can have a template of that so I can quickly open it

## Decisions

- Spaces/desktops are out (no public API). Per-display boxes dropped: the left box is templates only.
- Keys: `←` from strip or dropdown opens the templates box; `↑↓` move; `→` back; release `⌥` (or `⏎`) applies; `=` saves; `−` removes; `⌥1`–`9` apply directly.
- A template is a name plus slots of (bundle ID, `Layout.Action`). No custom fractions, not tied to a display.
- Save: visible windows on the display the switcher is showing on, each snapped to its nearest `Layout.Action`; auto-named from app names joined with ` · `. No Preferences tab, no rename/reorder.
- Apply: on the display the switcher is showing on. Launch missing apps, wait up to 5 s for a window, place each app's MRU window into its slot. Other windows untouched.
- Box always visible, even empty, with hint `= save layout`.
- One PR. This file is deleted in the last task's commit.
- Assumed: an app with several windows on the display is saved once, using its MRU window.
- Assumed: snapping picks the action whose frame overlaps the window most; `center` is never picked.

## Tasks

- [x] 1. Template model: `LayoutTemplate` persisted in `Settings.layoutTemplates`, plus `Layout` snap-to-nearest-action helper. Check: `make test` passes with new Settings and Layout tests.
- [x] 2. Switcher state: `.templates` mode, keys and effects (apply/save/remove, templates-changed). Check: `make test` passes with new Switcher table tests.
- [x] 3. System side: `SwitcherTap` key mapping and effects; save reads visible windows' AX frames on the panel display; apply launches apps, waits ≤5 s, sets frames. Check: `make build` with zero warnings, `make test` passes.
- [ ] 4. Panel UI: left templates box, hints, `Layout.panelX` reserving both side panels; delete this plan. Check: `make lint && make test` pass; manual: save Chrome · Slack halves, rearrange, apply restores; quit Slack, apply relaunches it.
