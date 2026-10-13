# Templates polish

## Request

ok before that, I don't like the way the templates look. Names are trimmed. It'd be nice to show the icons only and the names only when going to the left with <- and the names should be shown below (only the app names, not the window name)

also there's a white square in the templates that looks weird

Also it'd be nice to assign to each template a shortcut so I can just (for example) to alt+tab+command+1 for going directly to it, I am just giving an example of a shortcut but feel free to give a better one

finally, it'd be nice to have a preview of what it's going to be save as a template if applicable, for example I have slack + chrome in each half of my screen, so when I press alt+tab, I am going to be able to see a preview in the templates box saying something like "press = to save template" or something like that, but the user is going to see what's going to be saved

## Decisions

- Compact box before `←`: previews only, stacked, each with a `⇧N` badge, no names. After `←`: wider, app names below each preview (wrap, no truncation).
- White square: replace the 1 pt preview outline with a faint filled rounded rect, no border.
- Shortcuts while the switcher is open (strip, dropdown, either box; not the search list): `⌘1–9` opens quick nav N, `⇧1–9` applies template N. Quick nav badges, Preferences labels, and README switch `⇧N` → `⌘N`; templates use `⇧N`.
- Save preview: on open, a dimmed draft of what `=` would save sits at the top of the box; hint `← then = save` outside the box, `= save` inside. Hidden when empty or when it matches an existing template.
- Window frames come from the `CGWindowListCopyWindowInfo` call the tracker already makes (front-to-back order); both draft and save use it, no per-window AX reads.
- Same PR #16, one commit per item; this file is deleted in the last commit.

## Tasks

- [x] 1. Frames from the window list: `WindowInfo` carries its frame; save builds slots from snapshot frames in front-to-back order. Check: `make test` passes with updated tests.
- [ ] 2. Shortcut swap: `⌘1–9` quick nav, `⇧1–9` templates from strip/dropdown/boxes; Preferences labels, README. Check: `make test` passes with Switcher table rows for both keys from strip.
- [ ] 3. Save draft: switcher holds the draft slots, hidden when empty or matching a template; tap computes it on open. Check: `make test` passes with draft tests.
- [ ] 4. Panel UI: compact/expanded templates box, names below previews, draft row with hints, badges `⌘N`/`⇧N`, no white outline; delete this plan. Check: `make lint && make test`; manual pass on all four request items.
