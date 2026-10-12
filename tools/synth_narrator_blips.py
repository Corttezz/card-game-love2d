#!/usr/bin/env python3
"""
tools/synth_narrator_blips.py — a "voz" do corvo narrador (Out/2026).

Blips curtos por caractere (estilo Undertale/Balatro), SINTETIZADOS aqui —
zero dependência de serviço externo e zero pendência de licença (os SFX do
ElevenLabs no plano free não permitem uso comercial). Cada blip é um "toc"
de corvo: dente-de-serra com queda de pitch (o "cr" do croc), um formante
nasal por cima e um tiquinho de ruído no ataque (o bico batendo).

  python tools/synth_narrator_blips.py   → audio/sfx/narrator/blip_1..6.wav

Seis variações de pitch/timbre: o Tutorial sorteia entre elas, sem repetir a
mesma duas vezes seguidas.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "sfx", "narrator")
SR = 44100

# (frequência base Hz, queda de pitch, duração s, formante Hz, ruído)
VARIANTS = [
    (310, 0.22, 0.050, 1250, 0.10),
    (345, 0.18, 0.046, 1400, 0.08),
    (285, 0.26, 0.055, 1150, 0.12),
    (380, 0.15, 0.042, 1550, 0.07),
    (330, 0.24, 0.052, 1300, 0.11),
    (360, 0.20, 0.048, 1480, 0.09),
]


def synth(f0, drop, dur, formant, noise, seed):
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = []
    phase = 0.0
    lp = 0.0
    bp1 = bp2 = 0.0
    # ressonador de 2 polos no formante (dá o "a" nasal do croc)
    r = 0.93
    w = 2 * math.pi * formant / SR
    a1, a2 = -2 * r * math.cos(w), r * r
    for i in range(n):
        t = i / SR
        prog = i / n
        f = f0 * (1.0 - drop * prog)
        phase = (phase + f / SR) % 1.0
        saw = 2.0 * phase - 1.0
        # ataque de 2ms, decaimento exponencial
        env = min(1.0, t / 0.002) * math.exp(-t / (dur * 0.38))
        nz = (rnd.random() * 2 - 1) * noise * math.exp(-t / 0.006)
        x = saw * 0.55 + nz
        # passa-baixa leve (tira o chiado do serrote)
        lp += 0.35 * (x - lp)
        # formante
        y = lp - a1 * bp1 - a2 * bp2
        bp2, bp1 = bp1, y
        s = (lp * 0.6 + y * 0.09) * env
        out.append(s)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * 0.8 for s in out]


def write(path, samples):
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767))
                                for s in samples))


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (f0, drop, dur, formant, noise) in enumerate(VARIANTS, 1):
        p = os.path.join(OUT, f"blip_{i}.wav")
        write(p, synth(f0, drop, dur, formant, noise, seed=i))
        print(p)


if __name__ == "__main__":
    main()
