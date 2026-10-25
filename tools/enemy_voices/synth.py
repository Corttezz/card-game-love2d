import numpy as np
from scipy import signal
import dsp as D

SR = D.SR


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype='band', output='sos')
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f / (SR / 2), output='sos'), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f / (SR / 2), btype='high', output='sos'), x)


def expdec(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def click(rng, dur=0.03, lo=1500, hi=6000, tau=0.006):
    n = int(dur * SR)
    return bp(rng.standard_normal(n), lo, hi) * expdec(n, tau)


def ring(freqs, dur, tau, rng, amps=None):
    t = t_(dur)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        a = 1.0 if amps is None else amps[i]
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau * (1 - 0.1 * i)))
    return out


def place(dur, items):
    out = np.zeros(int(dur * SR) + 1)
    for off, sig in items:
        o = int(off * SR)
        m = min(len(sig), len(out) - o)
        if m > 0:
            out[o:o + m] += sig[:m]
    return out


def bone_clatter(rng, dur=0.35, n=7, lowres=False):
    items, t = [], 0.0
    for i in range(n):
        f0 = rng.uniform(900, 2600) * (0.6 if lowres else 1)
        c = click(rng, 0.05, 1200, 7000, 0.004) + 0.6 * ring([f0, f0 * 2.3], 0.05, 0.012, rng)[:int(0.05 * SR)]
        items.append((t, c * rng.uniform(0.5, 1.0) * (1 - 0.06 * i)))
        t += rng.uniform(0.012, 0.045)
    return place(dur, items)


