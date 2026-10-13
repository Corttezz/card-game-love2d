"""
tools/pixellab_shop_v5.py: artes NOVAS da Loja v5 (pedido do dono, Out/2026):

  packs     os 5 pacotes no estilo do pack_buffoon da v4 (um PACOTE de
            verdade: envelope grosso, topo serrilhado/dentado, lombada à
            esquerda, já na diagonal 1:8 da mesa), 64x80, 16 candidatas
  relics    cristal de mana e prensa (duplicate_card) refeitos, 64x64
  anims     poção borbulhando (hover) e os 5 pacotes abrindo (PackOpenScreen),
            animate_object com o PNG como quadro inicial

  python tools/pixellab_shop_v5.py queue packs|relics|anims [nomes]
  python tools/pixellab_shop_v5.py poll [--nowait]
  python tools/pixellab_shop_v5.py sheet <nome>      # prancha das candidatas

Saída em tools/preview_out/shop_v5/raw/<nome>__<i>.png (candidatas) e
<nome>_anim/<i>.png (quadros). Instalar é manual (escolher a candidata e
copiar pra assets/sprites/shop/v5/).
"""
import base64
import io
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools/preview_out/shop_v5/raw")
JOBS = os.path.join(RAW, "jobs.json")

STYLE = ("pixel art game item for a dark fantasy card game, standing upright on a "
         "wooden table, lit warmly from the upper left, crisp 1px dark outline, no "
         "anti-aliasing, limited sepia-leaning palette with one accent colour, "
         "transparent background, nothing else in the picture, no table, no shadow "
         "plate, no text")

PACK_POSE = ("a thick sealed booster pack of cards: a rectangular paper envelope "
             "with a serrated zig-zag torn top edge, a visible left side showing its "
             "thickness, the front face turned so it rises to the right (one pixel up "
             "every eight pixels), a wax seal or emblem in the middle and straps or "
             "ribbon crossing the front")

PACKS = {
    "pack_standard": "plain aged parchment envelope tied with dark string crossing on the front, red wax seal in the middle",
    "pack_arcana": "deep blue envelope with a golden all-seeing eye emblem in the middle and a purple ribbon crossing it",
    "pack_buffoon": "dark red envelope with a golden horned jester mask emblem and dark leather straps crossing it",
    "pack_celestial": "dark navy envelope with silver metal corners, a golden crescent moon and small stars emblem, tied with brown string",
    "pack_spectral": "pale sickly green envelope with a darker green skull emblem and dark thorny vines wrapped around it",
}

RELICS = {
    "mana_upgrade": ("a tall faceted mana crystal, deep blue glowing glass with a lighter core, "
                     "set in a small dark iron claw mount on a short stone base, a few floating "
                     "sparks of blue light; clean readable silhouette, the crystal is the hero"),
    "duplicate_card": ("a small wooden hand press for printing cards: a heavy dark wood frame with "
                       "a brass screw and a turning handle on top, a flat press bed with one "
                       "parchment card coming out at the front; chunky readable shapes"),
}

ANIMS = {
    "health_upgrade": {
        "src": "assets/sprites/shop/v4/health_upgrade.png",
        "anim": "the red elixir inside the glass bottle gently bubbles and swirls, two or three small bubbles rise and pop, the cork and label stay still, the bottle does not move",
        "frames": 8,
    },
}
PACK_OPEN_ANIM = ("the sealed card pack bursts open: the wax seal cracks, the top flap tears "
                  "upward along the serrated edge, light spills out of the opening and three "
                  "card corners rise out of the top; the pack itself stays in place")

SUFFIX = ". pixel art, same palette and outline as the first frame, no background, the object stays centered"


def ensure():
    os.makedirs(RAW, exist_ok=True)


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    json.dump(j, open(JOBS, "w"), indent=2)


def _b64file(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def _b64img(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def call(tool, args, timeout=300):
    import pixellab_enemy_anims as F
    text = F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))
    return text


def specs_packs():
    from PIL import Image
    style_ref = os.path.join(ROOT, "assets/sprites/shop/v4/pack_buffoon.png")
    out = {}
    for pid, desc in PACKS.items():
        old = Image.open(os.path.join(ROOT, "assets/sprites/packs", pid + ".png")).convert("RGBA")
        out[pid] = ("create_image_pro", {
            "description": PACK_POSE + ": " + desc + ". " + STYLE,
            "width": 64, "height": 80, "no_background": True,
            "style_image_base64": _b64file(style_ref),
            "style_copy": ["outline", "shading", "detail"],
            "reference_images": [
                {"base64": _b64img(old), "usage": "identity: the same pack, same colours, same emblem and straps"},
                {"base64": _b64file(style_ref), "usage": "shape, pose and construction: this exact kind of thick envelope with the serrated top, the left side showing thickness and the face rising to the right"},
            ],
        })
    return out


def specs_relics():
    from PIL import Image
    out = {}
    for rid, desc in RELICS.items():
        old = Image.open(os.path.join(ROOT, "assets/sprites/vouchers", rid + ".png")).convert("RGBA")
        out[rid] = ("create_image_pro", {
            "description": desc + ". " + STYLE,
            "width": 64, "height": 64, "no_background": True,
            "reference_images": [
                {"base64": _b64img(old), "usage": "identity and colours of the same object (improve the drawing, keep what it is)"},
            ],
        })
    return out


