import math
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, "assets", "branding", "icon.png")
OUT = os.path.join(ROOT, "assets", "branding")
DATA = os.path.join(ROOT, "src", "data", "menu_brand.lua")
REF = os.path.join(ROOT, "tools", "preview_out", "menu_logo", "ref")

I_INK, I_BLOOD, I_G0, I_G1, I_G2, I_G3 = 1, 2, 3, 4, 5, 6
T_RAY0, T_RAYSTEP, T_CHARGE, T_FLASH = 1.24, 0.125, 2.26, 2.62
TREV_SCALE = 1.25

PAL_LIT = [(0, 0, 0), (22, 10, 18), (62, 20, 18), (122, 74, 26), (172, 118, 42), (212, 160, 68), (240, 198, 108)]
PAL_UNLIT = [(0, 0, 0), (14, 8, 14), (30, 12, 16), (48, 30, 22), (60, 38, 26), (74, 48, 30), (88, 58, 34)]
PAL_WARM = [(0, 0, 0), (70, 30, 22), (120, 50, 28), (196, 128, 52), (226, 168, 74), (246, 206, 118), (255, 230, 160)]
PAL_HOT = [(0, 0, 0), (160, 96, 60), (200, 120, 70), (250, 214, 150), (255, 230, 176), (255, 242, 206), (255, 250, 232)]
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def bayer(h, w):
    return np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]


