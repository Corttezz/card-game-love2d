"""PixelLab generation runner for the Runemoire site art (art/gen/).

Uses the game's PixelLab client (card-game-love2d/tools/pixellab_enemy_anims.py),
which reads the API token from PIXELLAB_TOKEN or ~/.claude.json. No secrets here.

  python plab.py balance
  python plab.py queue <tag> <spec> [<spec> ...]
  python plab.py poll
  python plab.py process
  python plab.py sheet <prefix> [scale]

Every submitted call is appended to generations.log.jsonl (tool, size, cost, job id).
"""
import base64
import io
import json
import os
import re
import sys
import time

GAME = r"E:\dev\projects\card-game-love2d"
sys.path.insert(0, os.path.join(GAME, "tools"))
import pixellab_enemy_anims as F  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
CAND = os.path.join(RAW, "cand")
JOBS = os.path.join(RAW, "jobs.json")
LOG = os.path.join(HERE, "generations.log.jsonl")
SPR = os.path.join(GAME, "assets", "sprites")
TOOL = "create_image_pro"
UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

STYLE = (" Hand-drawn pixel art in the same style, palette and pixel scale as the reference: dark stone, "
         "warm candle light, sepia parchment and gold, crisp 1 px dark outline, limited palette, flat "
         "clustered shading, no smooth gradients, no anti-aliasing, no painterly or 3D rendering, "
         "no text, no letters, no numbers.")
SOLO = (" Single isolated object centered on a transparent background, no ground plane, no floor shadow, "
        "no scenery, nothing cut off at the edges.")


def png_b64(path, crop=None):
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    if crop:
        im = im.crop(crop)
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def P(*parts):
    return os.path.join(SPR, *parts)


MENU = (P("scenes", "menu.png"), (60, 100, 340, 232))  # altar + open book + candles
SEAL = os.path.join(GAME, "assets", "branding", "seal.png")

# ---------------------------------------------------------------- specs
# name -> (w, h, no_background, style (path or (path, crop)), [(ref, usage)], description)
SPECS = {}

SPECS["tome"] = (160, 112, True, MENU, [
    (MENU, "the same grimoire, same leather and page colours, same viewing angle and lighting; "
           "here it is open, draw it CLOSED"),
    (SEAL, "the round gold compass-star seal embossed in the middle of the closed cover"),
],
    "a closed thick old grimoire lying flat on a table, seen slightly from above and from the front, "
    "the same book as the open one in the reference but shut: a thick block of cream pages visible "
    "along the front edge and the right side, the cover is dark oxblood-brown leather with a raised "
    "border, ornate gold metal corner fittings on all four corners, a round embossed gold compass-star "
    "seal (eight pointed star in a ring) in the middle of the cover, a dark red ribbon bookmark hanging "
    "out of the pages over the front edge. Warm candle light from both sides." + STYLE + SOLO)

# round b: round a came out rotated three-quarter; force the straight-on view of menu.png
SPECS["tome2"] = (160, 112, True, MENU, SPECS["tome"][4],
    "a closed thick old grimoire lying flat on a table, seen straight from the FRONT and slightly from "
    "above, exactly the same camera as the open book in the reference: NOT rotated, NOT isometric, the "
    "front edge of the book is a horizontal line parallel to the bottom of the image, the book is wider "
    "than tall and left-right symmetric. We see the top of the cover as a wide flat trapezoid and below "
    "it the thick front edge of cream pages between the cover and the back board. Dark oxblood-brown "
    "leather cover with a raised border, gold metal corner fittings on the four corners, a round "
    "embossed gold compass-star seal (eight pointed star in a ring) in the middle of the cover, one dark "
    "red ribbon bookmark hanging out over the front edge of the pages. Warm candle light from both "
    "sides." + STYLE + SOLO)

RUNE_BASE = ("a small carved rune stone: a thick rounded upright stone tablet, front view, filling most "
             "of the canvas, made of {stone}. Carved into its front face is ONE simple glowing rune "
             "glyph, an abstract invented sigil of three or four straight strokes (not a letter of any "
             "real alphabet), {glyph}. The glyph glows {glow} and casts a faint glow on the stone around "
             "it; chipped edges, a lit top face and a darker side face.")
