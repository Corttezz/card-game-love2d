"""Converte a pixel art de dist/img para WebP sem perda (mesmos pixels, arquivo menor).
Mantém PNG em og/ e brand/ (compartilhamento e ícones). Usa cache por hash do PNG em tools/out/webp-cache.
Imprime a lista de convertidos (relativos a dist).
uso: python -X utf8 tools/webp.py dist
"""
import hashlib
import os
import shutil
import sys

from PIL import Image

D = sys.argv[1]
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "webp-cache")
os.makedirs(CACHE, exist_ok=True)
done = []
for root, _, files in os.walk(os.path.join(D, "img")):
    rel = os.path.relpath(root, D).replace("\\", "/")
    if rel.startswith("img/og") or rel.startswith("img/brand") or rel.startswith("img/v3b/raw"):
        continue
    for f in files:
        if not f.endswith(".png"):
            continue
        p = os.path.join(root, f)
        h = hashlib.sha1(open(p, "rb").read()).hexdigest()
        c = os.path.join(CACHE, h + ".webp")
        skip = os.path.join(CACHE, h + ".skip")
        if os.path.exists(skip):
            continue
        if not os.path.exists(c):
            im = Image.open(p)
            im = im.convert("RGBA") if im.mode in ("P", "LA", "RGBA") or "transparency" in im.info else im.convert("RGB")
            im.save(c, lossless=True, quality=100, method=4)
            if os.path.getsize(c) >= os.path.getsize(p):
                os.remove(c)
                open(skip, "w").close()
                continue
        shutil.copyfile(c, p[:-4] + ".webp")
        done.append(f"/{rel}/{f}")
print("\n".join(done))
