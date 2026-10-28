# Ziran brand assets

Source and marketing art for the orange fox identity. Nothing in this folder ships inside the app; runtime icons live in `Resources/` and are copied by `scripts/bundle.sh`. See [GUIDELINES.md](GUIDELINES.md) for character, palette, and usage notes.

| Path | Use |
| --- | --- |
| `ziran-readme-hero.png` | README header (1600 × 640, composite artwork, not a screenshot) |
| `ziran-social-preview.png` | GitHub social preview (1280 × 640); upload manually in repository settings |
| `logos/` | Horizontal logos (color, monochrome, reversed for dark backgrounds), symbols, and wordmarks as SVG and PNG |
| `mascot/ziran-mascot-hero-1024.png` | Transparent seated fox for illustration placements |
| `palette.json`, `palette.css` | Working colors: fox orange `#FF7A20`, sunset `#FFB45B`, cream `#FFF4E5`, warm gray `#E5D8CA`, earth `#826450`, charcoal `#20272F` |
| `source/AppIcon.iconset/` | Hand-tuned app icon sizes behind `Resources/AppIcon.icns` (simplified head at small sizes) |
| `source/ZiranMenuBarTemplate.svg` | Editable source for the menu bar template PNGs |

Runtime files in `Resources/`:

- `AppIcon.icns` is copied into the bundle as-is; `AppIcon.png` is the large source and a fallback when the ICNS is missing.
- `ZiranMenuBarTemplate.png` (18 px) and `ZiranMenuBarTemplate@2x.png` (36 px) are loaded at 18 points as a template image, so macOS tints them for light, dark, and selected menu bars.

The large illustrations were extracted and resampled from the approved flattened concept board; they are not layered high-resolution masters. Pose panels, minimal icon alternatives, Icon Composer layers, web favicons, and preview sheets stayed in the delivery kit and are not part of this repository.