RUNES = {
    "fields": ("weathered warm grey-brown sandstone", "with a small wheat-ear notch",
               "bright wheat gold and amber like a harvest sun"),
    "highlands": ("dark blue-grey slate", "with a zigzag lightning stroke",
                  "electric blue and violet like a storm"),
    "abyss": ("black volcanic basalt with thin red cracks", "with a sharp fang-like stroke",
              "molten lava orange and red"),
    "frost": ("pale blue-grey granite dusted with frost", "with a six-way star stroke",
              "icy cyan and white"),
    "marsh": ("dark mossy green-grey stone with moss patches", "with a curling root stroke",
              "toxic acid green"),
    "dusk": ("violet-grey stone", "with a crescent stroke", "rose gold and soft violet"),
    "eclipse": ("polished black obsidian", "shaped as a thin circular ring around a black disc, "
                "like an eclipse corona", "bright white-gold"),
}
for _id, (_s, _g, _w) in RUNES.items():
    SPECS["rune_" + _id] = (32, 32, True, P("world", "highlands_runestone_0.png"), [],
                            RUNE_BASE.format(stone=_s, glyph=_g, glow=_w) + STYLE + SOLO)

CURSOR_BASE = ("a mouse cursor pointer shaped like a quill pen: one feather quill lying diagonally, its "
               "sharp metal writing nib points to the UPPER LEFT corner and the nib tip touches the very "
               "top-left corner of the canvas, the feather vane widens towards the lower right; {tint}. "
               "Bold readable silhouette, small sprite.")
CURSORS = {
    "fields": "warm wheat-gold and amber feather, gold nib",
    "highlands": "storm blue and violet feather, silver nib with a tiny lightning glint",
    "abyss": "charcoal black feather with glowing ember-orange edges, gold nib",
    "frost": "white and icy cyan feather, silver nib",
    "marsh": "mossy toxic green feather, dark bronze nib",
    "dusk": "violet and rose feather, rose-gold nib",
}
# round b: round a marsh came out dull olive; push the hue
CURSORS["marsh2"] = ("bright toxic acid green and dark swamp green feather with a glowing lime edge, "
                     "dark bronze nib")
for _id, _t in CURSORS.items():
    SPECS["cursor_" + _id] = (24, 24, True, P("ui", "cursor_hand.png"), [],
                              CURSOR_BASE.format(tint=_t) + STYLE + " Transparent background.")

SPECS["fx_leaf"] = (16, 16, True, P("world", "dusk_leaves_0.png"), [],
                    "one single tiny falling autumn leaf, orange, red or amber, simple leaf shape with a "
                    "stem, only about 8 pixels long, centered with empty space around it, 1 px dark "
                    "outline, two or three flat colours, crisp pixel art, no anti-aliasing. Transparent background.")
SPECS["fx_snow"] = (16, 16, True, P("world", "frost_crystal_0.png"), [],
                    "one single tiny six-armed snowflake, white with pale icy cyan, only about 7 pixels "
                    "wide, centered with empty space around it, crisp pixel art, symmetric, no "
                    "anti-aliasing. Transparent background.")
SPECS["fx_bat"] = (16, 16, True, P("characters", "enemies", "dusk_bat", "south.png"), [],
                   "one tiny flying bat seen from the front, wings spread wide, dark violet-black body and "
                   "wings with a dark outline, two tiny red eyes, about 16 pixels wide and 10 pixels "
                   "tall, crisp pixel art, no anti-aliasing. Transparent background.")

SPECS["ui_parchment"] = (48, 48, True, P("ui", "parchment_texture.png"), [],
                         "a square aged parchment panel that fills the whole canvas edge to edge: warm "
                         "sepia cream paper, a darker burnt brown edge band all around, a thin gold inner "
                         "border line inset about 4 pixels from the edge, plain uniform edges with no "
                         "ornaments so it can be 9-sliced, plain center with subtle paper texture."
                         + STYLE)
SPECS["ui_divider"] = (160, 16, True, P("ui", "knotwork_strip.png"), [],
                       "a thin horizontal ornamental page divider, gold and dark ink filigree: a slim "
                       "gold line that tapers towards both ends with small scroll curls, a small diamond "
                       "shaped rune gem in the center." + STYLE + " Transparent background.")
SPECS["ui_corner"] = (24, 24, True, P("ui", "corner_flourish.png"), [],
                      "a gold filigree corner ornament for the TOP-LEFT corner of a page: an L shaped "
                      "flourish with one arm along the top edge and one arm along the left edge, small "
                      "curls and a leaf scroll at the corner." + STYLE + " Transparent background.")
