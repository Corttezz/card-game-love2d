extern vec2 texSize;
extern float time;
extern vec4 L1;
extern vec4 L2;
extern float veilK;
extern vec3 grade;
extern vec2 rows;
extern float flick;
extern float seed;

float alphaAt(Image tex, vec2 p) {
    if (p.x < 0.0 || p.y < 0.0 || p.x >= texSize.x || p.y >= texSize.y) return 0.0;
    return Texel(tex, (p + 0.5) / texSize).a;
}

float h21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = h21(i);
    float b = h21(i + vec2(1.0, 0.0));
    float c = h21(i + vec2(0.0, 1.0));
    float d = h21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 tc = floor(uv * texSize);
    float t = time;
    float kP = L1.x;
    float kB = L1.y;
    float kW = L1.z;
    float kV = L1.w;
    float kS = L2.x;
    float kE = L2.y;
    float kR = L2.z;
    float kK = L2.w;
    float H = max(8.0, rows.y - rows.x);
    float yn = clamp((tc.y - rows.x) / H, 0.0, 1.0);
    float a = alphaAt(tex, tc);
    vec3 gk = mix(vec3(1.0), grade, 0.25);

    if (a < 0.5) {
        if (kB <= 0.0 && kS <= 0.0 && veilK <= 0.0) return vec4(0.0);
        float sway = floor(sin(tc.y * 0.55 + t * 7.0 + seed) * 0.9 + 0.5);
        vec2 q = vec2(tc.x + sway, tc.y);
        float d = 0.0;
        for (int i = 1; i <= 14; i++) {
            if (d == 0.0 && alphaAt(tex, q + vec2(0.0, float(i))) > 0.5) d = float(i);
        }
        if (d > 0.0 && kB > 0.0) {
            float n = vnoise(vec2(q.x * 0.31 + seed, t * 2.4));
            float n2 = vnoise(vec2(q.x * 0.87 + 3.0, t * 5.5));
            float baseY = (q.y + d - rows.x) / H;
            float hgt = kB * (1.6 + 11.0 * smoothstep(0.38, 0.88, n) + 2.0 * n2) * mix(0.55, 1.15, baseY);
            float fd = d / max(1.0, hgt);
            bool cut = fd > 0.70 && h21(vec2(tc.x, floor(t * 11.0) + tc.y)) < 0.30;
            if (fd <= 1.0 && !cut) {
                vec3 fc = vec3(0.55, 0.10, 0.05);
                if (fd < 0.22) fc = vec3(1.0, 0.96, 0.70);
                else if (fd < 0.48) fc = vec3(1.0, 0.76, 0.22);
                else if (fd < 0.78) fc = vec3(0.96, 0.40, 0.10);
                return vec4(fc * gk, color.a);
            }
        }
        if (d > 0.0 && d <= 3.0 && kS > 0.0) {
            float spos = 1.15 - fract(t / 1.3) * 1.4;
            float sb = max(0.0, 1.0 - abs((q.y + d - rows.x) / H + (vnoise(q * 0.22 + seed) - 0.5) * 0.34 - spos) / 0.11);
            float hc = h21(vec2(q.x, 17.0 + seed));
            float fl = kS * (hc < 0.45 ? 3.0 : 1.5) * sb;
            if (d <= fl) {
                vec3 sc2 = d < 1.5 ? vec3(1.0, 0.94, 0.60) : vec3(1.0, 0.66, 0.18);
                return vec4(sc2 * gk, color.a);
            }
        }
        if (veilK > 0.0) {
            float nb = 0.0;
            for (int i = 2; i <= 6; i += 2) {
                float fi = float(i);
                nb = max(nb, alphaAt(tex, tc + vec2(fi, 0.0)));
                nb = max(nb, alphaAt(tex, tc + vec2(-fi, 0.0)));
                nb = max(nb, alphaAt(tex, tc + vec2(0.0, fi)));
            }
            if (nb > 0.5) {
                float nf = vnoise(tc * 0.22 + vec2(t * 0.6, -t * 0.25) + seed);
                float ns = vnoise(vec2(tc.x * 0.09 + tc.y * 0.06 + t * 0.5, tc.y * 0.20 - tc.x * 0.03 - t * 0.1) + seed);
                if (ns > 0.66 - 0.06 * veilK && nf > 0.35) {
                    return vec4(vec3(0.80, 0.84, 0.94) * grade, 0.42 * veilK * color.a);
                }
            }
        }
        return vec4(0.0);
    }

    vec3 c = Texel(tex, (tc + 0.5) / texSize).rgb * color.rgb;
    float l = lum(c);
    float aU = alphaAt(tex, tc + vec2(0.0, -1.0));
    float aD = alphaAt(tex, tc + vec2(0.0, 1.0));
    float aL = alphaAt(tex, tc + vec2(-1.0, 0.0));
    float aR = alphaAt(tex, tc + vec2(1.0, 0.0));
    bool edge1 = aU < 0.5 || aD < 0.5 || aL < 0.5 || aR < 0.5;
    bool upEdge = aU < 0.5;
    bool near2 = edge1
        || alphaAt(tex, tc + vec2(0.0, -2.0)) < 0.5 || alphaAt(tex, tc + vec2(0.0, 2.0)) < 0.5
        || alphaAt(tex, tc + vec2(-2.0, 0.0)) < 0.5 || alphaAt(tex, tc + vec2(2.0, 0.0)) < 0.5;

    if (kW > 0.0) {
        c = mix(c, vec3(l), 0.62 * kW);
        c *= 1.0 - 0.16 * kW;
        c += vec3(0.0, 0.02, 0.07) * kW;
        l = lum(c);
    }

    if (kP > 0.0) {
        float pulse = 0.5 + 0.5 * sin(t * 2.4 - yn * 5.0);
        vec3 pc = vec3(l * 0.55, l * 1.10 + 0.06, l * 0.35);
        c = mix(c, pc, kP * (0.20 + 0.24 * pulse));
        c += vec3(0.02, 0.10, 0.0) * kP * pulse;
        float nb = vnoise(tc * 0.18 + vec2(seed, -t * 0.3));
        if (nb > 0.70) c = mix(c, vec3(0.30, 0.62, 0.12) * (0.6 + l), 0.55 * kP);
        vec2 cell = floor(tc / 8.0);
        float hb = h21(cell + seed);
        if (hb < 0.20 + 0.35 * kP) {
            float per = 1.6 + hb * 1.8;
            float ph = fract(t / per + hb * 7.0);
            vec2 ctr = cell * 8.0 + 2.0 + floor(vec2(h21(cell + 3.1), h21(cell + 5.7)) * 4.0);
            if (alphaAt(tex, ctr) > 0.5 && alphaAt(tex, ctr + vec2(0.0, -2.0)) > 0.5
                && alphaAt(tex, ctr + vec2(0.0, 2.0)) > 0.5 && alphaAt(tex, ctr + vec2(-2.0, 0.0)) > 0.5
                && alphaAt(tex, ctr + vec2(2.0, 0.0)) > 0.5) {
                vec2 dv = tc - ctr;
                float r2 = dot(dv, dv);
                if (ph >= 0.14 && ph < 0.26) {
                    if (r2 < 0.5) c = vec3(0.62, 0.95, 0.40);
                } else if (ph >= 0.26 && ph < 0.40) {
                    if (r2 <= 1.0) c = (dv.y < -0.5) ? vec3(0.92, 1.0, 0.80) : vec3(0.55, 0.90, 0.32);
                } else if (ph >= 0.40 && ph < 0.88) {
                    if (r2 <= 4.0) {
                        c = mix(c, vec3(0.56, 0.92, 0.36), 0.55);
                        if (r2 >= 3.5) c = vec3(0.14, 0.34, 0.07);
                        if (dv.x == -1.0 && dv.y == -1.0) c = vec3(0.96, 1.0, 0.88);
                    }
                } else if (ph >= 0.88) {
                    if ((abs(dv.x) == 2.0 && abs(dv.y) == 2.0) || (dv.x == 0.0 && abs(dv.y) == 3.0)
                        || (dv.y == 0.0 && abs(dv.x) == 3.0)) c = vec3(0.80, 1.0, 0.62);
                }
            }
        }
    }

    if (kB > 0.0) {
        float fl = 0.70 + 0.30 * vnoise(vec2(tc.x * 0.25 + seed, t * 6.0));
        float wl = smoothstep(0.30, 1.0, yn) * fl;
        c += vec3(1.0, 0.40, 0.10) * (0.20 + 0.9 * l) * wl * 0.55 * kB;
        float nc = vnoise(tc * 0.30 + seed * 1.7) + (yn - 0.5) * 0.30;
        if (nc > 0.70 && nc < 0.735) {
            c = mix(c, vec3(1.0, 0.50, 0.12), 0.80 * kB * (0.55 + 0.45 * sin(t * 6.0 + tc.x * 1.3)));
        }
        if (upEdge) c = mix(c, vec3(1.0, 0.78, 0.32), 0.60 * kB);
    }

    if (kW > 0.0) {
        float hx = h21(vec2(tc.x, seed + 11.0));
        if (hx < 0.10) {
            float per = 2.0 + hx * 12.0;
            float ph = fract(t / per + hx * 13.0);
            float yd = floor(rows.x + H * 0.04 + ph * H * 0.55);
            if (ph < 0.9 && aD > 0.5) {
                if (tc.y == yd) c = vec3(0.96, 0.99, 1.0);
                else if (tc.y == yd + 1.0) c = vec3(0.58, 0.80, 1.0);
                else if (tc.y == yd + 2.0) c = vec3(0.22, 0.42, 0.78);
                else if (tc.y < yd && tc.y >= yd - 4.0) c = mix(c, c * vec3(0.72, 0.86, 1.15) + 0.04, 0.6);
            }
        }
    }

    if (kV > 0.0) {
        float pv = 0.5 + 0.5 * sin(t * 3.0);
        c = mix(c, vec3(l * 0.85 + 0.05, l * 0.58, l * 1.18 + 0.08), kV * (0.24 + 0.24 * pv));
        c += vec3(0.10, 0.0, 0.16) * kV * pv;
        vec2 cell = floor(tc / 7.0);
        float hc = h21(cell + seed + 2.0);
        vec2 lc = tc - cell * 7.0;
        float lx = (hc < 0.31) ? lc.x : 6.0 - lc.x;
        bool crack = hc < 0.62 && (lx == lc.y || (lx == lc.y + 1.0 && mod(lc.y, 3.0) == 1.0));
        if (crack && near2) {
            float g = pow(max(0.0, sin(t * 2.2 - hc * 25.0)), 10.0);
            float f2 = max(g, flick);
            c = f2 > 0.45 ? vec3(1.0, 0.92, 1.0) : mix(vec3(0.66, 0.40, 1.0), vec3(0.20, 0.03, 0.30), step(0.35, l));
        }
    }

    if (kS > 0.0) {
        float spos = 1.15 - fract(t / 1.3) * 1.4;
        float wob = (vnoise(tc * 0.22 + seed) - 0.5) * 0.34 + (vnoise(tc * 0.6 + 4.0) - 0.5) * 0.10;
        float sb = max(0.0, 1.0 - abs(yn + wob - spos) / 0.11);
        sb = floor(sb * 3.0 + 0.5) / 3.0 * (0.45 + 0.9 * l);
        c = mix(c, c * vec3(1.22, 1.04, 0.78) + vec3(0.05, 0.03, 0.0), kS * 0.40);
        c += vec3(0.50, 0.38, 0.08) * kS * min(1.0, sb);
        if (edge1 && sb > 0.0) c = mix(c, vec3(1.0, 0.92, 0.55), kS * min(1.0, sb * 1.4));
    }

    if (kE > 0.0) {
        float hbt = pow(max(0.0, sin(t * 6.0)), 8.0) + 0.6 * pow(max(0.0, sin(t * 6.0 - 0.8)), 8.0);
        c = mix(c, vec3(l * 1.70 + 0.14, l * 0.22, l * 0.16), kE * (0.36 + 0.40 * hbt));
        c += vec3(0.16, 0.0, 0.0) * kE * hbt;
    }

    if (kR > 0.0) {
        float pos = 1.0 - fract(t / 1.8) * 1.3 + 0.15;
        float wob = (vnoise(tc * 0.2 + seed + 9.0) - 0.5) * 0.36 + (vnoise(tc * 0.55) - 0.5) * 0.10;
        float g = max(0.0, 1.0 - abs(yn + wob - pos) / 0.14);
        g = floor(g * 3.0 + 0.5) / 3.0;
        c = mix(c, c + vec3(0.18, 0.60, 0.36), kR * (0.06 + 0.70 * g));
        if (h21(tc + floor(t * 5.0) + seed) > 0.994) c = vec3(0.82, 1.0, 0.80);
    }

    if (kK > 0.0) {
        c = mix(c, vec3(l * 0.78, l * 0.88, l * 1.04) + vec3(0.04, 0.05, 0.08), 0.55 * kK);
        float ph = fract(t / 1.7) * 1.7 - 0.35;
        float dd = (tc.x + (texSize.y - tc.y) * 0.55) / (texSize.x + texSize.y * 0.55) - ph
            + (vnoise(tc * 0.3 + seed) - 0.5) * 0.03;
        float shine = 0.35 + 0.9 * l;
        if (abs(dd) < 0.018) c = mix(c, vec3(0.96, 0.99, 1.0), 0.60 * kK * shine);
        else if (dd > 0.0 && dd < 0.05) c = mix(c, vec3(0.72, 0.84, 1.0), 0.35 * kK * shine);
        else if (dd < 0.0 && dd > -0.06) c = mix(c, vec3(0.30, 0.37, 0.50) * (0.5 + l), 0.45 * kK);
        if (edge1 && abs(dd) < 0.07) c = mix(c, vec3(1.0), 0.6 * kK);
    }

    if (veilK > 0.0) {
        float nv = vnoise(tc * 0.12 + vec2(t * 0.35, -t * 0.2) + seed);
        c = mix(c, vec3(l) * vec3(0.86, 0.90, 1.06) + 0.10, 0.40 * veilK);
        float ns = vnoise(vec2(tc.x * 0.09 + tc.y * 0.06 + t * 0.5, tc.y * 0.20 - tc.x * 0.03 - t * 0.1) + seed);
        float fs = floor(smoothstep(0.52, 0.80, ns) * 3.0 + 0.5) / 3.0;
        c = mix(c, vec3(0.82, 0.86, 0.96) * grade, 0.55 * veilK * fs);
        float va = 1.0 - veilK * (0.20 + 0.14 * sin(t * 2.3 + nv * 4.0));
        return vec4(c, color.a * va);
    }

    return vec4(c, color.a);
}
