import sys, subprocess, os
from PIL import Image, ImageDraw

video, out, cuts = sys.argv[1], sys.argv[2], [float(c) for c in sys.argv[3].split()]
tmp = os.path.join(os.path.dirname(out), "hp_tmp.png")
rows = []
for c in cuts:
    pair = []
    for d in (-0.034, 0.017):
        t = round(c + d, 3)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", video, "-frames:v", "1", tmp])
        im = Image.open(tmp).convert("RGB")
        hero = im.crop((100, 900, 380, 1000))
        boss = im.crop((660, 255, 1240, 370))
        tile = Image.new("RGB", (880, 130), (0, 0, 0))
        tile.paste(hero, (0, 15)); tile.paste(boss, (290, 8))
        ImageDraw.Draw(tile).text((4, 2), "%.3f" % t, fill=(255, 255, 0))
        pair.append(tile)
    rows.append(pair)
W = Image.new("RGB", (1780, 130 * len(rows)), (40, 40, 40))
for i, (a, b) in enumerate(rows):
    W.paste(a, (0, i * 130)); W.paste(b, (900, i * 130))
W.save(out)
print(out)
