# Generated art: credits and log

All PixelLab art was made with `create_image_pro`, with a style image from the Runemoire game
(card-game-love2d/assets) and style_copy = palette, outline, detail and shading. Each image was then
alpha-thresholded (128) and cropped, at native pixel scale. The scripts are in `tools/pixellab/`
(`plab.py` generates, `finalize.py` picks and post-processes, `handdrawn.py` draws the tiny
particles), and the per-call log is `tools/pixellab/generations.log.jsonl`. A cost listed on one
line of a family covers every file in that family. Rejected rounds are listed as 0-file lines.

| file | tool | size | gens | prompt summary |
|---|---|---|---|---|
| tome_closed.png | create_image_pro (style: menu.png altar crop, ref: seal.png) | 114x77 | 15 (+15 rejected round, 3/4 view) | closed oxblood grimoire, straight front view, gold corners, compass-star seal, red ribbon |
| runes/rune_fields.png | create_image_pro (style: highlands_runestone_0) | 26x31 | 10 | carved sandstone tablet, wheat-gold glowing invented glyph |
| runes/rune_highlands.png | same | 26x31 | 10 | blue slate tablet, electric blue lightning glyph |
| runes/rune_abyss.png | same | 26x31 | 10 | cracked basalt tablet, lava-orange glyph |
| runes/rune_frost.png | same | 26x31 | 10 | frosted granite tablet, icy cyan six-way star glyph |
| runes/rune_marsh.png | same | 26x31 | 10 | mossy stone tablet, toxic green curl glyph |
| runes/rune_dusk.png | same | 26x31 | 10 | violet stone tablet, rose-gold crescent glyph |
| runes/rune_eclipse.png | same | 26x31 | 10 | dark obsidian tablet, white-gold corona ring glyph |
| cursors/cursor_fields.png | create_image_pro (style: ui/cursor_hand) | 24x24 | 10 | quill pointer, wheat-gold feather; hotspot (0,0) |
| cursors/cursor_highlands.png | same | 24x24 | 10 | storm-blue feather, silver nib; hotspot (0,0) |
| cursors/cursor_abyss.png | same | 24x24 | 10 | charcoal feather with ember edges; hotspot (0,0) |
| cursors/cursor_frost.png | same | 24x24 | 10 | white and icy cyan feather; hotspot (1,0) |
| cursors/cursor_marsh.png | same | 24x24 | 10 (+10 rejected round, dull olive) | toxic green feather, bronze nib; hotspot (0,0) |
| cursors/cursor_dusk.png | same | 24x24 | 10 | violet and rose feather; hotspot (1,0) |
| fx/leaf_0.png, leaf_1.png, leaf_2.png | create_image_pro (style: dusk_leaves_0) | 8x10, 10x6, 8x9 | 10 | tiny autumn leaf (3 picks from one call) |
| fx/bat_0..3.png | create_image_pro (style: dusk_bat) + animate_image | 22x10 each | 10 + 1 | tiny front-view bat; 4-frame wing flap (up, mid, level, down) |
| fx/ember.png | hand-drawn (PIL) | 5x6 | 0 | glowing ember |
| fx/spore_0.png, spore_1.png | hand-drawn (PIL) | 5x5, 4x4 | 0 | glowing green spores |
| fx/snowflake_0.png, snowflake_1.png | hand-drawn (PIL) | 7x7, 5x5 | 0 (+10 rejected PixelLab call, all 10x10) | snowflakes |
| fx/raindrop.png | hand-drawn (PIL) | 2x8 | 0 | raindrop |
| ui/parchment_9slice.png | create_image_pro (style: ui/parchment_texture) | 48x48 | 10 | burnt-edge parchment with a gold inner line, rebuilt as a 9-slice with 16px corners and seamless edge bands |
| ui/divider.png | create_image_pro (style: ui/knotwork_strip) | 160x16 | 10 | gold filigree divider with a ruby rune diamond (loose end curls removed) |
| ui/corner.png | create_image_pro (style: ui/corner_flourish) | 24x24 | 10 | top-left gold filigree corner |
| ui/ribbon.png | create_image_pro (style: menu.png altar crop) | 12x47 | 10 | oxblood ribbon bookmark with a V-cut end |
| page_torn.png | create_image_pro (style: ui/parchment_texture) | 94x69 | 15 (+10 rejected round, too small) | torn grimoire page with burn holes, rotated to landscape |
| eclipse_wallpaper.png | create_image_pro (style: dusk_castle, ref: abyss_castle), opaque | 688x384 | 25 (+25 rejected round, black frame) | castle on a central cliff under a total eclipse, violet starry sky, floating runes |

eclipse_castle.png was not generated (optional; skipped).

**Total: 316 generations** (PixelLab balance 899 before, 583 after; 28 calls, 5 of them rejected rerolls).
