// shaders/dissolve.glsl
// Dissolve / materialize com value noise FBM + threshold animado + edge glow.
// Implementação própria — não derivada do código do Balatro.
//
// Algoritmo:
//   1) Calcula UV centralizado (0..1) e distância radial pra centro.
//   2) FBM (4 oitavas de value noise hash-based) lentamente animado em time.
//   3) threshold = dissolve com bias radial (cantos saem antes do centro).
//   4) Pixels com noise < threshold são "queimados" (alpha=0).
//   5) Banda fina ao redor do threshold recebe burn_colour_1/2 (chama).
//   6) Tint global em direção a burn_colour_2 conforme dissolve cresce.
//
// Uniforms expostos (compat com src/ui/DissolveShader.lua):
//   dissolve        (number, 0..1)  — 0 visível, 1 sumiu.
//   time            (number)        — segundos (fonte de animação)
//   texture_details (vec4)          — (off_x, off_y, w, h) em pixels do quad
//   image_details   (vec2)          — (image.w, image.h) — não usado, mantido p/ compat
//   shadow          (bool)          — true → tudo vira sombra preta semitransparente
//   burn_colour_1   (vec4)          — cor primária da chama (banda interna)
//   burn_colour_2   (vec4)          — cor secundária (banda externa)

extern number dissolve;
extern number time;
extern vec4 texture_details;
extern vec2 image_details;
extern bool shadow;
extern vec4 burn_colour_1;
extern vec4 burn_colour_2;
// Escala do campo de noise em CÉLULAS por eixo. (0,0) = legado (5.5 iso,
// cartas). Quads muito largos (banner full-width) passam escala anisotrópica
// pra célula ficar ~quadrada em pixels — sem isso a queima vira "faixas
// fantasmas" esticadas em vez de buracos de fogo.
extern vec2 noise_scale;

// Hash 2D → escalar [0..1). Sem dependência de textura de noise.
float dh21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 41.32);
    return fract(p.x * p.y);
}

// Value noise com smoothstep nas células (bilinear suave).
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = dh21(i);
    float b = dh21(i + vec2(1.0, 0.0));
    float c = dh21(i + vec2(0.0, 1.0));
    float d = dh21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// FBM: 4 oitavas, peso decrescente, freq dobrando.
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.55;
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p = p * 2.07 + vec2(11.3, 7.7);
        amp *= 0.5;
    }
    return clamp(v, 0.0, 1.0);
}

vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc) {
    vec4 px = Texel(tex, tc);

    // Curto-circuito quando totalmente visível.
    if (dissolve < 0.001) {
        if (shadow) return vec4(0.0, 0.0, 0.0, px.a * 0.3);
        return px * colour;
    }

    // UV normalizado (0..1) dentro do quad mesmo se for atlas region.
    vec2 quadSize = max(texture_details.zw, vec2(1.0));
    vec2 uv = (tc * image_details - texture_details.xy) / quadSize;
    uv = clamp(uv, 0.0, 1.0);

    // Distância radial 0..~0.71 → bias pra cantos (sai antes).
    vec2 cuv = uv - 0.5;
    float radial = length(cuv) * 1.42;  // ~1 nos cantos

    // Campo FBM lentamente animado. Coords escaladas pra granularidade média.
    vec2 nscale = (noise_scale.x > 0.0) ? noise_scale : vec2(5.5, 5.5);
    vec2 nuv = uv * nscale + vec2(time * 0.07, time * 0.045);
    float n = fbm(nuv);

    // Pequena ondulação extra pra borda mais "viva" (não copia 3-sines do Balatro).
    n += 0.08 * sin(uv.x * 9.0 + time * 0.6) * cos(uv.y * 7.0 - time * 0.5);
    n = clamp(n, 0.0, 1.0);

    // Threshold com bias: dissolve efetivo cresce mais nas bordas.
    // Quando dissolve=1, threshold sempre > n: tudo sumiu.
    float biased = dissolve + (radial - 0.5) * 0.35 * dissolve;
    float threshold = biased;

    // Banda de queima: largura proporcional, mas mínima fixa pra não sumir
    // visualmente quando dissolve está em 0.95+.
    float band = 0.10 + 0.06 * (1.0 - abs(dissolve - 0.5) * 2.0);

    // Mask binária com smoothstep curto pra antialiasing nas bordas pixel-art-friendly.
    float mask = smoothstep(threshold - 0.01, threshold + 0.01, n);

    // Modo sombra: cor preta semitransparente, ainda mascarada.
    if (shadow) {
        return vec4(0.0, 0.0, 0.0, px.a * mask * 0.3);
    }

    // Tint global em direção à cor secundária (suave, mais forte conforme dissolve).
    vec3 base = px.rgb;
    if (burn_colour_2.a > 0.01) {
        base = mix(base, burn_colour_2.rgb, dissolve * 0.45 * burn_colour_2.a);
    } else if (burn_colour_1.a > 0.01) {
        base = mix(base, burn_colour_1.rgb, dissolve * 0.35 * burn_colour_1.a);
    }

    // Banda colorida na frente do front da queima.
    // 0..1 dentro da banda, 0 fora.
    float bandT = clamp((n - threshold) / band, 0.0, 1.0);
    float bandIntensity = (1.0 - bandT) * (1.0 - bandT);  // mais forte na borda

    if (burn_colour_1.a > 0.01 && mask > 0.01 && bandIntensity > 0.01) {
        // Mix das duas cores: c1 na borda mais quente, c2 no anel externo.
        vec3 burnRgb = burn_colour_1.rgb;
        if (burn_colour_2.a > 0.01) {
            burnRgb = mix(burn_colour_1.rgb, burn_colour_2.rgb, bandT);
        }
        base = mix(base, burnRgb, bandIntensity * burn_colour_1.a);
    }

    return vec4(base, px.a * mask) * colour;
}
