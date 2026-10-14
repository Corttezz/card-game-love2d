#!/usr/bin/env python3
"""
tools/pixellab_trees.py — variantes NOVAS de árvore por bioma do WorldRoad
(pedido do dono, 13/Out/2026: "gerar mais árvores parecidas com cada um dos
atos, pra deixar mais diversificado").

Contrato: a árvore EXISTENTE do bioma é a referência (imagem, nunca só
texto) — `create_image_pro` com `reference_images` + `style_image_base64`
(paleta, contorno de 1 px, detalhe e sombreado copiados da referência). O
base64 é lido do DISCO pelo script (memória pixellab-base64-mcp-http).

  python tools/pixellab_trees.py queue [bioma_variante ...]   # enfileira (1 chamada pro = 4 candidatas)
  python tools/pixellab_trees.py poll                          # baixa as prontas em tools/preview_out/arvores/raw/
  python tools/pixellab_trees.py process                       # crop + furos + paleta → tools/preview_out/arvores/cand/
  python tools/pixellab_trees.py sheet                         # prancha por bioma: referência × candidatas
  python tools/pixellab_trees.py install fields_a__2 fields_tree_2 ...   # instala as APROVADAS

Julgamento (antes de instalar): a candidata entra só se lê como do mesmo
artista e do mesmo bioma (paleta, contorno, proporção). Forma vetorial
suave, iluminação de render ou detalhe demais = "cara de IA" = fora.
"""
import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # rpc/tool_text/fetch/token compartilhados

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets/sprites/world")
OUT = os.path.join(ROOT, "tools/preview_out/arvores")
RAW = os.path.join(OUT, "raw")
CAND = os.path.join(OUT, "cand")
JOBS = os.path.join(RAW, "jobs.json")

COMMON = (". Single isolated tree only, nothing else: no ground, no grass, no "
          "landscape, no shadow on the floor. The whole tree including every "
          "root tip and the top of the crown is inside the canvas with a small "
          "margin, nothing cut off at the edges. Transparent background. Same "
          "hand-drawn pixel art style as the reference tree: crisp 1 px dark "
          "outline, exactly the same colour palette, flat clustered shading, "
          "light from the upper left, same scale (same trunk thickness and the "
          "same size of leaf clusters). No smooth gradients, no anti-aliasing, "
          "no photographic rendering.")

# bioma → (referência, canvas w, h, {variante: descrição})
SPECS = {
    "fields": ("fields_tree_1.png", 112, 112, {
        "a": "a different old oak tree of the same green forest: taller and "
             "narrower than the reference, the crown made of the same round "
             "leaf clusters, the trunk forking into two main limbs, knotted "
             "roots spreading at the base",
        "b": "a wide, squat ancient oak of the same green forest: very broad "
             "low crown, short massive trunk, gnarled roots at the base",
    }),
    "highlands": ("highlands_pine_0.png", 96, 176, {
        "a": "a different pine tree of the same cold blue-green forest: "
             "slimmer and taller, sparser tiers of drooping branches, a bare "
             "lower trunk with roots at the base",
        "b": "a shorter, fuller pine of the same cold blue-green forest, the "
             "crown wind-bent and leaning slightly to one side, roots at the base",
    }),
    "abyss": ("abyss_deadtree_0.png", 112, 168, {
        "a": "a different dead tree of the same hellish wasteland: two thick "
             "twisted trunks splitting from the same root, bare claw-like "
             "branches, the same glowing ember cracks in the bark",
        "b": "a short thick broken dead tree of the same hellish wasteland, "
             "jagged shattered top, a few bare branches, glowing embers inside "
             "the cracks, heavy roots",
    }),
    "frost": ("frost_pine_0.png", 96, 136, {
        "a": "a different snow-covered fir of the same winter forest: taller "
             "and slimmer, heavy caps of snow on each tier of branches, dark "
             "trunk visible at the bottom",
        "b": "a small round young fir of the same winter forest, snow piled on "
             "the branches, short trunk visible at the bottom",
    }),
    "marsh": ("marsh_deadtree_0.png", 112, 152, {
        "a": "a different swamp tree of the same bog: crooked leaning trunk, "
             "long strands of hanging moss, mossy bark, roots spreading into "
             "the mud",
        "b": "a bald cypress of the same bog: bulging buttressed base, thin "
             "bare branches, a little hanging moss",
    }),
    "dusk": ("dusk_tree_0.png", 120, 120, {
        "a": "a different tree of the same twilight grove: taller with a "
             "slender twisted trunk, the purple crown in layered tufts, roots "
             "at the base",
        "b": "a low wide spreading tree of the same twilight grove, purple "
             "crown, thick twisted trunk, roots at the base",
    }),
}