def wet_splat(rng, dur=0.35, f_hi=2500):
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    e = expdec(n, dur * 0.18)
    cut = np.linspace(f_hi, 250, n)
    y = np.zeros(n)
    blocks = 16
    for b in range(blocks):
        a, z = b * n // blocks, (b + 1) * n // blocks
        y[a:z] = lp(noise, cut[(a + z) // 2])[a:z]
    blip = np.zeros(n)
    for k in range(3):
        o = int(rng.uniform(0.01, dur * 0.5) * SR)
        m = int(0.06 * SR)
        tt = np.arange(m) / SR
        f = np.linspace(rng.uniform(250, 420), rng.uniform(90, 150), m)
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.02)
        blip[o:o + m] += s[:max(0, min(m, n - o))]
    return y * e + 0.5 * blip


def stone_crack(rng, dur=0.4, bright=1.0):
    n = int(dur * SR)
    out = np.zeros(n)
    out[:int(0.03 * SR)] += click(rng, 0.03, 300, 9000 * bright, 0.005)
    for k in range(int(10 * bright) + 4):
        o = int(rng.exponential(0.06) * SR)
        if o < n - 2000:
            c = click(rng, 0.02, 2000, 9000, 0.002) * rng.uniform(0.2, 0.7)
            out[o:o + len(c)] += c[:n - o]
    tt = np.arange(n) / SR
    out += 0.9 * np.sin(2 * np.pi * 55 * tt) * np.exp(-tt / 0.08)
    out += 0.4 * lp(rng.standard_normal(n), 400) * np.exp(-tt / 0.1)
    return out


def metal_clank(rng, dur=0.45, base=None, hollow=False):
    base = base or rng.uniform(380, 620)
    ratios = [1, 2.76, 5.40, 8.93]
    c = click(rng, 0.02, 1000, 9000, 0.003)
    r = ring([base * k for k in ratios], dur, 0.22 if not hollow else 0.35, rng, [1, 0.6, 0.35, 0.2])
    out = 0.6 * r
    out[:len(c)] += c
    if hollow:
        out = out + 0.5 * reverbish(out, rng, 0.25)
    return out


def reverbish(x, rng, tail=0.3):
    n = len(x)
    ir_n = int(tail * SR)
    ir = rng.standard_normal(ir_n) * expdec(ir_n, tail / 4)
    ir[0] = 0
    return signal.fftconvolve(x, ir * 0.02)[:n]


def ghost_wail(rng, dur=0.45, f0=None, fall=0.7, breath=0.6):
    f0 = f0 or rng.uniform(380, 560)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = f0 * (1 + (fall - 1) * tt / dur) * (1 + 0.025 * np.sin(2 * np.pi * 6.5 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    air = bp(rng.standard_normal(n), 700, 3500)
    att = np.minimum(1, tt / 0.02)
    e = att * np.exp(-tt / (dur * 0.45))
    return (0.6 * tone + breath * air * 0.8) * e


def hiss(rng, dur=0.35, lo=2500, hi=9000, tau=None):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    e = np.minimum(1, tt / 0.01) * np.exp(-tt / (tau or dur * 0.35))
    return bp(rng.standard_normal(n), lo, hi) * e


def shriek(rng, dur=0.3, f0=None, harsh=0.6):
    f0 = f0 or rng.uniform(1500, 2300)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = f0 * (1 + 0.25 * np.exp(-tt / 0.04)) * (1 - 0.25 * tt / dur) * (1 + 0.04 * np.sin(2 * np.pi * 28 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    car = np.sin(ph + harsh * 2.5 * np.sin(ph * 1.5))
    e = np.minimum(1, tt / 0.006) * np.exp(-tt / (dur * 0.35))
    return car * e + 0.25 * hiss(rng, dur, 3000, 9000)


def squeak(rng, dur=0.2, n=2):
    items = []
    t = 0
    for i in range(n):
        m = rng.uniform(0.05, 0.09)
        tt = t_(m)
        f = np.linspace(rng.uniform(3800, 5200), rng.uniform(2600, 3400), len(tt))
        ph = 2 * np.pi * np.cumsum(f) / SR
        s = np.tanh(2.2 * (np.sin(ph) + 0.35 * np.sin(ph * 1.5 + 2 * np.sin(ph * 0.25)))) * np.sin(np.pi * tt / m) ** 0.5
        s = s + 0.35 * bp(rng.standard_normal(len(tt)), 2000, 8000) * np.sin(np.pi * tt / m)
        items.append((t, s * rng.uniform(0.6, 1.0)))
        t += m + rng.uniform(0.01, 0.04)
    return place(max(dur, t + 0.02), items)


def croak(rng, dur=0.35, f0=None):
    f0 = f0 or rng.uniform(32, 48)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = f0 * (1 - 0.2 * tt / dur)
    ph = np.cumsum(f) / SR
    pulses = (np.sin(2 * np.pi * ph) > 0.92).astype(float)
    body = bp(pulses, 250, 900) * 4 + bp(pulses, 1100, 1800) * 2
    e = np.minimum(1, tt / 0.01) * np.exp(-tt / (dur * 0.5))
    return body * e


def ice_crack(rng, dur=0.35):
    items = [(0, click(rng, 0.03, 2500, 12000, 0.004) * 1.0)]
    for k in range(8):
        f0 = rng.uniform(2800, 6500)
        items.append((rng.exponential(0.05), 0.5 * ring([f0, f0 * 1.6], 0.08, 0.02, rng) * rng.uniform(0.3, 1)))
    return place(dur, items)


def fire_crackle(rng, dur=0.4):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    out = 0.6 * lp(rng.standard_normal(n), 1800) * np.minimum(1, tt / 0.02) * np.exp(-tt / (dur * 0.4))
    for k in range(10):
        o = int(rng.uniform(0, dur * 0.7) * SR)
        c = click(rng, 0.01, 2000, 10000, 0.0015) * rng.uniform(0.3, 1.0)
        out[o:o + len(c)] += c[:n - o]
    return out


def wood_creak(rng, dur=0.35, f0=None):
    f0 = f0 or rng.uniform(110, 190)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    jit = 1 + 0.15 * signal.sosfilt(signal.butter(1, 30 / (SR / 2), output='sos'), rng.standard_normal(n)) * 8
    ph = np.cumsum(f0 * jit) / SR
    saw = 2 * (ph % 1) - 1
    e = np.minimum(1, tt / 0.015) * np.exp(-tt / (dur * 0.5))
    return bp(saw, 300, 2500) * e


def straw(rng, dur=0.3):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    g = (rng.random(n) < 0.004).astype(float) * rng.uniform(0.3, 1, n)
    g = signal.fftconvolve(g, expdec(200, 0.001))[:n]
    return hp(g * rng.standard_normal(n) + 0.3 * hp(rng.standard_normal(n), 3000), 1500) * np.exp(-tt / (dur * 0.4))


def feathers(rng, dur=0.35):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    am = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(16, 24) * tt) ** 2
    return bp(rng.standard_normal(n), 400, 4000) * am * np.exp(-tt / (dur * 0.4))


def shimmer(rng, dur=0.5, base=880):
    tt = t_(dur)
    out = np.zeros_like(tt)
    for k, r in enumerate([1, 1.5, 2, 2.5, 3.01]):
        out += np.sin(2 * np.pi * base * r * tt * (1 + 0.003 * k)) / (k + 1)
    return out * np.minimum(1, tt / 0.02) * np.exp(-tt / (dur * 0.35))


def dark_hum(rng, dur=0.5, f0=70):
    tt = t_(dur)
    s = np.sin(2 * np.pi * f0 * tt) + 0.5 * np.sin(2 * np.pi * f0 * 1.5 * tt) + 0.3 * np.sin(2 * np.pi * f0 * 2.02 * tt)
    return s * np.minimum(1, tt / 0.02) * np.exp(-tt / (dur * 0.4))


def thud(rng, dur=0.35, f0=60):
    tt = t_(dur)
    f = f0 * (1 + 0.8 * np.exp(-tt / 0.02))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.07)
    return s + 0.3 * lp(rng.standard_normal(len(tt)), 300) * np.exp(-tt / 0.05)


def chain(rng, dur=0.4):
    items, t = [], 0
    for i in range(6):
        f0 = rng.uniform(1800, 3400)
        items.append((t, place(0.08, [(0, 0.7 * ring([f0, f0 * 1.41, f0 * 2.2], 0.08, 0.02, rng)), (0, click(rng, 0.01, 3000, 10000, 0.002))])))
        t += rng.uniform(0.02, 0.05)
    return place(dur, items)


def growl(rng, dur=0.4, f0=None, rough=0.6, formant=(500, 1400)):
    f0 = f0 or rng.uniform(70, 110)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    am = 1 + rough * signal.sosfilt(signal.butter(1, 60 / (SR / 2), output='sos'), rng.standard_normal(n)) * 12
    f = f0 * (1 + 0.3 * np.exp(-tt / 0.05)) * (1 - 0.2 * tt / dur)
    ph = np.cumsum(f) / SR
    pulse = (np.sin(2 * np.pi * ph) > 0.6).astype(float) * am
    body = bp(pulse, formant[0] * 0.6, formant[0] * 1.4) * 3 + bp(pulse, formant[1] * 0.7, formant[1] * 1.3) * 1.5
    body += 0.3 * bp(rng.standard_normal(n), 300, 2500) * np.abs(am)
    e = np.minimum(1, tt / 0.008) * np.exp(-tt / (dur * 0.4))
    return body * e


MATERIALS = {
    'bone': bone_clatter, 'wet': wet_splat, 'stone': stone_crack, 'metal': metal_clank,
    'ghost': ghost_wail, 'hiss': hiss, 'shriek': shriek, 'squeak': squeak, 'croak': croak,
    'ice': ice_crack, 'fire': fire_crackle, 'wood': wood_creak, 'straw': straw, 'feathers': feathers,
    'shimmer': shimmer, 'hum': dark_hum, 'thud': thud, 'chain': chain, 'growl': growl,
}


def norm1(x):
    x = D.fade(x, 0.002, len(x) / SR * 0.4)
    return x / (np.max(np.abs(x)) + 1e-12)
