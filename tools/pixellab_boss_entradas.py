#!/usr/bin/env python3
"""
tools/pixellab_boss_entradas.py: pecas das entradas novas dos chefes dos
atos 2 (tower_lich) e 3 (abyss_tyrant), #538. Mesmo molde de
pixellab_boss_mechanics.py (create_image_pro com o idle0 do chefe como
estilo); as poses novas ficam em pixellab_boss_cine.py (CLIPS).

  python tools/pixellab_boss_entradas.py gen <nome[,nome]> [seed]
  python tools/pixellab_boss_entradas.py pick <nome> <N>
Candidatos em tools/preview_out/boss_mech_art/<nome>/contact.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_boss_mechanics as M

E = M.ENEMIES
LICH, TYR = M.idle0("tower_lich"), M.idle0("abyss_tyrant")
S = M.OBJ_STYLE

SPECS = {
    "ice_tomb": (96, 160, LICH,
        "a tall jagged crystal of clear pale cyan ice shaped like an upright "
        "coffin, sharp crystal spikes on top, deep blue shading and white "
        "frost on the edges, a dark violet silhouette of a skeletal robed "
        "figure frozen inside, front view. " + S),
    "ice_chunk": (32, 32, LICH,
        "a single broken jagged chunk of pale cyan ice debris with a white "
        "highlight edge and deep blue shadow. " + S),
    "sigil": (128, 64, LICH,
        "a magic summoning circle drawn on a stone floor seen in strong "
        "perspective as a flat wide ellipse, double ring of glowing ice-blue "
        "arcane runes with a violet five-pointed star inside, transparent "
        "outside the circle. " + S),
    "wisp": (32, 32, LICH,
        "a small spectral ghost wisp: pale cyan glowing head with a faint "
        "hollow skull face and a long wavy tail trailing downward, violet "
        "edge. " + S),
    "chain_big": (32, 64, TYR,
        "a vertical segment of a huge heavy black iron chain: exactly two "
        "interlocked thick oval links stacked top to bottom, the top link "
        "from the front and the bottom link edge-on, dark iron with glowing "
        "hot orange glints in the cracks. " + S),
    "shackle": (48, 48, TYR,
        "a heavy iron wall anchor: a square riveted iron plate with a thick "
        "iron ring hanging from it and a broken chain end, glowing molten "
        "orange cracks, front view. " + S),
    "lava_splash": (64, 64, TYR,
        "an eruption splash of molten lava bursting straight up from the "
        "bottom, bright yellow core, orange and dark red droplets flying "
        "outward, black cooling crust on the edges. " + S),
    "rock_chunk": (24, 24, TYR,
        "a jagged chunk of dark volcanic basalt rock with one glowing orange "
        "crack. " + S),
    "crater": (128, 48, TYR,
        "a cracked impact crater in a black volcanic stone floor seen in "
        "strong perspective as a flat wide ellipse, glowing molten orange "
        "lava cracks radiating outward from the center, transparent outside. "
        + S),
}

DEST = {k: os.path.join(E, ("tower_lich" if v[2] == LICH else
                            "abyss_tyrant"), "entrance", k + ".png")
        for k, v in SPECS.items()}

M.SPECS.update(SPECS)
M.DEST.update(DEST)

if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        for nm in a[0].split(","):
            M.cmd_gen(nm, a[1] if len(a) > 1 else None)
    elif c == "pick":
        M.cmd_pick(a[0], int(a[1]))
    else:
        print(__doc__)
