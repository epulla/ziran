# Quick nav

## Request

> let's do the 'Quick actions' (rename it to quick navigation) from AltTab. As you said, Ziran's philosophy is keyboard-first, so there should be any shortcuts to 'pin' & to move to the 'quick navigation'. The quick navigation can have closed or quit apps tho, if they are closed/quit, they can be opened/started.

> sorry I meant 'Quick Jump' from AltTab

> default, missing files/apps just get removed from the quick navigation, also let's name the box as 'quick nav'

> default, let's use the arrow+right to go to quick nav

> sounds good, don't forget to show the available shortcuts so the user always know what they can do

> you know what, let's not show the quick nav view at the search view

## Decisions

- Items can be apps, folders, files and URLs, saved in `UserDefaults` so they survive restarts.
- Items open the normal macOS way (`NSWorkspace.open`): a running app comes forward, a quit app launches, a file opens in its app, a URL opens in the browser.
- Bookmarks whose file or app no longer exists are removed from quick nav.
- The box is titled "Quick nav". It's a separate rounded panel in the switcher's style, 12 pt to the right of the switcher and top-aligned, or on the left when there's no room (user changed this from a column inside the panel). It shows in the strip and dropdown views only, not in search, including when no bookmarks exist. Items are numbered ⇧1–9.
- The box's hint names what ⌥− will save for the selected window ("⌥− adds ziran (folder)", or "removes" when already saved), because Ghostty's document is its working folder and that surprised the user. Finder is named from the window title, so the hint avoids running AppleScript.
- Keys:
  - ⌥⇧1–9: open the Nth item directly
  - → (strip/dropdown): move the selection into quick nav
  - ↑/↓: move within quick nav
  - ↩: open the selected item
  - ←: go back
- ⌥− on a selected window toggles a bookmark for it, choosing in this order:
  1. the window's document (`AXDocument`)
  2. the folder, for a Finder window
  3. otherwise, the app
- ⌥− on a quick nav item removes it.
- Preferences gets a "Quick Nav" tab: + adds files, folders, apps or a URL; items can be reordered and removed. No drag-and-drop.
- A hint line at the bottom of the panel shows the shortcuts for the current view (strip, dropdown, search, quick nav). It replaces the current arrow hints.
- Finder windows have no folder in Accessibility (`AXDocument` is empty, and the title-bar icon only reports "Macintosh HD"). ⌥− asks Finder over AppleScript for every window's name and folder, then picks the window whose name matches the selected window's title. No match, or more than one match, means a beep and no bookmark. This triggers a one-time Automation prompt and needs `NSAppleEventsUsageDescription` (user approved).
- Chrome and other apps that report `AXDocument` (page URL or file) get that page or file bookmarked, not the app (user approved).
- This plan file is deleted in the last task's commit.

## Tasks

- [x] Bookmark storage in `Settings`: an ordered list with add, remove and move (done by assigning the array), and missing files dropped on read. Check: `make test` passes with new `SettingsTests`.
- [x] `Switcher` quick nav state: →/← enter and leave from strip/dropdown, ↑/↓/↩ inside it, ⌥⇧1–9 open, ⌥− toggles a bookmark or removes an item. Check: `make test` passes with new `SwitcherTests` table cases.
- [x] Panel renders the "Quick nav" box. The tap maps the keys and works out what ⌥− should bookmark, and opening goes through `NSWorkspace`. Check: manually bookmark a TextEdit document, a Finder folder, an app and a quit app, then open each by key.
- [ ] Hint line at the bottom of the panel for each view. Check: manually confirm the hints match the working keys in strip, dropdown, search and quick nav.
- [ ] Preferences "Quick Nav" tab with add, URL entry, reorder and remove, and delete this plan file. Check: manually add and reorder items and see them in the switcher; `make format && make lint && make test` passes.
