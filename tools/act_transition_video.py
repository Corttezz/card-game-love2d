#!/usr/bin/env python3
"""Monta o mp4 de uma captura do tools/record_act_transition.lua e diz o que achou.

uso: python tools/act_transition_video.py <pasta da captura no save> <saida.mp4>
Áudio: cada quadro traz as fontes tocando (arquivo, posição, volume, pitch); o script recorta 1/30 s
de cada arquivo na posição registrada e mistura, com rampa de volume entre quadros (filtro passa-baixa
do jogo não é reproduzido). Relatório: quadros pretos, cortes secos (diferença grande entre quadros),
linha do tempo do som (música e SFX) e mudanças de estado.
"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100


def decode(path, cache={}):
    if path in cache:
        return cache[path]
    full = os.path.join(ROOT, path)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", full, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    a = np.frombuffer(raw, np.float32).reshape(-1, 2)
    cache[path] = a
    return a


def mix(ev):
    fps = ev["fps"]
    n = len(ev["audio"])
    spf = SR // fps
    out = np.zeros((n * spf, 2), np.float32)
    prev = []
    for i, srcs in enumerate(ev["audio"]):
        cur = []
        for path, pos, vol, pitch, filt in srcs:
            a = decode(path)
            g0 = vol
            for j, (pp, ppos, pvol) in enumerate(prev):
                if pp == path and abs((ppos + pitch / fps) - pos) < 0.08:
                    g0 = pvol
                    prev.pop(j)
                    break
            cur.append((path, pos, vol))
            s0 = int(pos * SR)
            need = int(round(spf * pitch)) + 1
            idx = np.arange(s0, s0 + need) % max(1, len(a))
            chunk = a[idx]
            if abs(pitch - 1) > 1e-3:
                x = np.linspace(0, need - 1, spf)
                chunk = np.stack([np.interp(x, np.arange(need), chunk[:, c]) for c in range(2)], 1)
            else:
                chunk = chunk[:spf]
            ramp = np.linspace(g0, vol, spf, dtype=np.float32)[:, None]
            out[i * spf:(i + 1) * spf] += chunk * ramp
        prev = cur
    return out


def analyse(frames_dir, ev):
    n = ev["frames"]
    lum, diff = [], []
    last = None
    for i in range(n):
        im = np.asarray(Image.open(os.path.join(frames_dir, f"{i:05d}.png")).convert("L").resize((160, 90)),
                        np.float32)
        lum.append(im.mean())
        if last is not None:
            diff.append(np.abs(im - last).mean())
        else:
            diff.append(0.0)
        last = im
    return np.array(lum), np.array(diff)


def report(ev, lum, diff):
    fps = ev["fps"]
    lines = []
    st = ev["states"]
    for i in range(1, len(st)):
        if st[i] != st[i - 1]:
            lines.append(f"{i / fps:6.2f}s estado {st[i - 1]} -> {st[i]}")
    black = np.where(lum < 3.0)[0]
    if len(black):
        runs, s = [], black[0]
        for a, b in zip(black, black[1:]):
            if b != a + 1:
                runs.append((s, a)); s = b
        runs.append((s, black[-1]))
        for a, b in runs:
            lines.append(f"{a / fps:6.2f}s preto ate {b / fps:.2f}s ({b - a + 1} quadros)")
    for i in np.where(diff > 28)[0]:
        lines.append(f"{i / fps:6.2f}s corte seco (dif {diff[i]:.0f}, lum {lum[i - 1]:.0f}->{lum[i]:.0f})")
    seen = {}
    for i, srcs in enumerate(ev["audio"]):
        names = set()
        for path, pos, vol, pitch, filt in srcs:
            name = os.path.basename(path)
            names.add(name)
            if name not in seen:
                lines.append(f"{i / fps:6.2f}s + {name} (vol {vol:.2f}, pos {pos:.2f}{', filtro' if filt else ''})")
            seen[name] = i
        for name in [k for k, v in seen.items() if v == i - 1 and k not in names]:
            lines.append(f"{i / fps:6.2f}s - {name}")
            del seen[name]
    lines.sort(key=lambda s: float(s.split("s", 1)[0]))
    return lines


def main():
    d, out = sys.argv[1], sys.argv[2]
    ev = json.load(open(os.path.join(d, "audio.json"), encoding="utf-8"))
    fps = ev["fps"]
    audio = mix(ev)
    peak = float(np.abs(audio).max()) if len(audio) else 0
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "a.f32")
        np.clip(audio, -1, 1).astype(np.float32).tofile(wav)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", os.path.join(d, "frames", "%05d.png"),
                        "-f", "f32le", "-ac", "2", "-ar", str(SR), "-i", wav, "-map", "0:v", "-map", "1:a",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", out], check=True)
    lum, diff = analyse(os.path.join(d, "frames"), ev)
    lines = report(ev, lum, diff)
    txt = os.path.splitext(out)[0] + ".txt"
    with open(txt, "w", encoding="utf-8") as f:
        f.write(f"notas: {json.dumps(ev.get('notes', {}), ensure_ascii=False)}\n")
        f.write(f"duracao {ev['frames'] / fps:.2f}s, pico do audio {peak:.2f}\n")
        f.write("\n".join(lines) + "\n")
    print("ok", out, f"{ev['frames'] / fps:.1f}s pico {peak:.2f}")


if __name__ == "__main__":
    main()