# kinds sorteáveis (src/data/biomes.lua propWeights) que hoje caem no
# PROCEDURAL por falta de PNG — nome → (referência de estilo, w, h, descrição)
EXTRA = {
    "highlands_deadtree": ("highlands_pine_0.png", 96, 160,
        "a dead leafless tree of the same cold blue-green highland forest: "
        "bare twisted grey-blue trunk and branches, no needles, roots at the base"),
    "frost_deadtree": ("frost_pine_0.png", 96, 136,
        "a dead leafless tree of the same winter forest: bare dark trunk and "
        "branches with snow resting on the upper branches, roots at the base"),
    "abyss_bush": ("abyss_deadtree_0.png", 64, 56,
        "a low dead thorny shrub of the same hellish wasteland: tangle of "
        "charred twigs with a few glowing ember tips, small, wide"),
}


def specs_flat():
    """nome → (ref, w, h, desc) unindo SPECS (bioma_a/b) e EXTRA."""
    out = {}
    for bid, (ref, w, h, variants) in SPECS.items():
        for var, desc in variants.items():
            out[f"{bid}_{var}"] = (ref, w, h, desc)
    out.update(EXTRA)
    return out


def ensure():
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(CAND, exist_ok=True)


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    json.dump(j, open(JOBS, "w"), indent=1)


def _b64file(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args},
                             timeout=timeout))


