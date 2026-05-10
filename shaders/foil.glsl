// shaders/foil.glsl
// Edition "Foil" — brilho metálico frio, sem cores rainbow (vs Holo).
// Faixa de luz cinzenta-azul deslizando lentamente + ruído metálico fino.
//
// Uniforms:
//   time     (number) — segundos
//   strength (number) — 0..1 (default 0.6)

extern number time;
extern number strength;

float fh21(vec2 p) {
    p = fract(p * vec2(83.51, 287.13));
    p += dot(p, p + 19.81);
    return fract(p.x * p.y);
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    // Faixa diagonal: gradiente que desliza com tempo.
    float diag = uv.x * 1.4 + uv.y * 0.9 + time * 0.25;
    float strip = sin(diag * 3.14159);
    // Pulso metálico: claro nas cristas das ondas.
    float metallic = 0.5 + 0.5 * strip;

    // Highlight estreito (faixa "sweep" viajando).
    float sweep = fract(diag * 0.5);
    sweep = smoothstep(0.42, 0.50, sweep) * (1.0 - smoothstep(0.50, 0.58, sweep));

    // Cor metálica fria: prata azulada.
    vec3 silver = vec3(0.78, 0.84, 0.95);
    vec3 highlightColor = vec3(1.0, 1.0, 1.05);

    // Ruído fino — granulação metálica.
    float grain = fh21(floor(uv * 280.0));
    grain = (grain - 0.5) * 0.18;

    // Mix: base + camada metálica + sweep + grain.
    vec3 outRgb = base.rgb;
    outRgb = mix(outRgb, silver, strength * 0.30 * metallic);
    outRgb += highlightColor * sweep * strength * 0.55;
    outRgb += vec3(grain) * strength * 0.4;

    // Boost de luminância sutil.
    outRgb = clamp(outRgb * (1.0 + strength * 0.05), 0.0, 1.4);

    return vec4(outRgb, base.a) * colour;
}
