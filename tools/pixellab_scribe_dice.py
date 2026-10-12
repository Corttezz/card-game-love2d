#!/usr/bin/env python3
"""
tools/pixellab_scribe_dice.py — arte do mini-jogo "Dados do Escriba"
(Out/2026, aposta opcional da loja).

Mesmo contrato das relíquias da loja (assets/sprites/vouchers/): 64x64
transparente, UM objeto com contorno escuro, paleta quente de couro/latão,
estilo puxado de `vouchers/interest_cap.png` (o baú de moedas — vizinho de
prateleira do copo de dados).

  python tools/pixellab_scribe_dice.py gen <nome> [seed]   # candidatos
  python tools/pixellab_scribe_dice.py pick <nome> <N>     # instala
  python tools/pixellab_scribe_dice.py faces               # 6 faces do dado

As FACES do dado não vêm da IA de propósito: o número de pips TEM que estar
certo (é a informação que o jogador lê pra saber se ganhou), e um gerador
erra contagem. São desenhadas aqui pixel a pixel, na paleta do grimório.
Candidatos em tools/preview_out/scribe_dice/<nome>/.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N  # call/b64/wait_job/download_all

ROOT = N.ROOT
DEST = os.path.join(ROOT, "assets/sprites/minigame")
OUT = os.path.join(ROOT, "tools/preview_out/scribe_dice")
STYLE_REF = os.path.join(ROOT, "assets/sprites/vouchers/interest_cap.png")

STYLE = ("single game item, one chunky object centered filling the 64x64 "
         "canvas, crisp dark 1px outline, warm medieval grimoire palette "
         "(aged leather browns, tarnished brass, parchment), dark shading and "
         "one bright highlight, hand-placed pixel art with hard edges, NO "
         "text, NO background, NO frame, NO smooth vector gradients")

SPECS = {
    "dice_cup": ("a worn brown leather dice cup with a tarnished brass rim "
                 "and brass rivets, tipped slightly, two small ivory bone "
                 "dice with red pips spilling out in front of it"),
}


def cmd_gen(name, seed=None):
    args = {"description": f"{SPECS[name]}. {STYLE}", "width": 64, "height": 64,
            "no_background": True, "style_image_base64": N.b64(STYLE_REF)}
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
    n = N.download_all(done, os.path.join(d, "cand_{}.png"))
    contact(name, n)


def contact(name, n):
    from PIL import Image
    d = os.path.join(OUT, name)
    ims = [Image.open(os.path.join(d, f"cand_{i}.png")).convert("RGBA")
           for i in range(n)]
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    cw = 64 * 3 + 70
    sh = Image.new("RGBA", (cols * cw, rows * 64 * 3), (40, 36, 32, 255))
    for k, im in enumerate(ims):
        x, y = (k % cols) * cw, (k // cols) * 64 * 3
        big = im.resize((192, 192), Image.NEAREST)
        sh.paste(big, (x, y), big)
        small = im.resize((64, 64), Image.NEAREST)
        sh.paste(small, (x + 196, y + 8), small)
    p = os.path.join(d, "contact.png")
    sh.save(p)
    print(p)


def cmd_pick(name, n):
    from PIL import Image
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    os.makedirs(DEST, exist_ok=True)
    im.save(os.path.join(DEST, name + ".png"))
    print(f"[pick] {name} <- cand_{n}")


# ---- faces do dado: osso envelhecido, pips cor de sangue -----------------
# Paleta = Palette.lua (seção Grimoire): INK, PARCHMENT_*, BLOOD.
INK = (28, 20, 16, 255)
BONE_HI = (246, 232, 200, 255)
BONE = (226, 204, 160, 255)
BONE_SH = (184, 156, 112, 255)
BONE_DK = (138, 108, 74, 255)
PIP = (140, 26, 22, 255)
PIP_HI = (196, 58, 44, 255)

PIPS = {  # posições na grade 3x3 (col, lin)
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
}


def cmd_faces():
    """Dado 22x22: contorno tinta, cantos chanfrados, face de osso com luz
    no alto-esquerda e sombra embaixo-direita, pips 4x4 arredondados."""
    from PIL import Image
    S = 22
    os.makedirs(DEST, exist_ok=True)
    sheet = Image.new("RGBA", (S * 6, S), (0, 0, 0, 0))
    for n in range(1, 7):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        px = im.load()
        for y in range(S):
            for x in range(S):
                # chanfro de 2px nos cantos
                cx = min(x, S - 1 - x)
                cy = min(y, S - 1 - y)
                if cx + cy < 2:
                    continue
                edge = cx == 0 or cy == 0 or cx + cy == 2
                if edge:
                    px[x, y] = INK
                elif x + y <= 5:
                    px[x, y] = BONE_HI
                elif x >= S - 3 or y >= S - 3:
                    px[x, y] = BONE_DK if (x >= S - 2 or y >= S - 2) else BONE_SH
                else:
                    px[x, y] = BONE
        for (c, l) in PIPS[n]:
            ox = 4 + c * 5
            oy = 4 + l * 5
            for dy in range(4):
                for dx in range(4):
                    if (dx, dy) in ((0, 0), (3, 0), (0, 3), (3, 3)):
                        continue  # cantos cortados = pip redondo
                    px[ox + dx, oy + dy] = PIP
            px[ox + 1, oy + 1] = PIP_HI
        im.save(os.path.join(DEST, f"die_{n}.png"))
        sheet.paste(im, ((n - 1) * S, 0))
    os.makedirs(OUT, exist_ok=True)
    sheet.resize((S * 6 * 6, S * 6), Image.NEAREST).save(
        os.path.join(OUT, "faces_contact.png"))
    print("[faces] 6 faces em", DEST)


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        cmd_gen(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], int(a[1]))
    elif c == "faces":
        cmd_faces()
    else:
        print(__doc__)
