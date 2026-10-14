extern vec2 booster;
extern number dissolve;
extern number time;
extern vec4 texture_details;
extern vec2 image_details;
extern bool shadow;
extern vec4 burn_colour_1;
extern vec4 burn_colour_2;
extern vec3 sheen;
extern number sheen_amt;

float bh21(vec2 p) {
    p = fract(p * vec2(117.81, 271.07));
    p += dot(p, p + 51.91);
    return fract(p.x * p.y);
}
float bvn(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = bh21(i);
    float b = bh21(i + vec2(1.0, 0.0));
    float c = bh21(i + vec2(0.0, 1.0));
    float d = bh21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float bfbm(vec2 p) {
    float v = 0.0; float a = 0.55;
    for (int i = 0; i < 3; i++) { v += a * bvn(p); p *= 2.07; a *= 0.5; }
    return clamp(v, 0.0, 1.0);
}

vec3 bhsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float dissolveMask(vec2 uv, float dis) {
    if (dis < 0.001) return 1.0;
    vec2 cuv = uv - 0.5;
    float radial = length(cuv) * 1.42;
    vec2 nuv = uv * 5.5 + vec2(time * 0.07, time * 0.045);
    float n = bfbm(nuv);
    n += 0.08 * sin(uv.x * 9.0 + time * 0.6) * cos(uv.y * 7.0 - time * 0.5);
    n = clamp(n, 0.0, 1.0);
    float biased = dis + (radial - 0.5) * 0.35 * dis;
    return smoothstep(biased - 0.01, biased + 0.01, n);
}

vec4 effect(vec4 colour, Image texture, vec2 tc, vec2 sc) {
    vec4 px = Texel(texture, tc);
    vec2 quadSize = max(texture_details.zw, vec2(1.0));
    vec2 uv = (tc * image_details - texture_details.xy) / quadSize;
    uv = clamp(uv, 0.0, 1.0);

    float phase = booster.x;

    float cyc = fract(phase * 0.11);
    float sweeping = step(cyc, 0.30);
    float center = mix(-0.25, 1.25, clamp(cyc / 0.30, 0.0, 1.0));
    float proj = uv.x * 0.80 + uv.y * 0.35;
    float band = (1.0 - smoothstep(0.0, 0.16, abs(proj - center))) * sweeping;
    band *= band;

    float hue = fract(uv.x * 0.6 + uv.y * 0.25 + phase * 0.15);
    vec3 rainbow = bhsv2rgb(vec3(hue, 0.40, 1.0));
    vec3 tint = mix(rainbow, rainbow * (0.35 + 0.65 * sheen) + sheen * 0.30, 0.85);

    float lum = dot(px.rgb, vec3(0.299, 0.587, 0.114));
    float take = 0.05 + 0.95 * lum;

    vec2 shUV = uv * 90.0 + vec2(phase * 1.7, -phase * 1.1);
    float sh = smoothstep(0.86, 0.97, bfbm(shUV)) * band;

    float amt = clamp(sheen_amt, 0.0, 1.0);
    vec3 iridescent = px.rgb + tint * (band * 0.45 * take * amt) + vec3(sh * 0.30 * amt);

    iridescent = clamp(iridescent, 0.0, 1.4);

    float baseAlpha = px.a;

    float dmask = dissolveMask(uv, dissolve);

    if (shadow) {
        return vec4(0.0, 0.0, 0.0, baseAlpha * dmask * 0.3);
    }

    if (dissolve > 0.001 && burn_colour_1.a > 0.01) {
        vec2 nuv = uv * 5.5 + vec2(time * 0.07, time * 0.045);
        float n = bfbm(nuv);
        vec2 cuvb = uv - 0.5;
        float radial = length(cuvb) * 1.42;
        float biased = dissolve + (radial - 0.5) * 0.35 * dissolve;
        float burnBand = 0.10;
        float bandT = clamp((n - biased) / burnBand, 0.0, 1.0);
        float bandIntensity = (1.0 - bandT) * (1.0 - bandT);
        if (bandIntensity > 0.01 && dmask > 0.01) {
            vec3 burnRgb = burn_colour_1.rgb;
            if (burn_colour_2.a > 0.01) burnRgb = mix(burn_colour_1.rgb, burn_colour_2.rgb, bandT);
            iridescent = mix(iridescent, burnRgb, bandIntensity * burn_colour_1.a);
        }
    }

    return vec4(iridescent, baseAlpha * dmask) * colour;
}
