#!/usr/bin/env python3
# tools/boss_cinematic_sheet.py
# Monta a PRANCHA (contact sheet) e o GIF da cinemática do chefe a partir dos
# quadros gravados por `love . shot_boss_cinematic` (boss_cine_<fase>_NNN.png
# no save dir).
#
#   python tools/boss_cinematic_sheet.py <save_dir> [out_dir]
#
# Saída (default tools/preview_out/boss_cinematic/):
#   boss_cine_intro_sheet.png   12 momentos, 4 colunas
#   boss_cine_death_sheet.png    6 momentos, 3 colunas
#   boss_cine_intro.gif / boss_cine_death.gif   (640 px de largura, 15 fps)

import os
import re
import sys

from PIL import Image, ImageDraw


def frames_of(save_dir, phase):
    rx = re.compile(r"^boss_cine_%s_(\d+)\.png$" % phase)
    out = []
    for f in os.listdir(save_dir):
        m = rx.match(f)
        if m:
            out.append((int(m.group(1)), os.path.join(save_dir, f)))
    out.sort()
    return [p for _, p in out]


def timeline_of(save_dir, phase):
    path = os.path.join(save_dir, "boss_cine_%s_timeline.txt" % phase)
    times = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            m = re.match(r"^(\d+) t=([\d.]+) step=(\S+)", line)
            if m:
                times[int(m.group(1))] = (float(m.group(2)), m.group(3))
    return times


def pick(frames, n):
    if len(frames) <= n:
        return list(range(len(frames)))
    return [round(i * (len(frames) - 1) / (n - 1)) for i in range(n)]


def sheet(frames, times, n, cols, out, cell_w=480):
    idx = pick(frames, n)
    if not idx:
        print("[sheet] sem quadros para", out)
        return
    first = Image.open(frames[0])
    ratio = first.height / first.width
    cell_h = int(cell_w * ratio)
    rows = (len(idx) + cols - 1) // cols
    label_h = 22
    sheet_img = Image.new("RGB", (cols * cell_w, rows * (cell_h + label_h)), (12, 10, 10))
    draw = ImageDraw.Draw(sheet_img)
    for k, i in enumerate(idx):
        im = Image.open(frames[i]).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        x = (k % cols) * cell_w
        y = (k // cols) * (cell_h + label_h)
        sheet_img.paste(im, (x, y + label_h))
        t, step = times.get(i, (None, "?"))
        label = "#%02d  t=%.2fs  %s" % (k + 1, t, step) if t is not None else "#%02d" % (k + 1)
        draw.text((x + 6, y + 4), label, fill=(230, 210, 170))
    sheet_img.save(out)
    print("[sheet]", out, sheet_img.size)


def gif(frames, out, width=640, fps=15):
    if not frames:
        return
    ims = []
    for p in frames:
        im = Image.open(p).convert("RGB")
        h = int(im.height * width / im.width)
        ims.append(im.resize((width, h), Image.LANCZOS).quantize(colors=128, method=Image.MEDIANCUT))
    ims[0].save(out, save_all=True, append_images=ims[1:], duration=int(1000 / fps), loop=0, optimize=False)
    print("[gif]", out, len(ims), "quadros")


def main():
    if len(sys.argv) < 2:
        print("uso: python tools/boss_cinematic_sheet.py <save_dir> [out_dir]")
        return 1
    save_dir = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join("tools", "preview_out", "boss_cinematic")
    os.makedirs(out_dir, exist_ok=True)
    # sufixo opcional pros arquivos de saída (um chefe por pasta/prefixo):
    #   python tools/boss_cinematic_sheet.py <save_dir> <out_dir> <tag>
    tag = ("_" + sys.argv[3]) if len(sys.argv) > 3 else ""
    # arrival = porta → entrada → distribuição das cartas (shot_boss_cinematic arrival)
    # phases = luta por fases (shot_boss_cinematic phases): 6 instantes
    for phase, n, cols in (("intro", 12, 4), ("death", 6, 3), ("arrival", 16, 4), ("phases", 6, 3)):
        frames = frames_of(save_dir, phase)
        if not frames:
            print("[sheet] fase sem quadros:", phase)
            continue
        times = timeline_of(save_dir, phase)
        sheet(frames, times, n, cols, os.path.join(out_dir, "boss_cine_%s%s_sheet.png" % (phase, tag)))
        gif(frames, os.path.join(out_dir, "boss_cine_%s%s.gif" % (phase, tag)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
