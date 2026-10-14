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

const float BEZEL_PX = 20.0;

float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    if (strength < 0.01 && power > 0.99) {
        return Texel(tex, uv) * color;
    }

    vec2 ar = vec2(resolution.x / max(1.0, resolution.y), 1.0);
    vec2 pp = (uv - 0.5) * ar;
    float bezelU = BEZEL_PX / max(1.0, resolution.y);
    float cornerR = 0.012;
    vec2 halfExt = 0.5 * ar - bezelU;
    vec2 nn = pp / (0.5 * ar);
    float rrA = dot(nn, nn);
    vec2 ppA = pp * (1.0 + 0.042 * rrA);
    float dTube = roundedBoxSDF(ppA, halfExt, cornerR);

    if (dTube > 0.0) {
        vec3 plastic = vec3(0.115, 0.104, 0.095);

        vec2 aPen = abs(ppA) - halfExt;
        aPen = max(aPen, vec2(0.0));

        float lumX = (pp.x < 0.0) ? 0.98 : 0.78;
        float lumY = (pp.y < 0.0) ? 0.55 : 1.22;
        float mixXY = smoothstep(-0.007, 0.007, aPen.x - aPen.y);
        float facetLum = mix(lumY, lumX, mixXY);

        float dSeam = abs(aPen.x - aPen.y);
        float seamShadow = 0.0;
        if (aPen.x > 0.0005 && aPen.y > 0.0005) {
            seamShadow = exp(-pow(dSeam / 0.0075, 2.0))
                * smoothstep(0.003, 0.010, dTube);
        }

        vec3 cab = plastic * facetLum;
        cab *= 0.95 + 0.10 * rand(floor(uv * resolution * 0.5));
        cab *= 1.0 - 0.20 * seamShadow;

        float groove = smoothstep(0.0045, 0.0, dTube);
        cab *= 1.0 - 0.55 * groove;

        float lipZone = smoothstep(0.013, 0.0045, dTube)
            * (1.0 - smoothstep(0.0045, 0.0, dTube));
        float lipStrength;
        if (aPen.x > aPen.y) lipStrength = (pp.x < 0.0) ? 0.5 : 0.35;
        else lipStrength = (pp.y < 0.0) ? 0.06 : 0.9;
        cab += vec3(0.20, 0.19, 0.175) * lipZone * lipStrength;

        vec2 wq = abs(uv - 0.5) * 2.0;
        cab *= 1.0 - 0.30 * pow(max(wq.x, wq.y), 10.0);

        return vec4(cab, 1.0) * color;
    }

    vec2 tuv = (pp / halfExt) * 0.5 + 0.5;

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

    vec2 cc = tuv - 0.5;
    float r2 = dot(cc, cc);
    vec2 curvXY = vec2(0.060, 0.080) * strength;
    vec2 suv = tuv + cc * (curvXY * r2 * 1.6 + curvXY * r2 * r2 * 7.0);
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

    float caPx = (0.9 + mix(1.6, 3.5, deg) * r2 * 4.0) * strength * caBoost;
    caPx *= (1.0 - calm) * caScale;
    float caOffset = caPx / max(1.0, resolution.x);
    vec4 colR = Texel(tex, suv + vec2(caOffset, 0.0));
    vec4 colG = Texel(tex, suv);
    vec4 colB = Texel(tex, suv - vec2(caOffset, 0.0));
    vec3 rgb = vec3(colR.r, colG.g, colB.b);

    vec2 hpx = 2.0 / resolution;
    vec3 halo = Texel(tex, suv + hpx).rgb + Texel(tex, suv - hpx).rgb
        + Texel(tex, suv + vec2(hpx.x, -hpx.y)).rgb
        + Texel(tex, suv + vec2(-hpx.x, hpx.y)).rgb;
    halo *= 0.25;
    float haloLum = dot(halo, vec3(0.299, 0.587, 0.114));
    rgb += halo * haloLum * 0.10 * strength;

    float frameParity = mod(floor(time * 60.0), 2.0);
    float lineParity = mod(floor(suv.y * resolution.y * 0.5) + frameParity, 2.0);
    float shimmer = 1.0 - lineParity * 0.012 * strength;
    float scan = 1.0 - sin(suv.y * resolution.y * 1.5) * 0.035 * strength;
    float triad = mod(px.x, 3.0);
    vec3 grille = vec3(1.0);
    grille.r += (triad < 1.0 ? 0.05 : -0.03) * strength;
    grille.g += (triad >= 1.0 && triad < 2.0 ? 0.05 : -0.03) * strength;
    grille.b += (triad >= 2.0 ? 0.05 : -0.03) * strength;

    float dome = 1.0 - (mix(0.03, 0.05, deg) * r2 * 2.0
        + mix(0.05, 0.10, deg) * r2 * r2 * 8.0) * strength;
    dome = clamp(dome, mix(0.93, 0.85, deg), 1.0);
    vec2 sheenPos = (suv - vec2(0.5, 0.24)) * vec2(1.0, 2.1);
    float sheen = exp(-dot(sheenPos, sheenPos) * 3.2) * 0.045 * strength;

    float shadowW = mix(mix(0.05, 0.08, deg), mix(0.16, 0.28, deg),
        clamp(1.0 - tuv.y, 0.0, 1.0));
    float glassShadow = 1.0 - shadowW * strength
        * smoothstep(-0.020, -0.001, dTube);

    float dEdge = deg * smoothstep(0.04, 0.32, r2);

    vec2 vPos = (suv - 0.5) * 0.45;
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, pow(vignette, 2.0),
        mix(0.30, 0.55, deg) * strength);
    float flickAmp = 0.008 * (1.0 + 2.5 * dEdge);
    float flicker = (1.0 - flickAmp * strength)
        + flickAmp * strength * sin(time * 60.0);
    float noise = (rand(suv * resolution + time * 40.0) * 0.018 - 0.009)
        * strength * (1.0 + 2.5 * dEdge);

    if (desat > 0.001) {
        float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
        rgb = mix(rgb, vec3(luma) * vec3(0.82, 0.93, 1.18), desat * 0.7);
    }
    if (snow > 0.001) {
        float n = rand(suv * resolution + vec2(time * 173.0, time * 91.0));
        rgb = mix(rgb, vec3(n * 0.85 + 0.06), snow);
    }
    if (rollBar > 0.001) {
        rgb *= 1.0 - 0.65 * rollBar;
    }

    if (dEdge > 0.001) {
        float hum = pow(0.5 + 0.5 * sin((suv.y - time * 0.22) * 9.4), 3.0);
        rgb *= 1.0 - 0.13 * dEdge * hum;
        float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
        rgb = mix(rgb, vec3(luma) * vec3(0.92, 0.97, 1.06), 0.18 * dEdge);
    }

    rgb *= grille * scan * shimmer * flicker * vignette * dome * glassShadow;
    rgb += sheen;
    rgb += noise;
    rgb *= surge;
    rgb = mix(rgb, vec3(1.0, 0.98, 0.92), hotline * 0.85);

    return vec4(rgb, 1.0) * color;
}
