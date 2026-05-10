// shaders/booster.glsl
// Embalagem iridescente pra booster packs. Implementação própria — combina:
//   • Tint azul-prateado base (papel metalizado).
//   • Hue iridescente que varia com UV + tempo (multi-banda).
//   • Specular sweep diagonal lento.
//   • FBM shimmer fino.
//   • Mask de dissolve compartilhado (mesma matemática do dissolve.glsl novo).
//
// Não é derivado do código do Balatro.
//
// Uniforms (compat com src/ui/BoosterShader.lua):
//   booster        (vec2)   — (phase, _) — phase é fase da animação (segundos)
//   dissolve       (number) — 0..1 (0 visível, 1 sumiu)
//   time           (number) — segundos absolutos
//   texture_details(vec4)   — (off_x, off_y, w, h)
//   image_details  (vec2)   — (image.w, image.h)
//   shadow         (bool)
//   burn_colour_1, burn_colour_2 (vec4)

extern vec2 booster;
extern number dissolve;
extern number time;
extern vec4 texture_details;
extern vec2 image_details;
extern bool shadow;
extern vec4 burn_colour_1;
extern vec4 burn_colour_2;

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

// Mask de dissolve. Mesma ideia do dissolve.glsl mas inline pra não depender
// do shader externo (evita require glsl).
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

    // Luminosidade base — preserva contraste do desenho original.
    float low  = min(px.r, min(px.g, px.b));
    float high = max(px.r, max(px.g, px.b));
    float delta = max(high - low, low * 0.7);

    // Hue iridescente: combinação de UV diagonal + radial + fase booster.
    float phase = booster.x;
    vec2 cuv = uv - 0.5;
    float r = length(cuv);
    float angle = atan(cuv.y, cuv.x);

    float band1 = uv.x * 1.7 + uv.y * 0.6 + phase * 0.22;
    float band2 = r * 5.0 - phase * 0.5;
    float band3 = angle / 6.2832 + phase * 0.06;

    float hue = fract(band1 * 0.55 + band2 * 0.25 + band3 * 0.20);
    vec3 rainbow = bhsv2rgb(vec3(hue, 0.65, 1.0));

    // Mix overlay: preserva 70% da cor original e camada iridescente sobre
    // pra que a textura do sleeve PixelLab seja reconhecível.
    vec3 iridescent = px.rgb * 0.70 + rainbow * 0.30 * (0.4 + 0.6 * delta);

    // Specular sweep lento (faixa diagonal brilhante).
    float sweep = fract(uv.x * 0.9 + uv.y * 0.4 + phase * 0.15);
    float sweepBand = smoothstep(0.46, 0.50, sweep) * (1.0 - smoothstep(0.50, 0.54, sweep));
    iridescent += vec3(sweepBand * 0.30);

    // Shimmer FBM grão fino (glitter sutil).
    vec2 shUV = uv * 90.0 + vec2(phase * 1.7, -phase * 1.1);
    float sh = bfbm(shUV);
    sh = smoothstep(0.82, 0.95, sh);
    iridescent += vec3(sh * 0.40);

    iridescent = clamp(iridescent, 0.0, 1.4);

    // Alpha original modulado por luminosidade pra preservar transparência.
    float baseAlpha = px.a * (0.78 + 0.22 * (low + delta));

    // Apply dissolve mask.
    float dmask = dissolveMask(uv, dissolve);

    if (shadow) {
        return vec4(0.0, 0.0, 0.0, baseAlpha * dmask * 0.3);
    }

    // Banda de queima quando dissolve ativo.
    if (dissolve > 0.001 && burn_colour_1.a > 0.01) {
        vec2 nuv = uv * 5.5 + vec2(time * 0.07, time * 0.045);
        float n = bfbm(nuv);
        vec2 cuvb = uv - 0.5;
        float radial = length(cuvb) * 1.42;
        float biased = dissolve + (radial - 0.5) * 0.35 * dissolve;
        float band = 0.10;
        float bandT = clamp((n - biased) / band, 0.0, 1.0);
        float bandIntensity = (1.0 - bandT) * (1.0 - bandT);
        if (bandIntensity > 0.01 && dmask > 0.01) {
            vec3 burnRgb = burn_colour_1.rgb;
            if (burn_colour_2.a > 0.01) burnRgb = mix(burn_colour_1.rgb, burn_colour_2.rgb, bandT);
            iridescent = mix(iridescent, burnRgb, bandIntensity * burn_colour_1.a);
        }
    }

    return vec4(iridescent, baseAlpha * dmask) * colour;
}