def load_seal():
    a = np.array(Image.open(ICON).convert("RGB").resize((128, 128), Image.NEAREST)).astype(int)
    lum = a.mean(2)
    H, W = lum.shape
    bg = np.zeros((H, W), bool)
    q = deque()
    for y in range(H):
        q.append((y, 0))
        q.append((y, W - 1))
    for x in range(W):
        q.append((0, x))
        q.append((H - 1, x))
    while q:
        y, x = q.popleft()
        if bg[y, x] or lum[y, x] < 75:
            continue
        bg[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not bg[ny, nx]:
                q.append((ny, nx))
    seal = ~bg
    lab = np.zeros((H, W), int)
    n = 0
    sizes = []
    for y in range(H):
        for x in range(W):
            if seal[y, x] and not lab[y, x]:
                n += 1
                cnt = 0
                q.append((y, x))
                lab[y, x] = n
                while q:
                    cy, cx = q.popleft()
                    cnt += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and seal[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((ny, nx))
                sizes.append(cnt)
    keep = lab == (int(np.argmax(sizes)) + 1)
    idx = np.zeros((H, W), np.int8)
    ink = keep & (lum < 60)
    blood = ink & (a[..., 0] > a[..., 2] + 10) & (a[..., 0] > 26)
    idx[ink] = I_INK
    idx[blood] = I_BLOOD
    gold = keep & ~ink
    idx[gold & (lum < 100)] = I_G0
    idx[gold & (lum >= 100) & (lum < 130)] = I_G1
    idx[gold & (lum >= 130) & (lum < 152)] = I_G2
    idx[gold & (lum >= 152)] = I_G3
    ys, xs = np.nonzero(keep)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return idx[y0:y1, x0:x1]


class Seal:
    def __init__(self):
        self.idx = load_seal()
        self.h, self.w = self.idx.shape
        self.mask = self.idx > 0
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.cx = (self.w - 1) / 2.0
        self.cy = (self.h - 1) / 2.0
        dx, dy = xx - self.cx, yy - self.cy
        self.r = np.hypot(dx, dy)
        ang = np.arctan2(dy, dx)
        self.cw = np.mod(ang + math.pi / 2, 2 * math.pi) / (2 * math.pi)
        self.ray = np.full((self.h, self.w), -1, np.int8)
        self.along = np.zeros((self.h, self.w), np.float32)
        self.raylen = []
        for k in range(8):
            th = -math.pi / 2 + k * math.pi / 4
            ux, uy = math.cos(th), math.sin(th)
            al = dx * ux + dy * uy
            dp = np.abs(-dx * uy + dy * ux)
            L = float(al[self.mask & (dp < 1.5)].max())
            w0 = 9.0 if k % 2 == 0 else 7.5
            inside = self.mask & (al > 5) & (dp <= w0 * (1 - al / (L + 1)) + 0.6)
            sel = inside & (self.ray < 0)
            self.ray[sel] = k
            self.along[sel] = al[sel] / L
            self.raylen.append(L)
        rr = self.r
        self.hub = self.mask & (rr < 12)
        self.ring = self.mask & (self.ray < 0) & (rr >= 37.0)
        self.inner = self.mask & ~self.ring & ~self.hub & (self.ray < 0)
        jit = bayer(self.h, self.w)
        t = np.zeros((self.h, self.w), np.float32)
        t[self.ring] = (0.22 + 0.78 * self.cw[self.ring])
        body = self.mask & ~self.ring
        t[body] = 0.12 + 0.75 * np.clip(rr[body] / 60.0, 0, 1) + 0.10 * self.cw[body]
        self.t_reveal = 0.10 + t * 0.95 + jit * 0.05
        self.tips = []
        for k in range(8):
            th = -math.pi / 2 + k * math.pi / 4
            L = self.raylen[k]
            self.tips.append((self.cx + math.cos(th) * L, self.cy + math.sin(th) * L))

    def encode(self):
        rs = self.ring | self.inner
        R = self.idx.astype(np.uint8)
        G = np.zeros((self.h, self.w), np.uint8)
        G[self.ray >= 0] = (self.ray[self.ray >= 0] + 1).astype(np.uint8)
        G[rs] = 9
        G[self.hub] += 16
        B = np.zeros((self.h, self.w), np.float32)
        B[self.ray >= 0] = self.along[self.ray >= 0]
        B[rs] = self.cw[rs]
        B = np.clip(np.round(B * 255), 0, 255).astype(np.uint8)
        A = np.clip(np.round(self.t_reveal / TREV_SCALE * 255), 1, 255).astype(np.uint8)
        A[~self.mask] = 0
        R[~self.mask] = 0
        G[~self.mask] = 0
        B[~self.mask] = 0
        return np.dstack([R, G, B, A])

    def render(self, T, final=False):
        P = {k: np.array(v, np.float32) for k, v in
             (("lit", PAL_LIT), ("unlit", PAL_UNLIT), ("warm", PAL_WARM), ("hot", PAL_HOT))}
        a = T - self.t_reveal
        vis = self.mask & (a >= 0) if not final else self.mask.copy()
        lvl = np.zeros((self.h, self.w), np.int8)
        if not final:
            lvl[vis & (a < 0.05)] = 3
            lvl[vis & (a >= 0.05) & (a < 0.13)] = 2
        lit = np.zeros((self.h, self.w), np.int8)
        for k in range(8):
            tk = T_RAY0 + k * T_RAYSTEP
            sel = self.ray == k
            ak = T - tk - self.along * 0.10
            lit[sel & (ak >= 0.11)] = 1
            lit[sel & (ak >= 0.045) & (ak < 0.11)] = 2
            lit[sel & (ak >= 0) & (ak < 0.045)] = 3
        ar = T - T_CHARGE - self.cw * 0.22
        rs = self.ring | self.inner
        lit[rs & (ar >= 0.045)] = 1
        lit[rs & (ar >= 0.016) & (ar < 0.045)] = 2
        lit[rs & (ar >= 0) & (ar < 0.016)] = 3
        ah = T - (T_CHARGE + 0.2)
        lit[self.hub & (ah >= 0.06)] = 1
        lit[self.hub & (ah >= 0) & (ah < 0.06)] = 3
        if final:
            lit[:] = 1
        flash = T - T_FLASH
        idx = self.idx
        out = P["unlit"][idx]
        out = np.where((lit == 1)[..., None], P["lit"][idx], out)
        out = np.where((lit == 2)[..., None], P["warm"][idx], out)
        out = np.where((lit == 3)[..., None], P["hot"][idx], out)
        if not final and 0 <= flash < 0.36:
            pal = P["hot"] if flash < 0.14 else P["warm"]
            if flash < 0.05:
                out = np.broadcast_to(np.array((255, 248, 226), np.float32), out.shape).copy()
            else:
                out = pal[idx]
        out = np.where((lvl == 2)[..., None], P["warm"][idx], out)
        out = np.where((lvl == 3)[..., None], P["hot"][np.maximum(idx, I_G2)], out)
        return out, vis


def word():
    img = store_art.logo(1, (6, 4))
    a = np.array(img).astype(np.int32)
    h, w = a.shape[:2]
    rgb = a[..., :3]
    ink = np.all(rgb == store_art.INK, -1)
    ink2 = np.all(rgb == store_art.INK2, -1)
    gold = (a[..., 3] == 255) & ~ink & ~ink2
    col = gold.any(0)
    segs = []
    x = 0
    while x < w:
        if col[x]:
            s = x
            while x < w and col[x]:
                x += 1
            segs.append([s, x])
        else:
            x += 1
    cuts = [0]
    for i in range(len(segs) - 1):
        cuts.append((segs[i][1] + segs[i + 1][0]) // 2)
    cuts.append(w)
    return img, gold, cuts


def mask_png(m):
    a = np.zeros(m.shape + (4,), np.uint8)
    a[m] = (255, 255, 255, 255)
    return Image.fromarray(a, "RGBA")


def lua_pal(name, pal):
    return "    %s = { %s },\n" % (name, ", ".join("{ %d, %d, %d }" % c for c in pal))


def bake():
    os.makedirs(OUT, exist_ok=True)
    S = Seal()
    img, gold, cuts = word()
    img.save(os.path.join(OUT, "wordmark.png"), optimize=True)
    mask_png(gold).save(os.path.join(OUT, "wordmark_gold.png"), optimize=True)
    rgb, vis = S.render(99, final=True)
    fin = np.zeros((S.h, S.w, 4), np.uint8)
    fin[vis, :3] = np.clip(rgb[vis], 0, 255).astype(np.uint8)
    fin[vis, 3] = 255
    Image.fromarray(fin, "RGBA").save(os.path.join(OUT, "seal.png"), optimize=True)
    Image.fromarray(S.encode(), "RGBA").save(os.path.join(OUT, "seal_data.png"), optimize=True)
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("return {\n")
        f.write("    seal = { w = %d, h = %d, cx = %.4f, cy = %.4f, trevScale = %.4f },\n"
                % (S.w, S.h, S.cx, S.cy, TREV_SCALE))
        f.write("    tips = { %s },\n" % ", ".join("{ %.2f, %.2f }" % t for t in S.tips))
        f.write("    word = { w = %d, h = %d },\n" % (img.width, img.height))
        f.write("    cuts = { %s },\n" % ", ".join(str(c) for c in cuts))
        f.write("    gap = 7,\n")
        f.write(lua_pal("palLit", PAL_LIT))
        f.write(lua_pal("palUnlit", PAL_UNLIT))
        f.write(lua_pal("palWarm", PAL_WARM))
        f.write(lua_pal("palHot", PAL_HOT))
        f.write("}\n")
    for p in ("wordmark.png", "wordmark_gold.png", "seal.png", "seal_data.png"):
        print("[ok] " + os.path.join(OUT, p))
    print("[ok] " + DATA)


def refs(ts):
    os.makedirs(REF, exist_ok=True)
    S = Seal()
    for t in ts:
        rgb, vis = S.render(t)
        a = np.zeros((S.h, S.w, 4), np.uint8)
        a[vis, :3] = np.clip(rgb[vis], 0, 255).astype(np.uint8)
        a[vis, 3] = 255
        p = os.path.join(REF, "seal_%.2f.png" % t)
        Image.fromarray(a, "RGBA").save(p)
        print("[ok] " + p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "bake"
    if cmd == "ref":
        refs([float(v) for v in sys.argv[2:]])
    else:
        bake()
