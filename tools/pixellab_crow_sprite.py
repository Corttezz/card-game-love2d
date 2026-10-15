#!/usr/bin/env python3
"""
tools/pixellab_crow_sprite.py: corvo pequeno em voo, de perfil, para o bando
do rei-carnica (BossAura, memory/boss_visuals.md).

  python tools/pixellab_crow_sprite.py base [seed]   candidatos 32x32
  python tools/pixellab_crow_sprite.py pick <N>      base escolhida
  python tools/pixellab_crow_sprite.py anim [seed]   batida de asa (animate_image)
  python tools/pixellab_crow_sprite.py install <i,j,k,...>
Candidatos em tools/preview_out/crow_sprite/; instala em
assets/sprites/characters/enemies/carrion_king/crow/frame_N.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N

ROOT = N.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/crow_sprite")
DEST = os.path.join(ROOT, "assets/sprites/characters/enemies/carrion_king/crow")
STYLE = os.path.join(ROOT, "assets/sprites/characters/enemies/carrion_king/"
                     "animations/idle/south/0.png")
SIZE = 32

DESC = ("a small black crow flying, strict side view profile facing RIGHT, "
        "both wings raised up high mid flap, beak pointing right, tail behind "
        "on the left, glossy blue-black feathers with a blue-violet sheen on "
        "the wing tops, tiny ember-orange eye, crisp dark 1px outline, "
        "hand-placed pixel art, NO anti-aliasing, NO smooth gradients, "
        "transparent background, single bird only, fills the canvas")

ACTION = ("the crow flaps its wings in a steady flying loop: wings sweep "
          "down to below the body, then rise back up high; body and head stay "
          "level in the same place, side view facing right")


def contact(prefix, scale=4):
    from PIL import Image, ImageDraw
    fs = sorted((f for f in os.listdir(OUT) if f.startswith(prefix) and f.endswith(".png")),
                key=lambda f: int(f[len(prefix):-4]))
    ims = [Image.open(os.path.join(OUT, f)).convert("RGBA") for f in fs]
    if not ims:
        return
    s = ims[0].width * scale
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * (s + 6), rows * (s + 14)), (58, 44, 36, 255))
    dr = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        x, y = (k % cols) * (s + 6), (k // cols) * (s + 14)
        big = im.resize((s, s), Image.NEAREST)
        sh.paste(big, (x, y), big)
        dr.text((x + 2, y + s), str(k), fill=(255, 255, 0))
    p = os.path.join(OUT, prefix + "contact.png")
    sh.save(p)
    print(p)


def cmd_base(seed=None):
    args = {"description": DESC, "width": SIZE, "height": SIZE,
            "no_background": True, "style_image_base64": N.b64(STYLE),
            "style_copy": ["color_palette", "outline", "shading"]}
    if seed is not None:
        args["seed"] = int(seed)
    text = N.call("create_image_pro", args)
    jid = N.job_id_of(text)
    print(f"[base] job {jid}", flush=True)
    done = N.wait_job(jid, 1500) if jid else None
    if not done:
        print(text[:300])
        return
    os.makedirs(OUT, exist_ok=True)
    N.download_all(done, os.path.join(OUT, "cand_{}.png"))
    contact("cand_")


def binarize(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def cmd_pick(n):
    from PIL import Image
    im = binarize(Image.open(os.path.join(OUT, f"cand_{n}.png")).convert("RGBA"))
    im.save(os.path.join(OUT, "base.png"))
    print(os.path.join(OUT, "base.png"))


def cmd_anim(seed=None):
    args = {"action": ACTION, "first_frame_base64": N.b64(os.path.join(OUT, "base.png")),
            "frame_count": 6, "no_background": True}
    if seed is not None:
        args["seed"] = int(seed)
    text = N.call("animate_image", args)
    jid = N.job_id_of(text)
    print(f"[anim] job {jid}", flush=True)
    done = N.wait_job(jid, 1500) if jid else None
    if not done:
        print(text[:300])
        return
    tag = f"s{seed}_" if seed is not None else ""
    N.download_all(done, os.path.join(OUT, "anim_" + tag + "{}.png"))
    contact("anim_" + tag)


def cmd_install(spec):
    from PIL import Image
    src = spec.split(":")
    prefix = src[0] if len(src) > 1 else "anim_"
    idx = [int(x) for x in src[-1].split(",")]
    os.makedirs(DEST, exist_ok=True)
    for f in os.listdir(DEST):
        if f.startswith("frame_"):
            os.remove(os.path.join(DEST, f))
    for k, i in enumerate(idx):
        im = binarize(Image.open(os.path.join(OUT, f"{prefix}{i}.png")).convert("RGBA"))
        im.save(os.path.join(DEST, f"frame_{k}.png"))
    print(f"[install] {len(idx)} quadros em {DEST}")


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "base":
        cmd_base(a[0] if a else None)
    elif c == "pick":
        cmd_pick(int(a[0]))
    elif c == "anim":
        cmd_anim(a[0] if a else None)
    elif c == "install":
        cmd_install(a[0])
    else:
        print(__doc__)
