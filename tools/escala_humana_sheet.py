import os
import re
import sys
import colorsys

import numpy as np
from PIL import Image

LOVE = os.path.expandvars(r"%APPDATA%\LOVE")


def load(identity, label, scene):
    path = os.path.join(LOVE, identity, "escala_humana", label, scene + ".png")
    return Image.open(path).convert("RGB")


def rows(identity, label, scene):
    path = os.path.join(LOVE, identity, "escala_humana", label, scene + ".txt")
    return open(path, encoding="utf-8").read().splitlines()


def props(lines, kind=None, tmin=None, tmax=None):
    out = []
    for ln in lines:
        m = re.match(r"prop (\S+)\s+t=\s*([-\d.]+) rel=\s*([-\d.]+) big=([\d.]+) h=\s*(\d+) w=\s*(\d+) base=\s*(-?\d+) x=\s*(-?\d+) box=(-?\d+),(-?\d+),(-?\d+),(-?\d+)", ln)
        if not m:
            continue
        k, t, rel, big, h, w, base, x, x1, y1, x2, y2 = m.groups()
        t = float(t)
        if kind and k != kind:
            continue
        if tmin is not None and t < tmin:
            continue
        if tmax is not None and t > tmax:
            continue
        out.append(dict(kind=k, t=t, big=float(big), h=int(h), w=int(w), base=int(base), x=int(x),
                        box=(int(x1), int(y1), int(x2), int(y2))))
    return out


def stats(im, box):
    a = np.asarray(im.crop(box)).astype(float) / 255.0
    flat = a.reshape(-1, 3)
    lum = (flat * np.array([0.299, 0.587, 0.114])).sum(axis=1)
    sat = np.array([colorsys.rgb_to_hsv(*p)[1] for p in flat])
    return lum.mean() * 255, sat.mean()


def canopy_vs_grass(im, lines, tmin, tmax, width=1920):
    res = []
    for p in props(lines, tmin=tmin, tmax=tmax):
        if p["kind"] not in ("tree", "pine", "deadtree"):
            continue
        x1, y1, x2, y2 = p["box"]
        if x1 < 0 or x2 > width or y1 < 0:
            continue
        ch = (y2 - y1)
        canopy = (x1 + (x2 - x1) // 4, y1 + ch // 6, x2 - (x2 - x1) // 4, y1 + ch // 2)
        gw = max(24, (x2 - x1) // 2)
        gy1, gy2 = y2 - ch // 6, y2 + ch // 8
        others = [q["box"] for q in props(lines) if q is not p]

        def clear(b):
            for o in others:
                if not (b[2] < o[0] or b[0] > o[2] or b[3] < o[1] or b[1] > o[3]):
                    return False
            return True

        side = None
        for cand in ((x2 + 6, gy1, x2 + 6 + gw, gy2), (x1 - 6 - gw, gy1, x1 - 6, gy2)):
            if cand[0] >= 0 and cand[2] <= width and clear(cand):
                side = cand
                break
        if not side:
            continue
        lc, sc = stats(im, canopy)
        lg, sg = stats(im, side)
        res.append((p["t"], lc, sc, lg, sg))
    return res


def sheet(pairs, box, scale, out, labels=None):
    tiles = []
    for im in pairs:
        c = im.crop(box)
        tiles.append(c.resize((c.width * scale, c.height * scale), Image.NEAREST))
    w, h = tiles[0].size
    s = Image.new("RGB", (w * len(tiles) + 8 * (len(tiles) - 1), h), (70, 0, 0))
    for i, t in enumerate(tiles):
        s.paste(t, (i * (w + 8), 0))
    s.save(out)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "canopy":
        identity, label, scene = sys.argv[2:5]
        im = load(identity, label, scene)
        lines = rows(identity, label, scene)
        for band in ((0.15, 0.3), (0.3, 0.5), (0.5, 0.7), (0.7, 1.01)):
            r = canopy_vs_grass(im, lines, *band)
            if r:
                lc = np.mean([x[1] for x in r]); sc = np.mean([x[2] for x in r])
                lg = np.mean([x[3] for x in r]); sg = np.mean([x[4] for x in r])
                print("t %.2f-%.2f n=%d copa L=%3.0f S=%.2f | grama L=%3.0f S=%.2f | L copa/grama=%.2f  S copa/grama=%.2f"
                      % (band[0], band[1], len(r), lc, sc, lg, sg, lc / max(1, lg), sc / max(0.01, sg)))
    elif cmd == "all":
        R = "tools/preview_out/escala_humana/recortes"
        A = "cenario-escala:antes:b1_tod65"
        D = "cenario-escala:depois:b1_tod65"
        jobs = [
            ("01_poste_frente_inimigo_antes_depois", (540, 380, 1320, 1075), 1, [A, D]),
            ("02_arvores_meio_dir_antes_depois", (1100, 440, 1700, 700), 2, [A, D]),
            ("02b_arvores_meio_esq_antes_depois", (60, 540, 620, 900), 2, [A, D]),
            ("03_crista_castelo_antes_depois", (560, 330, 1360, 560), 2, [A, D]),
            ("03b_crista_castelo_fork_antes_depois", (560, 260, 1360, 560), 1,
             ["cenario-escala:antes:fork_tod65", "cenario-escala-x1:depois:fork_tod65"]),
            ("04_lanterna_tod065_antes_depois", (560, 420, 860, 1075), 1, [A, D]),
            ("04b_lanterna_tod100_antes_depois", (560, 420, 860, 1075), 1,
             ["cenario-escala:antes:b1_tod100", "cenario-escala-x1:depois:b1_tod100"]),
            ("04c_lanterna_tod030_sem_gate_vs_depois", (560, 420, 1300, 1075), 1,
             ["cenario-escala-x3:nogate:b1_tod30", "cenario-escala-x3:depois:b1_tod30"]),
            ("05_base_poste_frente_antes_depois", (520, 860, 840, 1075), 2, [A, D]),
            ("05b_base_poste_meio_sombra_antes_depois", (1040, 600, 1340, 1060), 2, [A, D]),
            ("05c_poste_t046_sombra_antes_depois", (640, 480, 920, 900), 2, [A, D]),
        ]
        for name, box, scale, specs in jobs:
            sheet([load(*sp.split(":")) for sp in specs], box, scale, os.path.join(R, name + ".png"))
            print(name)
    elif cmd == "sheet":
        out = sys.argv[2]
        box = tuple(int(v) for v in sys.argv[3].split(","))
        scale = int(sys.argv[4])
        ims = [load(*spec.split(":")) for spec in sys.argv[5:]]
        sheet(ims, box, scale, out)
        print(out)
