#!/usr/bin/env python3
"""
tools/pixellab_intent_icons.py — ícones de INTENT do inimigo e status novos
(Out/2026, kit de golpes por criatura): debuff, carga, invocação, cura, buff,
multi-golpe, perfurante e Frágil no jogador.

Mesmo contrato da leva status_* (StatusPill): 64x64 transparente, UM objeto
gordo com contorno preto, cor própria por categoria. Critério de aprovação é a
legibilidade no TAMANHO DE USO (~36-48px no HUD), não ampliado.

  python tools/pixellab_intent_icons.py gen <nome> [seed]   # 16 candidatos
  python tools/pixellab_intent_icons.py pick <nome> <N>     # instala
Candidatos em tools/preview_out/intent_icons/<nome>/.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N  # call/b64/wait_job/download_all

ROOT = N.ROOT
ICONS = os.path.join(ROOT, "assets/sprites/icons")
OUT = os.path.join(ROOT, "tools/preview_out/intent_icons")

STYLE = ("single bold game UI icon, one chunky object centered filling the "
         "64x64 canvas, thick crisp 1px black outline, strong saturated "
         "color with dark shading and one bright highlight, readable at "
         "36 pixels, hand-placed pixel art with hard edges, NO text, NO "
         "background, NO frame, NO smooth vector gradients")

# nome → (ícone de estilo existente, descrição)
SPECS = {
    "intent_debuff": ("status_weak",
        "a cursed purple skull wrapped in a dark violet swirling hex mist, "
        "small downward spiral beneath it, sickly purple and black"),
    "intent_charge": ("intent_attack",
        "a raised heavy iron war hammer glowing orange-hot, with bright "
        "orange energy rings gathering around its head, charging up"),
    "intent_summon": ("intent_attack",
        "a curved bone war horn with a dark red cord, bright pale-blue "
        "sound waves bursting from its mouth, calling for allies"),
    "intent_heal": ("status_regen",
        "a red heart with a bright green plus sign over it, small green "
        "sparkles, healing"),
    "intent_buff": ("status_strength",
        "three bold orange-red upward arrows stacked like chevrons, rising "
        "power, empowerment"),
    "intent_multi": ("intent_attack",
        "three parallel diagonal red claw slash marks, multiple quick "
        "strikes, sharp white edges"),
    "intent_pierce": ("status_vulnerable",
        "a sharp steel spear tip piercing straight through a dented iron "
        "armor plate, the plate punched open, armor-piercing"),
    "status_frail": ("status_vulnerable",
        "a dented rusty brown iron chestplate cracking and crumbling apart, "
        "pieces flaking off, weakened brittle armor"),
}


def cmd_gen(name, seed=None):
    style_id, desc = SPECS[name]
    args = {"description": f"{desc}. {STYLE}", "width": 64, "height": 64,
            "no_background": True,
            "style_image_base64": N.b64(os.path.join(ICONS, style_id + ".png"))}
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
    N.ledger_add(name, "icon", None)
    contact(name, n)


def contact(name, n):
    """Prancha em DOIS tamanhos: 3x (detalhe) e 36px (tamanho de uso)."""
    from PIL import Image
    d = os.path.join(OUT, name)
    ims = [Image.open(os.path.join(d, f"cand_{i}.png")).convert("RGBA")
           for i in range(n)]
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    cw = 64 * 3 + 50
    sh = Image.new("RGBA", (cols * cw, rows * 64 * 3), (40, 36, 32, 255))
    for k, im in enumerate(ims):
        x, y = (k % cols) * cw, (k // cols) * 64 * 3
        big = im.resize((192, 192), Image.NEAREST)
        sh.paste(big, (x, y), big)
        small = im.resize((36, 36), Image.LANCZOS)
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
    im.save(os.path.join(ICONS, name + ".png"))
    print(f"[pick] {name} <- cand_{n}")


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        cmd_gen(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], a[1])
    else:
        print(__doc__)
