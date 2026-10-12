# Steam store art — Grimoire

Everything here comes from `tools/store_art.py`. Don't edit the PNGs by hand: change the script and run it again.

| File | Size | Steamworks field |
|---|---|---|
| `header_capsule_920x430.png` | 920×430 | Store Assets → **Header Capsule** |
| `small_capsule_462x174.png` | 462×174 | Store Assets → **Small Capsule** |
| `main_capsule_1232x706.png` | 1232×706 | Store Assets → **Main Capsule** |
| `vertical_capsule_748x896.png` | 748×896 | Store Assets → **Vertical Capsule** |
| `page_background_1438x810.png` | 1438×810 | Store Assets → **Page Background** (optional) |
| `library_capsule_600x900.png` | 600×900 | Library Assets → **Library Capsule** |
| `library_header_920x430.png` | 920×430 | Library Assets → **Library Header** |
| `library_hero_3840x1240.png` | 3840×1240 | Library Assets → **Library Hero** (no text; Steam places the logo over it) |
| `library_logo_1280x720.png` | 1280×720, transparent | Library Assets → **Library Logo** (in the logo editor, position it bottom-left over the hero) |
| `community_icon_184x184.png` | 184×184 | Community → **Community Icon** |
| `screenshots/en/*.png`, `screenshots/pt_BR/*.png` | 1920×1080 | Store Assets → **Screenshots** (one set per language) |

Each file is well under Steam's size limits. The largest is the hero at about 650 KB.

## How the art is made

- **Background of every capsule:** the game's own world, rendered by the engine at the asset's exact size, with no HUD. That uses `screenshot_enemy_scene` with `ENEMY_SCENE_WORLD_ONLY=1` and `ENEMY_SCENE_VIRTUAL=WxH`. The portrait capsules are rendered wide and then cropped in the middle. Rendered narrow, the edge trees swallow the frame.
- **Boss in the foreground:** the original sprite, scaled by a whole-number factor (nearest neighbour). It gets a contact shadow and a dusk tint so it matches the scene's lighting.
- **Logo "GRIMOIRE":** drawn pixel by pixel from the game font's native 8px glyphs (`assets/fonts/pixel.ttf`). Each glyph is stretched 3:2 vertically, then gets a gold metal bevel (the UI's aged gold), a double ink and dried-blood outline and a drop shadow, and is scaled up by a whole number. No vector text and no smoothing. The small capsule is composed at 2x and reduced by nearest neighbour, so the logo stays readable at its real size.
- **Community icon:** the logo's "G" over the UI's wax seal (`assets/sprites/ui/seal_common.png`).
- There are no review quotes, awards or extra text anywhere, as Steam's rules require.

## Screenshots (captured from the real game, 1920×1080)

1. Main menu
2. Class selection (emblems)
3. Road battle with the damage preview and the enemy's intent
4. Boss room (act 3, with a heavy-attack intent)
5. Shop (relics, packs, Scribe's Dice)
6. Road fork (battle / rest / shop)
7. Card collection
8. Victory screen

These are clean frames: no start-of-run toasts (`ENEMY_SCENE_CLEAN=1`), no empty top-bar strip (`STORE_NOTOPBAR=1`) and a fully revealed catalogue (`STORE_REVEAL=1`). `TOOL_WINDOW=1920x1080` opens the capture window at that size before the tool builds its layout, and `TOOL_LOCALE` picks the language.

## Regenerating

```bash
python tools/store_art.py capture   # renders the world backgrounds (~1 min each)
python tools/store_art.py build     # composes capsules, hero, logo, icon
python tools/store_art.py shots     # screenshots en + pt_BR
python tools/store_art.py sheet     # contact sheet → steam/store/_contact_sheet.png
```
