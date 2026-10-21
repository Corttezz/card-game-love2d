extern number time;
extern vec2 resolution;
extern number strength;

const float BEZEL_PX = 30.0;
const float CORNER_R = 0.045;
const float BULGE = 0.060;

float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
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

vec3 cabinet(vec2 uv, vec2 pp, vec2 ppA, vec2 halfExt, float dTube) {
    vec3 plastic = vec3(0.115, 0.104, 0.095);
    vec2 aPen = max(abs(ppA) - halfExt, vec2(0.0));
    float lumX = (pp.x < 0.0) ? 0.98 : 0.78;
    float lumY = (pp.y < 0.0) ? 0.55 : 1.22;
    float mixXY = smoothstep(-0.007, 0.007, aPen.x - aPen.y);
    float facetLum = mix(lumY, lumX, mixXY);
    float dSeam = abs(aPen.x - aPen.y);
    float seamShadow = 0.0;
    if (aPen.x > 0.0005 && aPen.y > 0.0005) {
        seamShadow = exp(-pow(dSeam / 0.0075, 2.0)) * smoothstep(0.003, 0.010, dTube);
    }
    vec3 cab = plastic * facetLum;
    cab *= 0.95 + 0.10 * rand(floor(uv * resolution * 0.5));
    cab *= 1.0 - 0.20 * seamShadow;
    float groove = smoothstep(0.0045, 0.0, dTube);
    cab *= 1.0 - 0.55 * groove;
    float lipZone = smoothstep(0.013, 0.0045, dTube) * (1.0 - smoothstep(0.0045, 0.0, dTube));
    float lipStrength;
    if (aPen.x > aPen.y) lipStrength = (pp.x < 0.0) ? 0.5 : 0.35;
    else lipStrength = (pp.y < 0.0) ? 0.06 : 0.9;
    cab += vec3(0.20, 0.19, 0.175) * lipZone * lipStrength;
    vec2 wq = abs(uv - 0.5) * 2.0;
    cab *= 1.0 - 0.30 * pow(max(wq.x, wq.y), 10.0);
    return cab;
}

