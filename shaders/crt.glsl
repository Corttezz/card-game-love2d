extern number time;
extern vec2 resolution;
extern number strength;
extern number power;
extern number powerDir;
extern number glitch;
extern number glitchY;
extern number degrade;
extern vec4 calmRect;
extern vec4 calmRect2;
extern number caScale;

const float BEZEL_PX = 16.0;
const float CORNER_R = 0.045;
const vec2 CURV = vec2(0.068, 0.089);

float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 roundedBoxNormal(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    vec2 g;
    if (q.x > 0.0 || q.y > 0.0) g = normalize(max(q, vec2(0.0)) + vec2(1e-6));
    else g = (q.x > q.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    return g * vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 clampUv(vec2 t) {
    return clamp(t, vec2(0.0005), vec2(0.9995));
}

vec2 warp(vec2 tuv, float k) {
    vec2 cc = tuv - 0.5;
    float r2 = dot(cc, cc);
    vec2 kk = CURV * k;
    return tuv + cc * kk * (r2 * 1.6 + r2 * r2 * 9.0);
}

vec3 bezelSpill(Image tex, vec2 ppI, vec2 halfExt, float dIn) {
    vec2 m = (ppI / halfExt) * 0.5 + 0.5;
    if (m.x > 1.0) m.x = 2.0 - m.x;
    if (m.y > 1.0) m.y = 2.0 - m.y;
    if (m.x < 0.0) m.x = -m.x;
    if (m.y < 0.0) m.y = -m.y;
    vec2 o = vec2(3.0 + dIn * 0.9) / resolution;
    vec3 s = Texel(tex, clampUv(m)).rgb * 0.28;
    s += Texel(tex, clampUv(m + vec2(o.x, 0.0))).rgb * 0.18;
    s += Texel(tex, clampUv(m - vec2(o.x, 0.0))).rgb * 0.18;
    s += Texel(tex, clampUv(m + vec2(0.0, o.y))).rgb * 0.18;
    s += Texel(tex, clampUv(m - vec2(0.0, o.y))).rgb * 0.18;
    return s;
}

vec3 cabinet(Image tex, vec2 uv, vec2 ppI, vec2 halfExt, float dIn) {
    vec2 sp = floor(uv * resolution);
    float dOut = min(min(sp.x, resolution.x - 1.0 - sp.x), min(sp.y, resolution.y - 1.0 - sp.y));
    float di = floor(dIn);
    vec2 n = roundedBoxNormal(ppI, halfExt, CORNER_R);
    vec2 toLight = normalize(vec2(-0.62, -0.78));
    float facing = dot(n, toLight);
    float lum = 1.0 + 0.10 * facing;
    vec3 spill = vec3(0.0);
    if (di < 2.0) {
        lum = (di < 1.0) ? 0.14 : 0.30;
    } else if (di < 8.0) {
        float k = (di - 2.0) / 5.0;
        lum = 1.0 - 0.62 * facing - 0.12 * (1.0 - k);
        spill = bezelSpill(tex, ppI, halfExt, dIn) * exp(-(di - 2.0) / 3.0) * 0.30;
    } else if (di < 9.0) {
        lum = 1.45 + 0.35 * max(-facing, 0.0) + 0.20 * max(facing, 0.0);
    } else if (di < 11.0) {
        lum = 0.86;
    }
    if (dOut < 4.0) {
        float k = 1.0 - dOut / 4.0;
        lum = mix(lum, 1.0 + 0.75 * facing, 0.8) * (1.0 - 0.15 * k);
        if (dOut < 1.0) lum *= 0.5;
    }
    vec2 tl = uv * vec2(resolution.x / resolution.y, 1.0);
    float nearTL = exp(-dot(tl, tl) * 2.2);
    float spec = 0.0;
    if (di >= 8.0 && di < 9.0) spec += 0.10 * max(facing, 0.0) * nearTL;
    if (dOut >= 1.0 && dOut < 4.0) {
        float band = exp(-pow((tl.x - tl.y * 1.7 - 0.06) / 0.05, 2.0));
        spec += 0.12 * max(facing, 0.0) * band;
    }
    vec3 plastic = vec3(0.112, 0.102, 0.094);
    vec3 cab = plastic * lum;
    cab *= 0.94 + 0.11 * rand(floor(uv * resolution * 0.5));
    cab += vec3(0.85, 0.85, 0.80) * spec * 0.6;
    cab += spill * vec3(0.95, 0.92, 0.88);
    vec2 wq = abs(uv - 0.5) * 2.0;
    cab *= 1.0 - 0.25 * pow(max(wq.x, wq.y), 12.0);
    return cab;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    if (strength < 0.01 && power > 0.99) {
        return Texel(tex, uv) * color;
    }

    vec2 ar = vec2(resolution.x / max(1.0, resolution.y), 1.0);
    vec2 pp = (uv - 0.5) * ar;
    float bezelU = BEZEL_PX / max(1.0, resolution.y);
    vec2 halfExt = 0.5 * ar - bezelU;
    vec2 tuv = (pp / halfExt) * 0.5 + 0.5;
    vec2 suv0 = warp(tuv, strength);
    vec2 ppI = (suv0 - 0.5) * 2.0 * halfExt;
    float dTube = roundedBoxSDF(ppI, halfExt, CORNER_R);
    float gradD = length(vec2(dFdx(dTube), dFdy(dTube)));
    float dIn = dTube / max(gradD, 1e-6);

    if (dTube > 0.0) {
        return vec4(cabinet(tex, uv, ppI, halfExt, dIn), 1.0) * color;
    }

    float p = clamp(power, 0.0, 1.0);
    float surge = 1.0;
    float hotline = 0.0;
    float snow = 0.0;
    float desat = 0.0;
    float caBoost = 1.0;
    float rollBar = 0.0;
    if (p < 0.999) {
        if (p < 0.02) {
            vec2 og = tuv - vec2(0.5, 0.3);
            float offGlow = 0.012 + 0.02 * exp(-dot(og, og) * 3.0);
            return vec4(vec3(offGlow), 1.0) * color;
        }
        float vScale = 1.0;
        float hScale = 1.0;
        float aspT = halfExt.x / halfExt.y;
        if (powerDir < -0.5) {
            if (p < 0.34) {
                float fade = (p - 0.02) / 0.32;
                vec2 dpt = (tuv - 0.5) * vec2(aspT, 1.0);
                float d2 = dot(dpt, dpt);
                float core = exp(-d2 * (9000.0 + 22000.0 * (1.0 - fade)));
                float halo = exp(-d2 * 420.0) * 0.35 * fade;
                vec3 dotCol = mix(vec3(1.0, 0.52, 0.22),
                                  vec3(1.0, 0.97, 0.88), fade);
                vec2 og = tuv - vec2(0.5, 0.3);
                float offGlow = 0.012
                    + 0.02 * exp(-dot(og, og) * 3.0) * (1.0 - fade);
                float amp = fade * fade * 0.9 + 0.1 * fade;
                return vec4(dotCol * (core * 1.5 + halo) * amp
                    + vec3(offGlow), 1.0) * color;
            } else if (p < 0.64) {
                float k = (p - 0.34) / 0.30;
                vScale = 0.006;
                hScale = max(0.012, k * k);
                surge = 2.6;
                hotline = 1.0;
            } else {
                float k = (p - 0.64) / 0.36;
                vScale = max(0.006, k * k);
                surge = 1.0 + (1.0 - k) * 1.5;
                hotline = clamp(1.0 - vScale * 9.0, 0.0, 1.0);
            }
        } else {
            if (p < 0.10) {
                float k = (p - 0.02) / 0.08;
                vec2 dpt = (tuv - 0.5) * vec2(aspT, 1.0);
                float d2 = dot(dpt, dpt);
                float core = exp(-d2 * (30000.0 - 21000.0 * k));
                float halo = exp(-d2 * 500.0) * 0.28 * k;
                vec3 dotCol = vec3(0.72, 0.84, 1.0);
                return vec4(dotCol * (core * (0.35 + 0.65 * k) + halo)
                    + vec3(0.012), 1.0) * color;
            } else if (p < 0.30) {
                float k = (p - 0.10) / 0.20;
                hScale = max(0.02, k);
                vScale = 0.006;
                surge = 2.4;
                hotline = 1.0;
            } else if (p < 0.62) {
                float k = (p - 0.30) / 0.32;
                k = k * k;
                vScale = 0.006 + 0.994 * k;
                surge = 1.9 - 0.6 * k;
                hotline = clamp(1.0 - vScale * 12.0, 0.0, 1.0);
                snow = 0.5 - 0.2 * k;
                desat = 1.0 - 0.3 * k;
                caBoost = 1.0 + 2.5 * (1.0 - k);
            } else if (p < 0.80) {
                float k = (p - 0.62) / 0.18;
                float roll = (1.0 - k) * (1.0 - k) * 1.2;
                float fy = fract(tuv.y + roll);
                float seam = min(fy, 1.0 - fy);
                rollBar = exp(-pow(seam / 0.030, 2.0)) * (1.0 - k);
                tuv.y = fy;
                snow = 0.30 * (1.0 - k);
                desat = 0.7 * (1.0 - k);
                caBoost = 1.0 + 1.8 * (1.0 - k);
                surge = 1.3 - 0.15 * k;
            } else if (p < 0.94) {
                float k = (p - 0.80) / 0.14;
                surge = 1.15 - 0.10 * k;
                snow = (1.0 - k) * 0.10;
                desat = (1.0 - k) * 0.5;
                caBoost = 1.0 + 1.6 * (1.0 - k);
            } else {
                float k = (p - 0.94) / 0.06;
                surge = 1.05 - 0.05 * k;
                float breath = sin(p * 240.0) * (1.0 - k) * 0.0045;
                tuv = 0.5 + (tuv - 0.5) * (1.0 + breath);
            }
        }
        vec2 tuvOrig = tuv;
        tuv.x = 0.5 + (tuv.x - 0.5) / hScale;
        tuv.y = 0.5 + (tuv.y - 0.5) / vScale;
        if (tuv.x < 0.0 || tuv.x > 1.0 || tuv.y < 0.0 || tuv.y > 1.0) {
            float sigY = 0.012 + vScale * 0.05;
            float glowY = exp(-pow((tuvOrig.y - 0.5) / sigY, 2.0));
            float dx = max(0.0, abs(tuvOrig.x - 0.5) - 0.5 * hScale);
            float glowX = exp(-pow(dx / 0.06, 2.0));
            float lineGlow = glowY * glowX * hotline * 0.34 * surge;
            return vec4(vec3(0.012) + vec3(0.9, 0.87, 1.0) * lineGlow,
                1.0) * color;
        }
    }

    vec2 suv = (p < 0.999) ? warp(tuv, strength) : suv0;
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        return vec4(vec3(0.012), 1.0) * color;
    }

    if (glitch > 0.001) {
        float band = exp(-pow((suv.y - glitchY) * 22.0, 2.0));
        float lineNoise = rand(vec2(floor(suv.y * resolution.y), floor(time * 90.0)));
        suv.x += (lineNoise - 0.5) * 0.006 * glitch * band;
        suv.y += (rand(vec2(floor(time * 60.0), 7.0)) - 0.5) * 0.0016 * glitch;
    }

    float calm = 0.0;
    vec2 cp = suv * resolution;
    if (calmRect.z > 0.0) {
        vec2 dd = max(max(calmRect.xy - cp, cp - (calmRect.xy + calmRect.zw)), vec2(0.0));
        calm = 1.0 - smoothstep(0.0, 24.0, length(dd));
    }
    if (calmRect2.z > 0.0) {
        vec2 dd2 = max(max(calmRect2.xy - cp, cp - (calmRect2.xy + calmRect2.zw)), vec2(0.0));
        calm = max(calm, 1.0 - smoothstep(0.0, 24.0, length(dd2)));
    }
    float deg = degrade * (1.0 - calm);
    float steady = 1.0 - calm;

    vec2 cc = suv - 0.5;
    float r2 = dot(cc, cc);
    float edgeK = smoothstep(0.05, 0.42, r2);
    vec2 ipx = 1.0 / resolution;
    float resK = clamp(resolution.y / 1080.0, 0.6, 1.5);

    float conv = smoothstep(0.015, 0.5, r2) * (1.0 + 0.8 * deg);
    vec2 dir = cc * 2.0;
    float convAmt = strength * caScale * caBoost * steady;
    vec2 offR = (dir * conv * 2.6 + vec2(0.0, -conv * 0.7)) * ipx * convAmt * resK;
    vec2 offB = (-dir * conv * 2.2 + vec2(conv * 0.3, conv * 0.7)) * ipx * convAmt * resK;
    vec2 caB = vec2(0.9 * convAmt * ipx.x, 0.0);
    vec3 rgb = vec3(Texel(tex, suv + offR + caB).r, Texel(tex, suv).g, Texel(tex, suv + offB - caB).b);

    float blurK = smoothstep(0.07, 0.48, r2) * steady;
    if (blurK > 0.002) {
        float rad = 2.4 * blurK * strength * resK;
        vec3 soft = rgb * 0.20;
        for (int i = 0; i < 8; i++) {
            float a = float(i) * 0.785398 + 0.39;
            vec2 d = vec2(cos(a), sin(a));
            soft += Texel(tex, suv + d * rad * ipx).rgb * 0.06;
            soft += Texel(tex, suv + d * rad * 0.5 * ipx).rgb * 0.04;
        }
        rgb = mix(rgb, soft, clamp(blurK * 0.6, 0.0, 1.0));
    }

    vec2 hpx = 2.0 / resolution;
    vec3 halo = (Texel(tex, suv + hpx).rgb + Texel(tex, suv - hpx).rgb
        + Texel(tex, suv + vec2(hpx.x, -hpx.y)).rgb
        + Texel(tex, suv + vec2(-hpx.x, hpx.y)).rgb) * 0.25;
    rgb += halo * luma(halo) * 0.10 * strength;

    float tubeRim = smoothstep(-0.035, 0.0, dTube);
    rgb *= 1.0 - 0.50 * tubeRim * tubeRim * strength;

    vec3 bloom = vec3(0.0);
    float rr1 = mix(3.0, 6.0, edgeK) * resK;
    float rr2 = mix(9.0, 18.0, edgeK) * resK;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398 + 0.2;
        vec2 d = vec2(cos(a), sin(a));
        vec3 s1 = Texel(tex, suv + d * rr1 * ipx).rgb;
        vec3 s2 = Texel(tex, suv + d * rr2 * ipx + d.yx * 2.0 * ipx).rgb;
        bloom += s1 * smoothstep(0.35, 0.80, luma(s1)) * 0.60 + s2 * smoothstep(0.35, 0.80, luma(s2)) * 0.40;
    }
    bloom = bloom / 8.0 * vec3(1.0, 0.88, 0.72);
    rgb += max(bloom - rgb * 0.85, vec3(0.0)) * mix(0.65, 1.1, edgeK) * strength * 1.6;

    float corner = smoothstep(0.22, 0.50, r2);
    rgb *= 1.0 - 0.14 * corner * strength;

    float lumS = clamp(luma(rgb), 0.0, 1.0);
    float ly = suv.y * resolution.y / 3.0;
    float sy = fract(ly) - 0.5;
    float bw = mix(0.22, 0.46, lumS);
    float beam = exp(-(sy * sy) / (2.0 * bw * bw));
    float scanAmt = mix(0.18, 0.55, edgeK) * strength * (1.0 - 0.6 * calm);
    float scan = mix(1.0, beam * 1.22, scanAmt);
    float col = mod(floor(px.x), 3.0);
    vec3 stripe = vec3(0.50);
    if (col < 1.0) stripe.r = 1.0;
    else if (col < 2.0) stripe.g = 1.0;
    else stripe.b = 1.0;
    float maskAmt = mix(0.18, 0.65, edgeK) * strength * (1.0 - 0.6 * calm);
    vec3 maskV = mix(vec3(1.0), stripe * 1.5, maskAmt) * scan;

    float dome = 1.0 - (mix(0.03, 0.05, deg) * r2 * 2.0
        + mix(0.05, 0.10, deg) * r2 * r2 * 8.0) * strength;
    dome = clamp(dome, mix(0.93, 0.85, deg), 1.0);
    vec2 sheenPos = (suv - vec2(0.5, 0.24)) * vec2(1.0, 2.1);
    float sheen = exp(-dot(sheenPos, sheenPos) * 3.2) * 0.045 * strength;

    float shadowW = mix(mix(0.05, 0.08, deg), mix(0.16, 0.28, deg),
        clamp(1.0 - tuv.y, 0.0, 1.0));
    float glassShadow = 1.0 - shadowW * strength * smoothstep(-0.020, -0.001, dTube);

    float dEdge = deg * smoothstep(0.04, 0.32, r2);
    vec2 vPos = (suv - 0.5) * 0.45;
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, vignette * vignette, mix(0.30, 0.55, deg) * strength);
    float flickAmp = 0.008 * (1.0 + 2.5 * dEdge);
    float flicker = (1.0 - flickAmp * strength) + flickAmp * strength * sin(time * 60.0);
    float noise = (rand(suv * resolution + time * 40.0) * 0.018 - 0.009)
        * strength * (1.0 + 2.5 * dEdge);

    if (desat > 0.001) {
        float l = luma(rgb);
        rgb = mix(rgb, vec3(l) * vec3(0.82, 0.93, 1.18), desat * 0.7);
    }
    if (snow > 0.001) {
        float nz = rand(suv * resolution + vec2(time * 173.0, time * 91.0));
        rgb = mix(rgb, vec3(nz * 0.85 + 0.06), snow);
    }
    if (rollBar > 0.001) {
        rgb *= 1.0 - 0.65 * rollBar;
    }
    if (dEdge > 0.001) {
        float hum = pow(0.5 + 0.5 * sin((suv.y - time * 0.22) * 9.4), 3.0);
        rgb *= 1.0 - 0.13 * dEdge * hum;
        float l = luma(rgb);
        rgb = mix(rgb, vec3(l) * vec3(0.92, 0.97, 1.06), 0.18 * dEdge);
    }

    rgb *= maskV * flicker * vignette * dome * glassShadow;

    vec2 wq = tuv - vec2(0.27, 0.19);
    float ca = cos(-0.42);
    float sa = sin(-0.42);
    wq = vec2(ca * wq.x - sa * wq.y, sa * wq.x + ca * wq.y);
    float dWin = roundedBoxSDF(wq * vec2(1.0, 1.7), vec2(0.17, 0.10), 0.05);
    float winMask = 1.0 - smoothstep(-0.05, 0.05, dWin);
    float winGrad = clamp(1.0 - (wq.x + 0.17) / 0.40, 0.0, 1.0);
    float refl = winMask * (0.55 + 0.45 * winGrad);
    float darkness = 1.0 - clamp(luma(rgb) * 1.4, 0.0, 1.0);
    rgb += vec3(0.80, 0.86, 0.95) * refl * 0.045 * strength * (0.35 + 0.65 * darkness);

    float rimG = smoothstep(-0.07, 0.0, dTube);
    rgb = rgb * (1.0 - 0.14 * rimG * strength) + vec3(0.16, 0.17, 0.19) * 0.14 * rimG * strength;
    float topSide = clamp(1.0 - tuv.y * 1.6, 0.0, 1.0) * clamp(1.0 - abs(tuv.x - 0.42) * 1.6, 0.0, 1.0);
    float specLine = exp(-pow((dTube + 0.011) / 0.0035, 2.0)) * topSide;
    rgb += vec3(0.95, 0.95, 1.0) * specLine * 0.22 * strength;

    rgb += vec3(0.008) * strength;
    rgb += sheen;
    rgb += noise;
    rgb *= surge;
    rgb = mix(rgb, vec3(1.0, 0.98, 0.92), hotline * 0.85);

    return vec4(rgb, 1.0) * color;
}
