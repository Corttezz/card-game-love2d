#!/usr/bin/env python3
"""
tools/store_art.py — arte da página da Steam (capsules, hero, logo, ícone,
screenshots) a partir do PRÓPRIO jogo.

Princípio: nada de pintura nova "estilo IA" por cima. O fundo de toda capsule
é o mundo REAL renderizado pelo motor (WorldRoad + inimigo, sem HUD) no
tamanho exato do asset — `love . screenshot_enemy_scene` com
ENEMY_SCENE_WORLD_ONLY=1 e ENEMY_SCENE_VIRTUAL=<w>x<h>. O logotipo é
desenhado PIXEL A PIXEL a partir dos glifos nativos (8px) da fonte do jogo
(assets/fonts/pixel.ttf): cada glifo vira bloco 2x2 com bisel de metal,
contorno duplo e sombra, e só então escala por fator INTEIRO (nearest).

  python tools/store_art.py capture     # renders do motor (lento, ~1 min/each)
  python tools/store_art.py build       # compõe todos os PNGs em steam/store/
  python tools/store_art.py shots       # screenshots 1920x1080 do jogo real
  python tools/store_art.py sheet       # prancha de contato
Saída: steam/store/*.png (ver steam/store/README.md).
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "steam", "store")
SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", "card-game-storeart")
CACHE = os.path.join(ROOT, "tools", "preview_out", "store_capture")
FONT = os.path.join(ROOT, "assets", "fonts", "pixel.ttf")
LOVEC = shutil.which("lovec") or r"C:\Program Files\LOVE\lovec.exe"

# Paleta do logotipo (ouro gasto da UI: seals/banners) — de cima pra baixo
GOLD = [(255, 236, 170), (246, 206, 112), (228, 172, 72), (196, 128, 44),
        (150, 88, 30), (112, 60, 22)]
INK = (24, 14, 10)
INK2 = (58, 26, 18)          # contorno externo (sangue seco)
SHADOW = (10, 6, 6)


# ---------------------------------------------------------------------------
# LOGOTIPO
# ---------------------------------------------------------------------------
def glyph_mask(text):
    """Máscara 1-bit dos glifos NATIVOS (8px) da fonte do jogo."""
    f = ImageFont.truetype(FONT, 8)
    im = Image.new("L", (len(text) * 10 + 8, 16), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((2, 2), text, font=f, fill=255)
    return np.array(im.crop(im.getbbox())) > 0


def dilate(m, r=1):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def logo(scale=6, letter=(3, 2), tagline=False):
    """GRIMOIRE em metal dourado: glifo nativo → blocos `letter`x`letter` →
    bisel (topo claro, base escura, faixas de ouro por linha) → contorno de
    tinta 1px → contorno de sangue seco 1px → sombra deslocada → x`scale`."""
    g = glyph_mask("GRIMOIRE")
    # glifo esticado na VERTICAL (3:2): título de grimório é alto e estreito,
    # e o bloco quadrado da fonte lia como placar de fliperama
    g = np.kron(g, np.ones(letter, bool))
    pad = 4
    H, W = g.shape[0] + pad * 2, g.shape[1] + pad * 2
    m = np.zeros((H, W), bool)
    m[pad:pad + g.shape[0], pad:pad + g.shape[1]] = g
    o1 = dilate(m) & ~m
    o2 = dilate(m | o1) & ~(m | o1)
    rgba = np.zeros((H, W, 4), np.uint8)
    # sombra: silhueta inteira deslocada 2px pra baixo/direita
    sil = m | o1 | o2
    sh = np.roll(np.roll(sil, 2, 0), 1, 1) & ~sil
    rgba[sh] = SHADOW + (200,)
    rgba[o2] = INK2 + (255,)
    rgba[o1] = INK + (255,)
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    for y, x in zip(ys, xs):
        t = (y - top) / max(1, bot - top)
        c = GOLD[min(len(GOLD) - 1, int(t * len(GOLD)))]
        # bisel: pixel com vazio em cima = brilho; com vazio embaixo = sombra
        if not m[y - 1, x]:
            c = tuple(min(255, v + 34) for v in c)
        elif not m[y + 1, x]:
            c = tuple(int(v * 0.62) for v in c)
        elif not m[y, x - 1]:
            c = tuple(min(255, v + 14) for v in c)
        rgba[y, x] = c + (255,)
    img = Image.fromarray(rgba)
    img = img.crop(img.getbbox())
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def emblem(name, size):
    im = Image.open(os.path.join(ROOT, "assets/sprites/emblems", name + ".png")).convert("RGBA")
    k = max(1, size // im.width)
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def book(scale):
    """O GRIMÓRIO aberto do menu (assets/sprites/scenes/menu.png), recortado
    da arte original e com fundo removido pela cor do altar."""
    im = Image.open(os.path.join(ROOT, "assets/sprites/scenes/menu.png")).convert("RGBA")
    crop = im.crop((112, 164, 290, 214))
    return crop.resize((crop.width * scale, crop.height * scale), Image.NEAREST)



# ---------------------------------------------------------------------------
# CAPTURAS DO MOTOR (fundo de toda capsule)
# ---------------------------------------------------------------------------
# nome → (modo ato_nodeType, sprite forçado, w, h)
CAPTURES = {
    # sprite "none" = mundo VAZIO (castelo à vista); o monstro entra na
    # composição em escala inteira, onde a capsule precisa dele
    "dusk_wide":   ("6_elite", "none", 1232, 706),
    "dusk_header": ("6_elite", "none", 920, 430),
    "dusk_small":  ("6_elite", "none", 924, 348),
    "dusk_hero":   ("6_elite", "none", 3840, 1240),
    # retratos: o mundo é renderizado LARGO (a escala do mundo segue a altura;
    # em canvas estreito as árvores da borda engolem o quadro) e a capsule é
    # o recorte central — ver CROP_W
    "dusk_tall":   ("6_elite", "none", 1600, 896),
    "fields_tall": ("1_elite", "none", 1600, 900),
    "fields_head": ("1_elite", "none", 920, 430),
    "frost_bg":    ("4_battle", "none", 1438, 810),
    "abyss_bg":    ("3_elite", "none", 1438, 810),
}


def run_love(args, env_extra):
    env = dict(os.environ, CARDGAME_IDENTITY="card-game-storeart", **env_extra)
    r = subprocess.run([LOVEC, "."] + args, cwd=ROOT, env=env,
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=600)
    out = (r.stdout or "") + (r.stderr or "")
    for line in out.splitlines():
        if "salvo" in line or "rror" in line:
            print("   ", line.strip())
    return out


def capture(names=None):
    os.makedirs(CACHE, exist_ok=True)
    for name, (mode, sid, w, h) in CAPTURES.items():
        if names and name not in names:
            continue
        print(f"[capture] {name} {mode} {sid} {w}x{h}", flush=True)
        run_love(["screenshot_enemy_scene", mode], {
            "ENEMY_SCENE_WORLD_ONLY": "1", "ENEMY_SCENE_ID": sid,
            "ENEMY_SCENE_VIRTUAL": f"{w}x{h}"})
        src = os.path.join(SAVE, f"enemy_scene_{mode}_{sid}_world_{w}x{h}.png")
        if os.path.exists(src):
            shutil.copy(src, os.path.join(CACHE, name + ".png"))
        else:
            print("   FALTOU", src)


# ---------------------------------------------------------------------------
# COMPOSIÇÃO
# ---------------------------------------------------------------------------
def sprite(eid, k):
    p = os.path.join(ROOT, "assets/sprites/characters/enemies", eid,
                     "animations/idle/south/0.png")
    im = Image.open(p).convert("RGBA")
    im = im.crop(im.getbbox())
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


CROP_W = {"dusk_tall": 748, "fields_tall": 600}


def cap(name):
    im = Image.open(os.path.join(CACHE, name + ".png")).convert("RGBA")
    cw = CROP_W.get(name)
    if cw:
        x = (im.width - cw) // 2
        im = im.crop((x, 0, x + cw, im.height))
    return im


def shade_band(img, y0, y1, a0, a1, color=(12, 6, 10)):
    """Faixa escura em gradiente QUANTIZADO (degraus de 4px — pixel art não
    leva gradiente liso) pra dar contraste ao logotipo."""
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    step = 4
    for y in range(y0, y1, step):
        t = (y - y0) / max(1, y1 - y0)
        a = int(a0 + (a1 - a0) * t)
        a = a // 16 * 16
        d.rectangle((0, y, img.width, y + step - 1), fill=color + (a,))
    img.alpha_composite(over)


def ground_shadow(img, cx, by, w):
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for i, a in enumerate((90, 60, 30)):
        ww, hh = w // 2 + i * 6, max(4, w // 12) + i * 2
        d.ellipse((cx - ww, by - hh, cx + ww, by + hh), fill=(8, 4, 8, a))
    img.alpha_composite(over)


def place(img, spr, cx, by, tint=(0.92, 0.80, 0.86)):
    """Pé do sprite na linha `by`, centrado em cx, com sombra de contato.
    `tint` multiplica o sprite pela luz do crepúsculo — sem isso ele sai
    "colado", com luz de estúdio num cenário de entardecer."""
    a = np.asarray(spr).astype(np.float32)
    a[..., :3] *= np.array(tint, np.float32)
    spr = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    ground_shadow(img, cx, by - 2, spr.width)
    img.alpha_composite(spr, (int(cx - spr.width / 2), int(by - spr.height)))


def put_logo(img, cx, cy, scale):
    lg = logo(scale)
    img.alpha_composite(lg, (int(cx - lg.width / 2), int(cy - lg.height / 2)))
    return lg


def save(img, name, rgb=True):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    (img.convert("RGB") if rgb else img).save(p, optimize=True)
    kb = os.path.getsize(p) // 1024
    print(f"[out] {name:28s} {img.size[0]}x{img.size[1]}  {kb} KB")


def build_capsule(bg, logo_scale, logo_cy, boss=None, boss_k=2, boss_cx=0.5,
                  boss_by=0.95, band=(0, 0.45), emblems=None):
    img = bg.copy()
    W, H = img.size
    if boss:
        place(img, sprite(boss, boss_k), W * boss_cx, H * boss_by)
    shade_band(img, int(H * band[0]), int(H * band[1]), 150, 0)
    put_logo(img, W / 2, H * logo_cy, logo_scale)
    if emblems:
        size, y = emblems
        ems = [emblem(n, size) for n in ("warrior", "mage", "rogue")]
        gap = size // 6
        total = sum(e.width for e in ems) + gap * 2
        x = (W - total) // 2
        for e in ems:
            img.alpha_composite(e, (x, int(H * y - e.height / 2)))
            x += e.width + gap
    return img


def build():
    # --- capsules principais (logo + mundo real + chefe) ------------------
    save(build_capsule(cap("dusk_header"), 3, 0.20, "eclipse_queen", 2,
                       0.78, 0.97, band=(0, 0.42)), "header_capsule_920x430.png")
    save(build_capsule(cap("dusk_wide"), 4, 0.17, "eclipse_queen", 3,
                       0.76, 0.98, band=(0, 0.36)), "main_capsule_1232x706.png")
    # small 462x174: compõe em 924x348 e reduz /2 (nearest) — logo ocupa
    # quase toda a largura pra continuar legível no tamanho real
    sm = build_capsule(cap("dusk_small"), 5, 0.42, band=(0, 1.0))
    save(sm.resize((462, 174), Image.NEAREST), "small_capsule_462x174.png")
    save(build_capsule(cap("dusk_tall"), 3, 0.13, "eclipse_queen", 3,
                       0.5, 0.97, band=(0, 0.28), emblems=(96, 0.27)),
         "vertical_capsule_748x896.png")
    # --- biblioteca --------------------------------------------------------
    save(build_capsule(cap("fields_tall"), 3, 0.10, "carrion_king", 3,
                       0.5, 0.97, band=(0, 0.25), emblems=(64, 0.22)),
         "library_capsule_600x900.png")
    save(build_capsule(cap("fields_head"), 3, 0.20, "carrion_king", 2,
                       0.78, 0.97, band=(0, 0.42)), "library_header_920x430.png")
    # hero: SEM texto (a Steam põe o logo por cima); chefe à direita, o lado
    # esquerdo fica livre pro logo do cliente
    hero = cap("dusk_hero")
    place(hero, sprite("eclipse_queen", 6), hero.width * 0.72, hero.height * 0.96)
    save(hero, "library_hero_3840x1240.png")
    # logo 1280x720 transparente
    lg = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    l = logo(10)
    lg.alpha_composite(l, ((1280 - l.width) // 2, (720 - l.height) // 2))
    save(lg, "library_logo_1280x720.png", rgb=False)
    # --- page background: mundo escurecido e dessaturado (fundo da página) -
    pb = cap("abyss_bg")
    arr = np.asarray(pb.convert("RGB")).astype(np.float32)
    gray = arr.mean(axis=2, keepdims=True)
    arr = (arr * 0.45 + gray * 0.55) * 0.42
    save(Image.fromarray(arr.clip(0, 255).astype(np.uint8)),
         "page_background_1438x810.png")
    # --- ícone da comunidade 184x184: G do logotipo sobre selo -----------
    save(community_icon(), "community_icon_184x184.png")


def community_icon():
    """Selo de cera da UI (seal_common, 32px) + o "G" do logotipo, montados
    numa grade NATIVA de 46px e só então x4 — o pixel do selo e o da letra
    saem do MESMO tamanho (selo x6 com letra x4 lia como duas resoluções)."""
    N = 46
    seal = Image.open(os.path.join(ROOT, "assets/sprites/ui/seal_common.png")).convert("RGBA")
    seal = seal.crop(seal.getbbox())
    base = Image.new("RGBA", (N, N), (26, 16, 14, 255))
    k = max(1, (N - 2) // seal.width)
    seal = seal.resize((seal.width * k, seal.height * k), Image.NEAREST)
    base.alpha_composite(seal, ((N - seal.width) // 2, (N - seal.height) // 2))
    g = glyph_mask("G")
    g = np.kron(g, np.ones((3, 2), bool))
    pad = 2
    m = np.zeros((g.shape[0] + 2 * pad, g.shape[1] + 2 * pad), bool)
    m[pad:-pad, pad:-pad] = g
    o1 = dilate(m) & ~m
    rgba = np.zeros(m.shape + (4,), np.uint8)
    rgba[o1] = INK + (255,)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        t = (y - ys.min()) / max(1, ys.max() - ys.min())
        c = GOLD[min(len(GOLD) - 1, int(t * len(GOLD)))]
        if not m[y - 1, x]:
            c = tuple(min(255, v + 34) for v in c)
        elif not m[y + 1, x]:
            c = tuple(int(v * 0.62) for v in c)
        rgba[y, x] = c + (255,)
    gl = Image.fromarray(rgba)
    gl = gl.crop(gl.getbbox())
    base.alpha_composite(gl, ((N - gl.width) // 2, (N - gl.height) // 2))
    return base.resize((184, 184), Image.NEAREST)


# ---------------------------------------------------------------------------
# SCREENSHOTS 1920x1080 DO JOGO REAL
# ---------------------------------------------------------------------------
# (arquivo final, args do love, env extra, arquivo gerado no save dir)
# TOOL_WINDOW abre a janela de captura em 1920x1080 antes do tool;
# TOOL_LOCALE / *_LOCALE escolhem o idioma ({loc}).
SHOTS = [
    ("01_menu", ["screenshot_menu_v2"], {}, "menu_v2_osd.png"),
    ("02_class_select", ["screenshot_class_select"],
     {"CS_SIZES": "1920x1080"}, "class_select_1920x1080_pick.png"),
    ("03_road_battle", ["test_one", "screenshot_damage_preview"],
     {"PREVIEW_W": "1920", "PREVIEW_H": "1080", "PREVIEW_LOCALE": "{loc}"},
     "dmgprev_1920x1080_{loc}_sel3.png"),
    ("04_boss_room", ["screenshot_enemy_scene", "3_boss"],
     {"ENEMY_SCENE_VIRTUAL": "1920x1080", "ENEMY_SCENE_CLEAN": "1",
      "ENEMY_SCENE_INTENT": "kind=strong,perHit=24,hits=1", "TOOL_WINDOW": ""},
     "enemy_scene_3_boss_intent_strong_1920x1080.png"),
    ("05_shop", ["screenshot_shop"], {"SHOP_LOCALE": "{loc}"},
     "shop_1_repouso.png"),
    ("06_road_fork", ["screenshot_worldroad", "b1_forkhover"],
     {"STORE_NOTOPBAR": "1"}, "worldroad_screenshot.png"),
    ("07_collection", ["screenshot_collection", "warrior_bash"],
     {"STORE_REVEAL": "1"}, "collection_grid.png"),
    ("08_victory", ["test_one", "screenshot_end_screens", "{loc}"], {},
     "end_victory_{loc}_1920x1080.png"),
]


def shots(locales=("en", "pt_BR")):
    for loc in locales:
        dest = os.path.join(OUT, "screenshots", loc)
        os.makedirs(dest, exist_ok=True)
        for name, args, env, produced in SHOTS:
            env = {k: v.format(loc=loc) for k, v in env.items()}
            env.setdefault("TOOL_WINDOW", "1920x1080")
            if env["TOOL_WINDOW"] == "":
                env.pop("TOOL_WINDOW")
            env["TOOL_LOCALE"] = loc
            args = [a.format(loc=loc) for a in args]
            print(f"[shot] {loc} {name}", flush=True)
            src = os.path.join(SAVE, produced.format(loc=loc))
            if os.path.exists(src):
                os.remove(src)
            try:
                run_love(args, env)
            except subprocess.TimeoutExpired:
                print("   TIMEOUT")
            if not os.path.exists(src):
                print("   FALTOU", src)
                continue
            im = Image.open(src).convert("RGB")
            if im.size != (1920, 1080):
                print("   TAMANHO ERRADO", im.size)
                continue
            p = os.path.join(dest, name + ".png")
            im.save(p, optimize=True)
            print(f"   ok {os.path.getsize(p) // 1024} KB")


def sheet():
    """Prancha de contato de tudo em steam/store (pra revisão rápida)."""
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png")
                   and not f.startswith("_"))
    shots_dir = os.path.join(OUT, "screenshots", "en")
    shot_files = sorted(os.listdir(shots_dir)) if os.path.isdir(shots_dir) else []
    tiles = [(f, Image.open(os.path.join(OUT, f)).convert("RGBA")) for f in files]
    tiles += [("screenshots/en/" + f,
               Image.open(os.path.join(shots_dir, f)).convert("RGBA"))
              for f in shot_files]
    TH = 220
    rows, row, w = [], [], 0
    for name, im in tiles:
        k = TH / im.height
        t = im.resize((max(1, int(im.width * k)), TH), Image.LANCZOS)
        if w + t.width > 2400 and row:
            rows.append(row)
            row, w = [], 0
        row.append((name, t))
        w += t.width + 12
    rows.append(row)
    W = max(sum(t.width + 12 for _, t in r) for r in rows) + 12
    H = len(rows) * (TH + 30) + 12
    out = Image.new("RGBA", (W, H), (22, 16, 14, 255))
    d = ImageDraw.Draw(out)
    y = 12
    for r in rows:
        x = 12
        for name, t in r:
            bg = Image.new("RGBA", t.size, (60, 50, 70, 255))
            bg.alpha_composite(t)
            out.alpha_composite(bg, (x, y))
            d.text((x, y + TH + 4), name, fill=(240, 220, 170))
            x += t.width + 12
        y += TH + 30
    p = os.path.join(OUT, "_contact_sheet.png")
    out.convert("RGB").save(p)
    print(p)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "capture":
        capture(sys.argv[2:] or None)
    elif cmd == "shots":
        shots(tuple(sys.argv[2:]) or ("en", "pt_BR"))
    elif cmd == "sheet":
        sheet()
    elif cmd == "build":
        build()
    elif cmd == "logo":
        logo(int(sys.argv[2]) if len(sys.argv) > 2 else 6).save(
            os.path.join(CACHE, "_logo_test.png"))
    else:
        print(__doc__)
