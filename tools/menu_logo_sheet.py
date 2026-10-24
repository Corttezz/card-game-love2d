import glob
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "preview_out", "menu_logo")
TRAILER = r"E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_v7_4k.mp4"
TRAILER_T0 = 51.25
FPS = 20


def frames(size):
    return sorted(glob.glob(os.path.join(OUT, "sting_" + size, "f_*.png")))


def sheet(size, times):
    fs = frames(size)
    tw, th = 480, 270
    cols = 4
    rows = (len(times) + cols - 1) // cols
    im = Image.new("RGB", (cols * (tw + 8) + 8, rows * (th + 22) + 8), (24, 18, 20))
    d = ImageDraw.Draw(im)
    for i, t in enumerate(times):
        n = min(len(fs) - 1, int(round(t * FPS)))
        with Image.open(fs[n]) as src:
            f = src.convert("RGB").resize((tw, th), Image.NEAREST)
        x = 8 + (i % cols) * (tw + 8)
        y = 8 + (i // cols) * (th + 22)
        im.paste(f, (x, y))
        d.text((x, y + th + 4), "t=%.2fs" % t, fill=(240, 220, 170))
    p = os.path.join(OUT, "entrada_folha_%s.png" % size)
    im.save(p)
    print("[ok] " + p)


def gif(size, width=640):
    src = os.path.join(OUT, "sting_" + size, "f_%03d.png")
    p = os.path.join(OUT, "entrada_%s.gif" % size)
    vf = ("scale=%d:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[pl];[b][pl]paletteuse=dither=none" % width)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", src, "-vf", vf, "-loop", "0", p], check=True)
    print("[ok] " + p)


def compare(size, times):
    fs = frames(size)
    tw, th = 640, 360
    im = Image.new("RGB", (tw * 2 + 24, len(times) * (th + 22) + 8), (24, 18, 20))
    d = ImageDraw.Draw(im)
    tmp = os.path.join(OUT, "_trailer_tmp.png")
    for i, t in enumerate(times):
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % (TRAILER_T0 + t), "-i", TRAILER,
                        "-frames:v", "1", "-vf", "scale=%d:%d" % (tw, th), tmp], check=True)
        a = Image.open(tmp).convert("RGB")
        n = min(len(fs) - 1, int(round(t * FPS)))
        b = Image.open(fs[n]).convert("RGB").resize((tw, th), Image.NEAREST)
        y = 8 + i * (th + 22)
        im.paste(a, (8, y))
        im.paste(b, (16 + tw, y))
        d.text((8, y + th + 4), "trailer t=%.2fs" % t, fill=(240, 220, 170))
        d.text((16 + tw, y + th + 4), "menu t=%.2fs" % t, fill=(240, 220, 170))
    os.remove(tmp)
    p = os.path.join(OUT, "comparacao_trailer_%s.png" % size)
    im.save(p)
    print("[ok] " + p)


if __name__ == "__main__":
    size = sys.argv[1] if len(sys.argv) > 1 else "1920x1080"
    sheet(size, [0.3, 0.9, 1.4, 1.8, 2.3, 2.5, 2.64, 2.75, 2.95, 3.2, 3.35, 3.6, 3.9, 4.3, 4.5, 6.0])
    gif(size)
    compare(size, [0.9, 1.8, 2.5, 2.7, 3.3, 4.4, 6.0])
