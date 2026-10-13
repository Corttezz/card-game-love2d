#!/usr/bin/env python3
"""
tools/pixellab_intent_icons.py — set de ÍCONES DE INTENT do inimigo (+ status
de debuff no jogador), v2 (Out/2026).

v1 reprovada pelo dono ("dá pra gerar muito melhor; até o de ataque é ruim;
mais alinhado ao design system"). Causa técnica medida: os PNGs eram 64px
desenhados num alvo de 34px (EnemyHud.ICON_SIZE) — escala 0.53 nearest, o
pixel picota. v2 é NATIVA no tamanho de uso:
  - intent principal 32x32 → IconLoader.computeScale(32, 34) = 1 (nítido)
  - pequenos 24x24 (extras do box EXTRA_ICON=24, pills alvo ~27-31) → 1
Estilo = sistema grimório/sépia da UI (assets/sprites/ui/stat_*.png, seals):
metal envelhecido, osso, sangue, ouro gasto, contorno escuro de 1px, luz de
cima-esquerda. Formas distintas (silhueta), não só cor.

  python tools/pixellab_intent_icons.py gen <nome> [seed]   # candidatos
  python tools/pixellab_intent_icons.py pick <nome> <N>     # instala
  python tools/pixellab_intent_icons.py board               # prancha final
Candidatos em tools/preview_out/intent_icons/<nome>/.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N  # call/b64/wait_job/download_all

ROOT = N.ROOT
ICONS = os.path.join(ROOT, "assets/sprites/icons")
OUT = os.path.join(ROOT, "tools/preview_out/intent_icons")
STYLE_BOARD = os.path.join(OUT, "_style_board.png")  # stat_shield/hourglass/seal/star

STYLE = ("tiny dark fantasy grimoire UI icon, pixel art at native size, one "
         "bold readable silhouette centered, crisp dark brown-black 1px "
         "outline, earthy desaturated palette (aged gold, tarnished steel, "
         "bone white, blood crimson, burnt sienna, charcoal), light from the "
         "upper left, hard-edged pixel clusters, NO anti-aliasing, NO smooth "
         "gradients, NO text, transparent background, matches the style of "
         "the reference icons")

# nome → (tamanho, descrição). Uma FORMA por intent.
SPECS = {
    "intent_attack": (32, "a single steel longsword pointing diagonally up "
                      "to the right, aged gold crossguard, dark leather grip, "
                      "a small crimson blood drip on the blade"),
    "intent_strong": (32, "a huge heavy double-bladed battle axe, wide "
                      "crescent steel blades, blood crimson edges, short "
                      "impact lines radiating behind it, menacing"),
    "intent_multi": (32, "three short daggers fanned out in a spread, blades "
                     "pointing up, steel blades and aged gold hilts"),
    "intent_defense": (32, "a round wooden shield with an iron rim and "
                       "central iron boss, front view"),
    "intent_buff": (32, "a raised clenched iron gauntlet fist with a bold "
                    "aged gold upward arrow behind it, empowerment"),
    "intent_debuff": (32, "a cursed violet eye inside a dark purple teardrop "
                      "of smoke, dripping, ominous hex"),
    "intent_charge": (32, "an hourglass with aged gold frame and glowing "
                      "ember orange sand, small flames at the top, a "
                      "devastating blow is coming"),
    "intent_summon": (32, "a curved bone war horn with an aged gold band "
                      "and a dark red cord, calling for allies"),
    "intent_heal": (32, "a round glass potion flask with crimson red healing "
                    "liquid, cork stopper, small bone white cross on the "
                    "glass"),
    # v1 (pergaminho com "?" no lacre) lia como PERGAMINHO, não "desconhecido":
    # o "?" de 3px some no tamanho de uso. A forma tem que SER o "?".
    "intent_unknown": (32, "one big bold question mark symbol carved from "
                       "bone white stone with dark cracks, filling the icon, "
                       "thick dark outline, mysterious"),
    # 24px: extras do box e pills
    "intent_pierce": (24, "a sharp steel arrowhead punching through a cracked "
                      "iron plate, armor-piercing"),
    "status_frail": (24, "a cracked tarnished steel breastplate split down "
                     "the middle, brittle armor"),
    # v1 saiu espada INTEIRA (lia como ataque). A forma tem que ser a QUEBRA.
    "status_weak_self": (24, "a broken sword in two separate pieces: the hilt "
                         "with a short jagged stub of blade on the left, the "
                         "snapped blade tip falling away on the right, a "
                         "clear empty gap between the two pieces, drooping "
                         "downward, weakened"),
    "status_vulnerable_self": (24, "a shattered round wooden shield broken "
                               "into pieces with a crimson crack, exposed"),
}


def cmd_gen(name, seed=None):
    size, desc = SPECS[name]
    card = name in CARD_SPECS
    args = {"description": desc if card else f"{desc}. {STYLE}",
            "width": size, "height": size, "no_background": True,
            "style_image_base64": N.b64(CARD_STYLE_REF if card else STYLE_BOARD)}
    if seed is not None:
        args["seed"] = int(seed)
    text = N.call("create_image_pro", args)
    jid = N.job_id_of(text)
    print(f"[gen] {name} job {jid}", flush=True)
    done = N.wait_job(jid, 1500) if jid else None
    if not done:
        print(text[:300])
        return
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.startswith("cand_"):
            os.remove(os.path.join(d, f))
    n = N.download_all(done, os.path.join(d, "cand_{}.png"))
    if size <= 42:
        unroll(d, n)   # só a folha 8x8 de canvas pequeno vem enrolada
    N.ledger_add(name, "icon_v2", None)
    contact(name, n)


# ---------------------------------------------------------------------------
# ÍCONES DE CARTA (64x64) — mesmo pipeline de candidatos. O slot da carta
# corta o ícone por "cover" (88x107 a partir de 64x64): só ~52px do MEIO
# aparecem. Composição LARGA = sujeito decepado nas bordas (os 3 coringas de
# combo v1: cartas e escudos cortados ao meio). Prompt pede o sujeito
# estreito, centrado, margem vazia dos lados.
CARD_STYLE = ("single centered subject in a NARROW vertical composition, "
              "everything fits inside the middle 40 pixels of the width, "
              "empty transparent margins on the left and right, dark fantasy "
              "grimoire card illustration pixel art, crisp dark 1px outline, "
              "earthy desaturated palette with aged gold, detailed shading, "
              "light from the upper left, hard-edged pixel clusters, no text, "
              "no background, matches the reference icon style")
CARD_SPECS = {
    "combo_volley": (64, "three slender steel throwing daggers falling point "
                     "down in a tight vertical cluster, one slightly above the "
                     "other two, aged gold crossguards, motion streaks above "
                     "them, a rain of blades"),
    "combo_wall": (64, "two tall kite shields locked edge to edge in a tight "
                   "shield wall, front one bronze with iron studs, the one "
                   "behind darker, both tall and narrow, a defensive wall"),
    "combo_pair": (64, "an ornate gilded hand mirror standing upright, oval "
                   "glass showing the reflection of a second identical "
                   "mirror inside it, twin reflection, mystical violet glint "
                   "on the glass"),
}
for _k, (_sz, _d) in CARD_SPECS.items():
    SPECS[_k] = (_sz, _d + ". " + CARD_STYLE)
CARD_STYLE_REF = os.path.join(ICONS, "joker_shield.png")


def unroll(d, n):
    """create_image_pro em canvas pequeno (<=42px, 64 candidatos) devolve a
    FOLHA 8x8 fatiada meia célula fora do lugar: em 32px cada candidato vinha
    enrolado (cabo da espada no canto de cima-direita); em 24px cada fatia
    trazia pedaço do vizinho. Conserto único pros dois: remonta a folha na
    ordem, rola a FOLHA meia célula nos dois eixos e refatia."""
    import numpy as np
    from PIL import Image
    paths = [os.path.join(d, f"cand_{i}.png") for i in range(n)]
    cells = [np.array(Image.open(p).convert("RGBA")) for p in paths]
    h, w = cells[0].shape[:2]
    cols = 8
    rows = (n + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.uint8)
    for i, c in enumerate(cells):
        sheet[(i // cols) * h:(i // cols + 1) * h,
              (i % cols) * w:(i % cols + 1) * w] = c
    sheet = np.roll(sheet, (h // 2, w // 2), axis=(0, 1))
    for i, p in enumerate(paths):
        Image.fromarray(sheet[(i // cols) * h:(i // cols + 1) * h,
                              (i % cols) * w:(i % cols + 1) * w]).save(p)


def contact(name, n):
    """Prancha: cada candidato em 4x (detalhe) + 1x (tamanho de uso) sobre a
    cor do box do intent."""
    from PIL import Image, ImageDraw
    d = os.path.join(OUT, name)
    ims = [Image.open(os.path.join(d, f"cand_{i}.png")).convert("RGBA")
           for i in range(n)]
    s = ims[0].width
    cols = 8
    cw, ch = s * 4 + s + 16, s * 4 + 14
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * cw, rows * ch), (74, 48, 34, 255))
    dr = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        x, y = (k % cols) * cw, (k // cols) * ch
        big = im.resize((s * 4, s * 4), Image.NEAREST)
        sh.paste(big, (x, y), big)
        sh.paste(im, (x + s * 4 + 6, y + 4), im)
        dr.text((x + 2, y + s * 4), str(k), fill=(255, 255, 0))
    p = os.path.join(d, "contact.png")
    sh.save(p)
    print(p)


def cmd_pick(name, n):
    from PIL import Image
    size, _ = SPECS[name]
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    if im.size != (size, size):
        raise SystemExit(f"{name}: candidato {im.size} != {size}")
    px = im.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    im.save(os.path.join(ICONS, name + ".png"))
    print(f"[pick] {name} <- cand_{n}  bbox={im.getbbox()}")


def cmd_board():
    """Prancha do set instalado: 4x + tamanho de uso, sobre o box do intent."""
    from PIL import Image, ImageDraw
    names = list(SPECS)
    cw, ch = 32 * 4 + 60, 32 * 4 + 24
    sh = Image.new("RGBA", (len(names) * cw // 2 + cw, ch * 2),
                   (74, 48, 34, 255))
    dr = ImageDraw.Draw(sh)
    for k, nm in enumerate(names):
        im = Image.open(os.path.join(ICONS, nm + ".png")).convert("RGBA")
        x, y = (k % 7) * cw, (k // 7) * ch
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        sh.paste(big, (x + 4, y + 4), big)
        sh.paste(im, (x + 32 * 4 + 14, y + 10), im)
        dr.text((x + 4, y + 32 * 4 + 8), nm, fill=(255, 235, 180))
    p = os.path.join(OUT, "intent_set_v2.png")
    sh.save(p)
    print(p)


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        cmd_gen(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], a[1])
    elif c == "board":
        cmd_board()
    else:
        print(__doc__)
