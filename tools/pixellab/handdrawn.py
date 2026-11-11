"""Hand-drawn tiny weather particles (too small for PixelLab to draw crisply).

  python handdrawn.py   -> writes art/gen/fx/{ember,spore_0,spore_1,raindrop}.png
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "gen", "fx")

PAL = {
    # ember: dark red rim, orange, amber, hot white-yellow core
    "r": (122, 34, 18), "O": (232, 104, 32), "Y": (255, 190, 60), "W": (255, 244, 186),
    # spore: dark moss rim, toxic green, light green, pale core
    "g": (38, 92, 34), "G": (96, 190, 58), "L": (170, 238, 96), "w": (234, 255, 196),
    # rain: dim blue, mid blue, pale highlight
    "a": (86, 116, 160), "b": (150, 190, 230), "c": (214, 234, 255),
}

ART = {
    "ember": ["..r..",
              ".rOr.",
              "rOYOr",
              "rYWOr",
              ".rOr.",
              "..r.."],
    "spore_0": [".gGg.",
                "gGLGg",
                "GLwLG",
                "gGLGg",
                ".gGg."],
    "spore_1": [".Gg.",
                "GwLg",
                "gLGg",
                ".gg."],
    "raindrop": [".a",
                 ".a",
                 "ab",
                 "ab",
                 "ab",
                 "bc",
                 "bc",
                 "bc"],
}


def draw(rows):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), PAL[ch] + (255,))
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, rows in ART.items():
        draw(rows).save(os.path.join(OUT, name + ".png"))
        print(name, len(rows[0]), "x", len(rows))