vec3 bezelSpill(Image tex, vec2 pp, vec2 halfExt, float dTube) {
    vec2 t = (pp / halfExt) * 0.5 + 0.5;
    vec2 m = t;
    if (m.x > 1.0) m.x = 2.0 - m.x;
    if (m.y > 1.0) m.y = 2.0 - m.y;
    if (m.x < 0.0) m.x = -m.x;
    if (m.y < 0.0) m.y = -m.y;
    float dpx = dTube * resolution.y;
    vec2 o = vec2(3.0 + dpx * 0.9) / resolution;
    vec3 s = Texel(tex, clampUv(m)).rgb * 0.28;
    s += Texel(tex, clampUv(m + vec2(o.x, 0.0))).rgb * 0.18;
    s += Texel(tex, clampUv(m - vec2(o.x, 0.0))).rgb * 0.18;
    s += Texel(tex, clampUv(m + vec2(0.0, o.y))).rgb * 0.18;
    s += Texel(tex, clampUv(m - vec2(0.0, o.y))).rgb * 0.18;
    return s * exp(-dpx / 10.0);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec2 ar = vec2(resolution.x / max(1.0, resolution.y), 1.0);
    vec2 pp = (uv - 0.5) * ar;
    float bezelU = BEZEL_PX / max(1.0, resolution.y);
    vec2 halfExt = 0.5 * ar - bezelU;
    vec2 nn = pp / (0.5 * ar);
    vec2 ppA = pp * (1.0 + BULGE * dot(nn, nn));
    float dTube = roundedBoxSDF(ppA, halfExt, CORNER_R);
    if (false) {
        vec3 cab = cabinet(uv, pp, ppA, halfExt, dTube);

        return vec4(cab, 1.0) * color;
    }
    vec2 tuv = (pp / halfExt) * 0.5 + 0.5;
    vec2 cc = tuv - 0.5;
    float r2 = dot(cc, cc);
    vec2 curvXY = vec2(0.080, 0.105) * strength;
    vec2 suv = tuv + cc * (curvXY * r2 * 1.6 + curvXY * r2 * r2 * 9.0);
    vec2 ppI = (suv - 0.5) * 2.0 * halfExt;
    float dImg = roundedBoxSDF(ppI, halfExt, 0.045);
    if (dImg > 0.0) {
        vec3 cabI = cabinet(uv, ppI, ppI, halfExt, dImg);
        cabI += bezelSpill(tex, ppI, halfExt, dImg) * 0.45;
        return vec4(cabI, 1.0) * color;
    }
    dTube = dImg;
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        return vec4(vec3(0.012), 1.0) * color;
    }
    float edgeK = smoothstep(0.05, 0.42, r2);
    vec2 ipx = 1.0 / resolution;
    float conv = smoothstep(0.015, 0.5, r2);
    vec2 dir = cc * 2.0;
    vec2 offR = (dir * conv * 3.6 + vec2(0.0, -conv * 1.0)) * ipx * strength;
    vec2 offB = (-dir * conv * 3.0 + vec2(conv * 0.4, conv * 1.0)) * ipx * strength;
    float blurK = smoothstep(0.07, 0.48, r2);
    float rad = 3.0 * blurK * strength;
    vec2 caB = vec2(0.9 * strength * ipx.x, 0.0);
    vec3 sharp = vec3(Texel(tex, suv + offR + caB).r, Texel(tex, suv).g, Texel(tex, suv + offB - caB).b);
    vec3 soft = sharp * 0.20;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398 + 0.39;
        vec2 d = vec2(cos(a), sin(a));
        soft += Texel(tex, suv + d * rad * ipx).rgb * 0.06;
        soft += Texel(tex, suv + d * rad * 0.5 * ipx).rgb * 0.04;
    }
    vec3 rgb = mix(sharp, soft, clamp(blurK * 0.8, 0.0, 1.0));
    vec2 hpx = 2.0 / resolution;
    vec3 halo = (Texel(tex, suv + hpx).rgb + Texel(tex, suv - hpx).rgb
        + Texel(tex, suv + vec2(hpx.x, -hpx.y)).rgb
        + Texel(tex, suv + vec2(-hpx.x, hpx.y)).rgb) * 0.25;
    rgb += halo * luma(halo) * 0.10 * strength;
    float tubeRim = smoothstep(-0.035, 0.0, dTube);
    rgb *= 1.0 - 0.50 * tubeRim * tubeRim * strength;
    vec3 bloom = vec3(0.0);
    float rr1 = mix(3.0, 6.0, edgeK);
    float rr2 = mix(9.0, 18.0, edgeK);
    for (int i = 0; i < 12; i++) {
        float a = float(i) * 0.523599;
        vec2 d = vec2(cos(a), sin(a));
        vec3 s1 = Texel(tex, suv + d * rr1 * ipx).rgb;
        vec3 s2 = Texel(tex, suv + d * rr2 * ipx + d.yx * 2.0 * ipx).rgb;
        bloom += s1 * smoothstep(0.35, 0.80, luma(s1)) * 0.60 + s2 * smoothstep(0.35, 0.80, luma(s2)) * 0.40;
    }
    bloom = bloom / 12.0 * vec3(1.0, 0.88, 0.72);
    rgb += max(bloom - rgb * 0.85, vec3(0.0)) * mix(0.65, 1.1, edgeK) * strength * 1.6;
    float corner = smoothstep(0.22, 0.50, r2);
    rgb *= 1.0 - 0.22 * corner * strength;
    float lumS = clamp(luma(rgb), 0.0, 1.0);
    float ly = suv.y * resolution.y / 3.0;
    float sy = fract(ly) - 0.5;
    float bw = mix(0.22, 0.46, lumS);
    float beam = exp(-(sy * sy) / (2.0 * bw * bw));
    float scanAmt = mix(0.18, 0.55, edgeK) * strength;
    float scan = mix(1.0, beam * 1.22, scanAmt);
    float col = mod(floor(px.x), 3.0);
    vec3 stripe = vec3(0.50);
    if (col < 1.0) stripe.r = 1.0;
    else if (col < 2.0) stripe.g = 1.0;
    else stripe.b = 1.0;
    float maskAmt = mix(0.18, 0.65, edgeK) * strength;
    vec3 maskV = mix(vec3(1.0), stripe * 1.5, maskAmt) * scan;
    float dome = clamp(1.0 - (0.03 * r2 * 2.0 + 0.05 * r2 * r2 * 8.0) * strength, 0.93, 1.0);
    vec2 sheenPos = (suv - vec2(0.5, 0.24)) * vec2(1.0, 2.1);
    float sheen = exp(-dot(sheenPos, sheenPos) * 3.2) * 0.045 * strength;
    float shadowW = mix(0.05, 0.16, clamp(1.0 - tuv.y, 0.0, 1.0));
    float glassShadow = 1.0 - shadowW * strength * smoothstep(-0.020, -0.001, dTube);
    vec2 vPos = (suv - 0.5) * 0.45;
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, vignette * vignette, 0.30 * strength);
    float flicker = (1.0 - 0.008 * strength) + 0.008 * strength * sin(time * 60.0);
    float noise = (rand(suv * resolution + time * 40.0) * 0.018 - 0.009) * strength;
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
    return vec4(rgb, 1.0) * color;
}