def queue(group, names=None):
    ensure()
    J = jobs()
    if group in ("packs", "relics"):
        specs = specs_packs() if group == "packs" else specs_relics()
        for name, (tool, args) in specs.items():
            if names and name not in names:
                continue
            text = call(tool, args)
            m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
            J[name] = {"job": m.group(0) if m else None}
            print(f"[queue] {name}: {J[name]['job']} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(1.5)
    elif group == "anims":
        import pixellab_animate_vouchers as V
        host = V.HOST_OBJECT
        specs = dict(ANIMS)
        for pid in PACKS:
            specs["open_" + pid] = {"src": "assets/sprites/shop/v5/" + pid + ".png",
                                    "anim": PACK_OPEN_ANIM, "frames": 8}
        for name, spec in specs.items():
            if names and name not in names:
                continue
            args = {
                "object_id": host,
                "animation_description": spec["anim"] + SUFFIX,
                "display_name": "shopv5_" + name,
                "mode": "v3",
                "frame_count": spec["frames"],
                "replace_existing": True,
                "custom_start_frame_base64": _b64file(os.path.join(ROOT, spec["src"])),
            }
            text = call("animate_object", args)
            m = re.search(r"group:\s*([0-9a-f-]{36})", text)
            J[name] = {"object_id": host, "group": m.group(1) if m else None}
            print(f"[queue] {name}: group {J[name]['group']} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(1.5)


def _download_image(name, jid):
    import pixellab_enemy_anims as F
    text = call("get_image", {"job_id": jid})
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[poll] {name}: FALHOU {text[:160]}")
        return "error"
    if "status: completed" not in low:
        return "wait"
    urls = re.findall(r"https?://\S+", text)
    urls = [u.rstrip(")\"',") for u in urls if "download" in u or u.endswith(".png")]
    if not urls:
        print(f"[poll] {name}: completo sem url — {text[:200]}")
        return "error"
    for i, u in enumerate(urls):
        open(os.path.join(RAW, f"{name}__{i}.png"), "wb").write(F.fetch(u))
    print(f"[ok] {name}: {len(urls)} candidatas")
    return "done"


def _download_anim(name, object_id, group):
    import pixellab_enemy_anims as F
    text = call("get_object", {"object_id": object_id})
    # bloco da animacao no get_object: linha "<display_name> [group: ...]",
    # depois "frames: N" e "unknown: <url>/{i}.png  (i=0..N-1)"
    i = text.find("shopv5_" + name + " [group")
    if i < 0:
        return "wait"
    seg = text[i:i + 1500]
    mN = re.search(r"frames:\s*(\d+)", seg)
    mU = re.search(r"(https?://\S+)\{i\}\.png", seg)
    if not (mN and mU):
        if "failed" in seg.lower():
            print(f"[poll] {name}: FALHOU {seg[:200]}")
            return "error"
        return "wait"
    n, base = int(mN.group(1)), mU.group(1)
    dest = os.path.join(RAW, name + "_anim")
    os.makedirs(dest, exist_ok=True)
    for k in range(n):
        open(os.path.join(dest, f"{k}.png"), "wb").write(F.fetch(f"{base}{k}.png"))
    print(f"[ok] {name}: {n} quadros", flush=True)
    return "done"


def poll(wait=True, only=None):
    J = jobs()
    pending = {n: j for n, j in J.items() if (not only or n in only)}
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        for name, j in list(pending.items()):
            if j.get("job"):
                if os.path.exists(os.path.join(RAW, name + "__0.png")):
                    pending.pop(name); continue
                st = _download_image(name, j["job"])
            elif j.get("group"):
                if os.path.isdir(os.path.join(RAW, name + "_anim")):
                    pending.pop(name); continue
                st = _download_anim(name, j["object_id"], j["group"])
            else:
                pending.pop(name); continue
            if st != "wait":
                pending.pop(name)
        if pending and wait:
            print(f"[poll] aguardando {sorted(pending)}", flush=True)
            time.sleep(20)
        elif not wait:
            break
    return pending


def sheet(name):
    from PIL import Image
    files = sorted([f for f in os.listdir(RAW) if re.match(re.escape(name) + r"__\d+\.png$", f)],
                   key=lambda f: int(f.split("__")[1].split(".")[0]))
    if not files:
        print("nada"); return
    ims = [Image.open(os.path.join(RAW, f)).convert("RGBA") for f in files]
    w, h = max(i.width for i in ims), max(i.height for i in ims)
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (w + 4), rows * (h + 4)), (40, 30, 30, 255))
    for k, im in enumerate(ims):
        out.paste(im, ((k % cols) * (w + 4), (k // cols) * (h + 4)), im)
    p = os.path.join(RAW, name + "_sheet.png")
    out.resize((out.width * 3, out.height * 3), Image.NEAREST).save(p)
    print(p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        queue(sys.argv[2], sys.argv[3:] or None)
    elif cmd == "poll":
        poll(wait="--nowait" not in sys.argv, only=[a for a in sys.argv[2:] if not a.startswith("--")] or None)
    elif cmd == "sheet":
        sheet(sys.argv[2])
    else:
        print(__doc__)