SPECS["ui_ribbon"] = (16, 48, True, MENU, [],
                      "a vertical hanging bookmark ribbon: a narrow strip of dark oxblood red silk "
                      "hanging straight down, about 12 pixels wide, a small gold band at the top, a "
                      "V-shaped swallowtail cut at the bottom end, subtle fold shading." + STYLE
                      + " Transparent background.")

SPECS["page_torn"] = (200, 140, True, P("ui", "parchment_texture.png"), [],
                      "a single torn-out page of an old grimoire lying flat, aged sepia parchment, the "
                      "left edge ragged and torn where it was ripped from the binding, the other edges "
                      "worn, slightly crumpled with soft folds and creases, a few small brown burn marks "
                      "and one scorched corner, a couple of faint ink blots, no writing." + STYLE + SOLO)

# round b: round a page came out tiny (single candidate at 200x140); 160x112 gives 4 candidates
SPECS["page_torn2"] = (160, 112, True, P("ui", "parchment_texture.png"), [],
                       "one large torn-out page of an old grimoire lying flat, landscape orientation, "
                       "the page fills most of the canvas: aged sepia parchment, the left edge ragged and "
                       "torn with paper fibres where it was ripped from the binding, the other edges worn, "
                       "slightly crumpled with soft folds and creases, three or four small brown burn holes "
                       "with charred rims and one scorched corner, a couple of faint ink blots, no writing."
                       + STYLE + SOLO)

SPECS["eclipse_wall"] = (688, 384, False, P("world", "dusk_castle.png"), [
    (P("world", "abyss_castle.png"), "castle shape and stone pixel style, drawn as a black silhouette"),
],
    "a dark fantasy night scene: a black castle silhouette with several towers stands on a tall rocky "
    "cliff in the CENTER of the image; high above it a total solar eclipse: a black sun disc with a thin "
    "bright white-gold corona ring and soft rays; a deep violet to black night sky full of small stars; "
    "a few faint glowing violet runes floating in the air around the castle; dark mist at the foot of "
    "the cliff. Hand-drawn pixel art in the same style and pixel scale as the reference castle, 1 px "
    "dark outlines, limited palette, flat clustered shading, no smooth gradients, no text, no letters.")
# round b: round a framed the scene inside a black rounded border; ask for full bleed
SPECS["eclipse_wall2"] = SPECS["eclipse_wall"][:5] + (
    SPECS["eclipse_wall"][5] + " Full-bleed scene: the sky, stars and cliffs fill the ENTIRE canvas "
    "edge to edge, no border, no frame, no black margin, no vignette, no rounded corners.",)


# ---------------------------------------------------------------- plumbing
def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    os.makedirs(RAW, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=1)


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def style_b64(s):
    return png_b64(*s) if isinstance(s, tuple) else png_b64(s)


def queue(names, tag="a"):
    os.makedirs(RAW, exist_ok=True)
    J = jobs()
    for name in names:
        w, h, nobg, style, refs, desc = SPECS[name]
        args = {"description": desc, "width": w, "height": h, "no_background": nobg,
                "style_image_base64": style_b64(style),
                "style_copy": ["color_palette", "outline", "detail", "shading"]}
        if refs:
            args["reference_images"] = [{"base64": style_b64(r), "usage": u} for r, u in refs]
        while True:
            text = call(TOOL, args)
            if "rate limit" not in text.lower():
                break
            time.sleep(20)  # 10 concurrent jobs max; wait for a slot
        m = re.search(UUID, text)
        if not m:
            print(f"[queue] {name}: not queued: {text[:300]}", flush=True)
            continue
        mc = re.search(r"cost:\s*(\d+)", text)
        key = name + "_" + tag
        J = jobs()
        J[key] = {"job": m.group(0) if m else None, "spec": name, "cost": int(mc.group(1)) if mc else None}
        save_jobs(J)
        with open(LOG, "a") as f:
            f.write(json.dumps({"t": time.strftime("%Y-%m-%dT%H:%M:%S"), "key": key, "tool": TOOL,
                                "w": w, "h": h, "cost": J[key]["cost"], "job": J[key]["job"],
                                "prompt": desc[:160]}) + "\n")
        print(f"[queue] {key}: {J[key]['job']} cost={J[key]['cost']} {'' if m else text[:400]}", flush=True)
        time.sleep(1)


