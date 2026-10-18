import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets", "sprites", "world")
BIOMES = ["fields", "highlands", "abyss", "frost", "marsh", "dusk"]
SEARCH = 12
OVERLAP = int(os.environ.get("SEAM_OVERLAP", "24"))


def premul(a):
    a = a.astype(float)
    return np.concatenate([a[:, :, :3] * a[:, :, 3:4] / 255, a[:, :, 3:4]], axis=2)


def paths(b):
    out = [os.path.join(WORLD, b + "_mountains.png")]
    f = os.path.join(WORLD, b + "_mountains_front.png")
    if os.path.exists(f):
        out.append(f)
    return out


def col_jump(ims, i0, i1):
    return float(np.mean([np.abs(i[:, i1] - i[:, i0]).sum(axis=1).mean() for i in ims]))


def neighbor(ims):
    w = ims[0].shape[1]
    return float(np.mean([col_jump(ims, x, x + 1) for x in range(0, w - 1, 3)]))


def seam_path(err):
    h, n = err.shape
    cost = err.copy()
    back = np.zeros((h, n), dtype=int)
    big = 1e18
    cost[:, 0] = big
    cost[:, n - 1] = big
    for y in range(1, h):
        for k in range(n):
            best, bk = big, k
            for d in (-1, 0, 1):
                kk = k + d
                if 0 <= kk < n and cost[y - 1, kk] < best:
                    best, bk = cost[y - 1, kk], kk
            cost[y, k] = cost[y, k] + best
            back[y, k] = bk
    k = int(np.argmin(cost[h - 1]))
    path = [0] * h
    for y in range(h - 1, -1, -1):
        path[y] = k
        k = back[y, k]
    return path, float(cost[h - 1].min())


def plan(ims, a, e):
    err = None
    for i in ims:
        c = i[:, a:e]
        l = c.shape[1]
        d = np.abs(c[:, l - OVERLAP:] - c[:, :OVERLAP]).sum(axis=2)
        err = d if err is None else err + d
    return seam_path(err)


def best_plan(ims):
    w = ims[0].shape[1]
    best = None
    for a in range(0, SEARCH, 2):
        for e in range(w - SEARCH + 1, w + 1, 2):
            path, c = plan(ims, a, e)
            if best is None or c < best[0]:
                best = (c, a, e, path)
    return best


def quilt(raw, a, e, path):
    c = raw[:, a:e]
    l = c.shape[1]
    out = c[:, : l - OVERLAP].copy()
    tail = c[:, l - OVERLAP:]
    for y, k in enumerate(path):
        out[y, :k] = tail[y, :k]
    return out


def sheet(raws, out, k=3):
    rows = []
    for r in raws:
        h, w = r.shape[:2]
        im = Image.fromarray(np.ascontiguousarray(r))
        strip = Image.new("RGBA", (w * 2, h), (255, 0, 255, 255))
        strip.alpha_composite(im, (0, 0))
        strip.alpha_composite(im, (w, 0))
        crop = strip.crop((w - 60, 0, w + 60, h))
        rows.append(crop.resize((crop.width * k, crop.height * k), Image.NEAREST))
    H = sum(r.height + 4 for r in rows)
    W = max(r.width for r in rows)
    s = Image.new("RGBA", (W, H), (40, 40, 40, 255))
    y = 0
    for r in rows:
        s.alpha_composite(r, (0, y))
        y += r.height + 4
    s.save(out)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "measure"
    outdir = sys.argv[2] if len(sys.argv) > 2 else None
    pick = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else set()
    for b in BIOMES:
        raws = [np.asarray(Image.open(p).convert("RGBA")) for p in paths(b)]
        ims = [premul(r) for r in raws]
        w = raws[0].shape[1]
        line = "%s largura=%d vizinho=%.1f costura=%.1f" % (b, w, neighbor(ims), col_jump(ims, w - 1, 0))
        if mode == "apply" and b in pick:
            c, a, e, path = best_plan(ims)
            new = [quilt(r, a, e, path) for r in raws]
            for p, r in zip(paths(b), new):
                Image.fromarray(np.ascontiguousarray(r)).save(p)
            raws = new
            nims = [premul(r) for r in new]
            nw = new[0].shape[1]
            line += " -> corte %d:%d costura cruzada %d px largura=%d costura=%.1f u(202)=%.4f" % (
                a, e, OVERLAP, nw, col_jump(nims, nw - 1, 0), (202 - a) / nw)
        print(line)
        if outdir:
            sheet(raws, os.path.join(outdir, "costura_%s.png" % b))


if __name__ == "__main__":
    main()
