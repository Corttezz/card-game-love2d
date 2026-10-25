import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_primeiro_plano as P

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P.OUT = os.path.join(ROOT, "tools/preview_out/chao_itens/pixellab")
P.RAW = os.path.join(P.OUT, "raw")
P.CAND = os.path.join(P.OUT, "cand")
P.JOBS = os.path.join(P.OUT, "jobs.json")

P.SPECS = {
    "abyss_thorns": ("abyss_bush_0.png", 96, 48, "right",
        "a low wide clump of charred dead thorny scrub, thin twisted dark plum-brown burnt twigs "
        "close to the ground, only two or three tiny dull red ember specks on the twig tips, "
        "matte, no flames, no glow, ash-dark volcanic wasteland at dusk"),
    "abyss_cinders": ("abyss_bush_0.png", 96, 40, "right",
        "a few fallen charred broken branches and twigs lying flat on the ground, dark plum-brown "
        "burnt wood with cracked bark, one or two tiny dull red ember pixels in the cracks, matte, "
        "no flames, no glow, ash-dark volcanic wasteland"),
    "abyss_stones": ("abyss_ruin_0.png", 80, 44, "right",
        "a small cluster of three dark basalt stones of different sizes half sunk in the dirt, "
        "dark plum-grey rock the same colour as the ruin stones, rough faceted faces, no lava, "
        "no glow, no cracks of light, volcanic wasteland"),
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        P.queue(sys.argv[2:])
    elif cmd == "poll":
        P.poll()
    elif cmd == "process":
        P.process()
    elif cmd == "sheet":
        P.sheet(sys.argv[2])
    elif cmd == "install":
        P.install(sys.argv[2:])