def download(name, jid):
    text = call("get_image", {"job_id": jid})
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[FAIL] {name}: {text[:200]}")
        return "error"
    if "status: completed" not in low:
        return "wait"
    mf = re.search(r"frames:\s*(\d+)", text)
    m0 = re.search(r"(https?://\S+download\?index=)0", text)
    urls = [m0.group(1) + str(i) for i in range(int(mf.group(1)))] if mf and m0 else []
    if not urls:
        urls = [u.rstrip(")\"',") for u in re.findall(r"https?://\S+", text) if "download" in u]
    for i, u in enumerate(urls):
        open(os.path.join(RAW, f"{name}__{i:02d}.png"), "wb").write(F.fetch(u))
    print(f"[ok] {name}: {len(urls)}", flush=True)
    return "done"


def poll():
    t0 = time.time()
    idle = 0
    while time.time() - t0 < 3600:
        J = jobs()
        pending = {n: j for n, j in J.items() if j.get("job") and not j.get("done") and not j.get("dead")}
        if not pending:
            idle += 1
            if idle > 4:
                break
        for name, j in pending.items():
            try:
                st = download(name, j["job"])
            except Exception as e:  # transient network errors
                print(f"[err] {name}: {e}")
                st = "wait"
            if st in ("error", "done"):
                J = jobs()
                J[name]["dead" if st == "error" else "done"] = True
                save_jobs(J)
        time.sleep(15)
    print("poll finished")


def threshold(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            px[x, y] = (c[0], c[1], c[2], 255 if c[3] >= 128 else 0)
    return im


def process():
    from PIL import Image
    os.makedirs(CAND, exist_ok=True)
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".png") or "__" not in f or os.path.exists(os.path.join(CAND, f)):
            continue
        try:
            im = Image.open(os.path.join(RAW, f)).convert("RGBA")
        except Exception:  # still downloading
            continue
        if f.startswith("eclipse_wall"):
            im.save(os.path.join(CAND, f))
            continue
        threshold(im)
        bb = im.getbbox()
        if bb:
            im.crop(bb).save(os.path.join(CAND, f))


def sheet(prefix, K=3, cols=16):
    from PIL import Image, ImageDraw
    tiles = [(f[:-4], Image.open(os.path.join(CAND, f)).convert("RGBA"))
             for f in sorted(os.listdir(CAND)) if f.startswith(prefix)]
    cw = max(t.width for _, t in tiles) * K + 10
    ch = max(t.height for _, t in tiles) * K + 14
    cols = min(cols, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cw + 10, rows * ch + 10), (70, 66, 74, 255))
    d = ImageDraw.Draw(out)
    for i, (label, t) in enumerate(tiles):
        x, y = 10 + (i % cols) * cw, 10 + (i // cols) * ch
        out.alpha_composite(t.resize((t.width * K, t.height * K), Image.NEAREST), (x, y + 12))
        d.text((x, y), label.split("__")[-1] + f" {t.width}x{t.height}", fill=(255, 240, 200, 255))
    p = os.path.join(RAW, f"sheet_{prefix}.png")
    out.save(p)
    print(p, out.size)


def animate(key, src, action, frames, canvas):
    """animate_image on a candidate, centered on a canvas x canvas transparent frame."""
    from PIL import Image
    im = Image.open(src).convert("RGBA")
    pad = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    pad.alpha_composite(im, ((canvas - im.width) // 2, (canvas - im.height) // 2))
    buf = io.BytesIO()
    pad.save(buf, "PNG")
    text = call("animate_image", {"first_frame_base64": base64.b64encode(buf.getvalue()).decode(),
                                  "action": action, "frame_count": frames, "no_background": True})
    m = re.search(UUID, text)
    mc = re.search(r"cost:\s*(\d+)", text)
    print(text[:300])
    if not m:
        return
    J = jobs()
    J[key] = {"job": m.group(0), "spec": key, "cost": int(mc.group(1)) if mc else None}
    save_jobs(J)
    with open(LOG, "a") as f:
        f.write(json.dumps({"t": time.strftime("%Y-%m-%dT%H:%M:%S"), "key": key, "tool": "animate_image",
                            "w": canvas, "h": canvas, "cost": J[key]["cost"], "job": J[key]["job"],
                            "prompt": action}) + "\n")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "animate":
        animate(sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), int(sys.argv[6]))
    if cmd == "balance":
        print("\n".join(l for l in call("get_balance", {}).splitlines() if "generations" in l))
    elif cmd == "queue":
        queue(sys.argv[3:], sys.argv[2])
    elif cmd == "poll":
        poll()
    elif cmd == "process":
        process()
    elif cmd == "sheet":
        sheet(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 3,
              int(sys.argv[4]) if len(sys.argv) > 4 else 16)
