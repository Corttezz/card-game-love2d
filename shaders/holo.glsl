// shaders/holo.glsl
// Foil/Holo iridescente. Multi-banda rainbow + specular sweep + shimmer FBM.
// Implementação própria (não derivada do Balatro): foco em sensação Pokemon TCG /
// Magic foil — bandas que parecem reagir ao "ângulo" simulado pela posição UV.
//
// Uniforms:
//   time     (number) — segundos
//   strength (number) — 0..1 (0 desliga; rare~0.35, legendary~0.75)

extern number time;
extern number strength;

// HSV → RGB (gera arco-íris).
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Hash + value noise (compactos, separados de dissolve.glsl pra viver standalone).
float h21(vec2 p) {
    p = fract(p * vec2(91.345, 213.567));
    p += dot(p, p + 33.71);
    return fract(p.x * p.y);
}
float vn(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = h21(i);
    float b = h21(i + vec2(1.0, 0.0));
    float c = h21(i + vec2(0.0, 1.0));
    float d = h21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm2(vec2 p) {
    float v = 0.0; float a = 0.5;
    for (int i = 0; i < 3; i++) { v += a * vn(p); p *= 2.13; a *= 0.5; }
    return v;
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    // "Pseudo-normal": projeta UV centralizado pra simular curvatura de carta.
    // Resultado: gradient orientation muda conforme você se move pela superfície.
    vec2 cuv = uv - 0.5;
    float r = length(cuv);
    float angle = atan(cuv.y, cuv.x);

    // Banda 1 — diagonal lenta (movimento global suave).
    float band1 = uv.x * 1.6 + uv.y * 0.8 + time * 0.18;

    // Banda 2 — radial pulsante (foil "respirando" do centro).
    float band2 = r * 4.0 - time * 0.35;

    // Banda 3 — angular (rainbow rotaciona ao redor do centro).
    float band3 = angle / (2.0 * 3.14159265) + time * 0.05;

    // Combina em hue final (cada banda contribui pra mistura iridescente).
    float hue = fract(band1 * 0.55 + band2 * 0.25 + band3 * 0.20);

    // Saturação cai um pouco no centro (highlight branco brilhante no meio).
    float sat = mix(0.95, 0.6, smoothstep(0.0, 0.15, r));
    vec3 rainbow = hsv2rgb(vec3(hue, sat, 1.0));

    // Specular sweep: faixa diagonal brilhante que cruza a carta lentamente.
    float sweep = fract(band1 * 0.5);
    sweep = smoothstep(0.45, 0.5, sweep) * (1.0 - smoothstep(0.5, 0.55, sweep));
    vec3 specular = vec3(sweep) * 0.5;

    // Shimmer FBM: textura granular fina, animada — simula glitter holográfico.
    vec2 shimmerUV = uv * 80.0 + vec2(time * 1.3, -time * 0.9);
    float shimmer = fbm2(shimmerUV);
    shimmer = smoothstep(0.74, 0.92, shimmer);
    vec3 sparkle = vec3(shimmer) * 0.8;

    // Mix final: base recebe overlay de rainbow + specular + sparkle, escalado por strength.
    float overlayMix = strength * 0.42;
    vec3 outRgb = mix(base.rgb, rainbow, overlayMix);
    outRgb += (specular + sparkle) * strength;

    // Boost sutil de brilho geral (foil "vivo").
    outRgb = clamp(outRgb * (1.0 + strength * 0.08), 0.0, 1.6);

    return vec4(outRgb, base.a) * colour;
}
