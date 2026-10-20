import glob
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WORLD = os.path.join(ROOT, "assets", "sprites", "world")
OUT = os.path.join(ROOT, "src", "data", "castle_feet.lua")
BIOMES = ["fields", "highlands", "abyss", "frost", "marsh", "dusk"]


def frames_of(bid):
    files = [os.path.join(WORLD, bid + "_castle.png")]
    for sub in (bid + "_castle", bid + "_castle_door"):
        d = os.path.join(WORLD, "anim", sub)
        i = 0
        while os.path.exists(os.path.join(d, "%d.png" % i)):
            files.append(os.path.join(d, "%d.png" % i))
            i += 1
    return files


def gaps_of(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    a = im.getchannel("A").load()
    out = []
    for x in range(w):
        g = -1
        for y in range(h - 1, -1, -1):
            if a[x, y] > 0:
                g = h - 1 - y
                break
        out.append(g)
    return w, h, out


def fill_holes(g):
    n = len(g)
    left, right = [0] * n, [0] * n
    m = 10 ** 9
    for i in range(n):
        if g[i] >= 0:
            m = min(m, g[i])
        left[i] = m
    m = 10 ** 9
    for i in range(n - 1, -1, -1):
        if g[i] >= 0:
            m = min(m, g[i])
        right[i] = m
    return [max(left[i], right[i]) if g[i] >= 0 else -1 for i in range(n)]


def scan(bid):
    w = h = None
    worst = None
    files = frames_of(bid)
    for f in files:
        fw, fh, g = gaps_of(f)
        if w is None:
            w, h, worst = fw, fh, g
        else:
            if (fw, fh) != (w, h):
                sys.exit("[FAIL] %s: quadro %s com tamanho %dx%d (base %dx%d)" % (bid, f, fw, fh, w, h))
            worst = [max(p, q) for p, q in zip(worst, g)]
    return w, h, fill_holes(worst), len(files)


def main():
    lines = ["return {"]
    for bid in BIOMES:
        w, h, g, n = scan(bid)
        print("[ok] %s %dx%d %d quadros, pe sobe ate %d px nas bordas" % (bid, w, h, n, max(g)))
        lines.append("    %s = { iw = %d, ih = %d, frames = %d, gap = {" % (bid, w, h, n))
        for i in range(0, len(g), 32):
            lines.append("        " + ", ".join(str(v) for v in g[i:i + 32]) + ",")
        lines.append("    } },")
    lines.append("}")
    with open(OUT, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("[ok] " + OUT)


if __name__ == "__main__":
    main()
