// shaders/negative.glsl
// Edition "Negative" — cores invertidas + halo branco/escuro pulsante.
// Carta "raríssima" com vibe sombria/fantasmagórica.
//
// Uniforms:
//   time     (number) — segundos
//   strength (number) — 0..1 (default 1.0; quase sempre full)

extern number time;
extern number strength;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    // Inverte cor preservando luminosidade percebida.
    vec3 inv = vec3(1.0) - base.rgb;

    // Mix com base preta-azulada pra parecer "espectral" (não negativo médico).
    vec3 ghost = mix(inv, vec3(0.05, 0.06, 0.12), 0.35);

    // Pulso sutil: brilho global oscila lento.
    float pulse = 0.85 + 0.15 * sin(time * 1.6);
    ghost *= pulse;

    // Halo branco nas bordas pra destacar.
    vec2 cuv = uv - 0.5;
    float r = length(cuv);
    float halo = smoothstep(0.42, 0.55, r) * (1.0 - smoothstep(0.55, 0.7, r));
    ghost += vec3(halo * 0.6 * strength);

    // Strength faz lerp entre original e negativo.
    vec3 outRgb = mix(base.rgb, ghost, strength);

    return vec4(outRgb, base.a) * colour;
}
