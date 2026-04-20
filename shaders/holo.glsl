// shaders/holo.glsl
// Foil/Holo effect para cartas de raridade "rare" e "legendary".
// Aplica gradiente arco-íris animado modulado por noise metálico.
// Funciona como um "overlay" sobre a textura da carta, preservando transparência.
//
// Uniforms:
//   time     (number) — tempo em segundos
//   strength (number) — intensidade 0..1 (0 desliga; rare=0.35, legendary=0.75)

extern number time;
extern number strength;

// HSV → RGB (para gerar arco-íris)
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * color;
    }

    // Gradiente arco-íris diagonal animado
    float hue = fract(uv.x * 0.7 + uv.y * 0.3 + time * 0.15);
    vec3 rainbow = hsv2rgb(vec3(hue, 0.85, 1.0));

    // Noise metálico para shimmer
    float n = rand(floor(uv * 96.0) + time * 0.5);
    float shimmer = smoothstep(0.85, 1.0, n) * strength;

    // Mix: base + gradiente rainbow com intensidade `strength`
    vec3 holo = mix(base.rgb, rainbow, strength * 0.35);
    // Adiciona pontos brancos aleatórios (sparkle)
    holo += vec3(shimmer * 0.8);

    return vec4(holo, base.a) * color;
}