def queue(names=None):
    ensure()
    J = jobs()
    for name, (ref, w, h, desc) in specs_flat().items():
        if True:
            if names and name not in names:
                continue
            ref64 = _b64file(os.path.join(WORLD, ref))
            args = {
                "description": desc + COMMON,
                "width": w, "height": h, "no_background": True,
                "style_image_base64": ref64,
                "style_copy": ["color_palette", "outline", "detail", "shading"],
                "reference_images": [
                    {"base64": ref64,
                     "usage": "style, palette, outline weight, lighting and "
                              "scale: draw a DIFFERENT tree of the same biome "
                              "by the same artist"},
                ],
            }
            text = call("create_image_pro", args)
            m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
            J[name] = {"job": m.group(0) if m else None, "ref": ref}
            print(f"[queue] {name}: {J[name]['job']} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(2)


def _download(name, jid):
    text = call("get_image", {"job_id": jid})
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[poll] {name}: FALHOU {text[:160]}")
        return "error"
    if "status: completed" not in low:
        return "wait"
    # create_image_pro devolve ATÉ 4 candidatas: o texto traz "frames: N" e
    # SÓ a url do índice 0 ("... ?index=3" vem truncado) — monta as outras
    urls = []
    mf = re.search(r"frames:\s*(\d+)", text)
    m0 = re.search(r"(https?://\S+download\?index=)0", text)
    if mf and m0:
        urls = [m0.group(1) + str(i) for i in range(int(mf.group(1)))]
    if not urls:
        urls = re.findall(r"https?://\S+", text)
        urls = [u.rstrip(")\"',") for u in urls if "download" in u or u.endswith(".png")]
    if not urls:
        print(f"[poll] {name}: completo sem url — {text[:200]}")
        return "error"
    for i, u in enumerate(urls):
        open(os.path.join(RAW, f"{name}__{i}.png"), "wb").write(F.fetch(u))
    print(f"[ok] {name}: {len(urls)} candidatas", flush=True)
    return "done"


def poll(wait=True):
    ensure()
    J = jobs()
    pending = {n: j for n, j in J.items() if j.get("job")}
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        for name, j in list(pending.items()):
            if os.path.exists(os.path.join(RAW, name + "__0.png")):
                pending.pop(name); continue
            st = _download(name, j["job"])
            if st != "wait":
                pending.pop(name)
        if pending and wait:
            print(f"[poll] aguardando {sorted(pending)}", flush=True)
            time.sleep(25)
        elif not wait:
            break
    return pending


# ---------------------------------------------------------------- pós-processo
def _fill_holes(im):
    """Bolsões transparentes INTERNOS (não alcançáveis pela borda) viram
    sombra de copa (média dos vizinhos ×0.85) — ciclo 34 do WorldRoad: a
    borda clara do mundo vazava por dentro das copas."""
    w, h = im.size
    px = im.load()
    reach = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + \
            [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or reach[y][x] or px[x, y][3] >= 128:
            continue
        reach[y][x] = True
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    holes = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128 and not reach[y][x]:
                n = [px[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                     if 0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] >= 128]
                if n:
                    r = sum(c[0] for c in n) // len(n)
                    g = sum(c[1] for c in n) // len(n)
                    b = sum(c[2] for c in n) // len(n)
                    px[x, y] = (int(r * 0.85), int(g * 0.85), int(b * 0.85), 255)
                    holes += 1
    return holes


def _palette(im, step=1):
    cols = {}
    px = im.load()
    for y in range(0, im.height, step):
        for x in range(0, im.width, step):
            c = px[x, y]
            if c[3] >= 128:
                cols[c[:3]] = cols.get(c[:3], 0) + 1
    return cols


def _palette_match(cand, ref, tol=14):
    """fração dos pixels da candidata cuja cor está a ≤ tol (L1/3) de alguma
    cor da referência — 'mesma paleta' objetivamente."""
    rp = list(_palette(ref))
    cp = _palette(cand)
    tot = sum(cp.values())
    ok = 0
    for c, n in cp.items():
        if any(abs(c[0] - r[0]) + abs(c[1] - r[1]) + abs(c[2] - r[2]) <= tol * 3 for r in rp):
            ok += n
    return ok / max(1, tot), len(cp), len(rp)


def process():
    from PIL import Image
    ensure()
    J = jobs()
    report = []
    for f in sorted(os.listdir(RAW)):
        m = re.match(r"^([a-z]+_[a-z]+)__(\d+)\.png$", f)
        if not m or m.group(1) not in specs_flat():
            continue
        name = m.group(1)
        ref = Image.open(os.path.join(WORLD, specs_flat()[name][0])).convert("RGBA")
        im = Image.open(os.path.join(RAW, f)).convert("RGBA")
        # alpha binário (nada de borda meio-transparente)
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                c = px[x, y]
                px[x, y] = (c[0], c[1], c[2], 255 if c[3] >= 128 else 0)
        bb = im.getbbox()
        if not bb:
            report.append(f"{f}: vazio"); continue
        im = im.crop(bb)
        holes = _fill_holes(im)
        frac, nc, nr = _palette_match(im, ref)
        # base: a última linha tem que ter tronco/raiz (não copa cortada)
        a = im.split()[3]
        last = [x for x in range(im.width) if a.getpixel((x, im.height - 1)) > 0]
        base_w = (max(last) - min(last) + 1) if last else 0
        out = os.path.join(CAND, f)
        im.save(out)
        line = (f"{f}: {im.width}x{im.height} ref {ref.width}x{ref.height} "
                f"furos {holes} paleta {frac*100:.0f}% ({nc} cores vs {nr}) "
                f"base {base_w}px")
        report.append(line)
        print(line)
    open(os.path.join(OUT, "cand_report.txt"), "w").write("\n".join(report) + "\n")


def sheet():
    from PIL import Image, ImageDraw
    ensure()
    K = 2
    for bid, (ref, w, h, variants) in SPECS.items():
        refim = Image.open(os.path.join(WORLD, ref)).convert("RGBA")
        tiles = [("REF " + ref, refim)]
        for f in sorted(os.listdir(CAND)):
            if f.startswith(bid + "_"):
                tiles.append((f, Image.open(os.path.join(CAND, f)).convert("RGBA")))
        # árvores extras já instaladas (tree_1, tree_2...) também entram
        for f in sorted(os.listdir(WORLD)):
            if re.match(rf"^{bid}_(tree|pine|deadtree)_[1-9]\.png$", f) and f != ref:
                tiles.append(("INST " + f, Image.open(os.path.join(WORLD, f)).convert("RGBA")))
        if len(tiles) == 1:
            continue
        H = max(t.height for _, t in tiles) * K + 18
        W = sum(t.width * K + 10 for _, t in tiles)
        out = Image.new("RGBA", (W, H), (34, 30, 28, 255))
        d = ImageDraw.Draw(out)
        x = 0
        for label, t in tiles:
            big = Image.new("RGBA", t.size, (60, 95, 60, 255))
            big.alpha_composite(t)
            big = big.resize((t.width * K, t.height * K), Image.NEAREST)
            out.paste(big, (x, H - big.height))
            d.text((x, 2), label[:26], fill=(240, 230, 210, 255))
            x += big.width + 10
        p = os.path.join(OUT, f"variantes_bioma_{list(SPECS).index(bid) + 1}_{bid}.png")
        out.save(p)
        print(p)


def install(pairs):
    """install cand_nome target_nome: copia tools/preview_out/arvores/cand/<cand>.png
    para assets/sprites/world/<target>.png (ex.: fields_a__2 fields_tree_2)."""
    import shutil
    for cand, target in zip(pairs[0::2], pairs[1::2]):
        src = os.path.join(CAND, cand + ".png")
        dst = os.path.join(WORLD, target + ".png")
        shutil.copyfile(src, dst)
        print(f"[install] {src} -> {dst}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        queue(sys.argv[2:] or None)
    elif cmd == "poll":
        poll(wait="--nowait" not in sys.argv)
    elif cmd == "process":
        process()
    elif cmd == "sheet":
        sheet()
    elif cmd == "install":
        install(sys.argv[2:])
    else:
        print(__doc__)
