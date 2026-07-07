// shaders/crt.glsl
// Balatro-style CRT post-processing shader para LÖVE 2D.
// Combina wave horizontal, chromatic aberration, scanlines, flicker, vignette e noise.
// Baseado em: https://gist.github.com/mar1lusk1/4677e482375bff4a01956107aef35699
//
// Uniforms:
//   time       (number) — tempo corrente em segundos (love.timer.getTime())
//   resolution (vec2)   — {width, height} em pixels
//   strength   (number) — intensidade geral 0..1 (permite toggle suave)

extern number time;
extern vec2 resolution;
extern number strength;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    // Se strength=0, retorna original (toggle barato via uniform)
    if (strength < 0.01) {
        return Texel(tex, uv) * color;
    }

    // ====== DISTORTION (horizontal wave) — REMOVIDA (Jul/2026) ======
    // A onda deslocava uv.x em BANDAS horizontais que viajavam
    // verticalmente pela tela (fase = uv.y + time). Em pixel art nearest,
    // ~1px de shift numa banda que sobe lê como "linha varrendo o
    // gramado, escurecendo/clareando fileiras" — 4 rodadas de caça no
    // GrassField até isolar que era PÓS-PROCESSAMENTO (as capturas de
    // validação não passam pelo CRT). Não reintroduzir em cena pixel art.

    // ====== CHROMATIC ABERRATION (RGB shift) — sutil ======
    float caOffset = 0.0008 * strength;
    vec4 colR = Texel(tex, uv + vec2(caOffset, 0.0));
    vec4 colG = Texel(tex, uv);
    vec4 colB = Texel(tex, uv - vec2(caOffset, 0.0));
    vec4 colorCA = vec4(colR.r, colG.g, colB.b, 1.0);

    // ====== SCANLINES ======
    float scanline = sin(uv.y * resolution.y * 1.5) * 0.025 * strength;
    float brightness = 1.0 - scanline;

    // ====== FLICKER — reduzido de 0.03 pra 0.008 (tela para de piscar rápido) ======
    float flicker = (1.0 - 0.008 * strength) + 0.008 * strength * sin(time * 60.0);

    // ====== VIGNETTE ======
    vec2 vPos = (uv - 0.5) * (0.6 + 0.4 * (1.0 - strength));
    float vignette = 1.0 - dot(vPos, vPos);
    vignette = clamp(vignette, 0.0, 1.0);
    vignette = pow(vignette, 3.0);
    // mistura vignette com identidade via strength
    vignette = mix(1.0, vignette, strength);

    // ====== NOISE — reduzido pela metade ======
    float noise = (rand(uv * resolution + time * 40.0) * 0.018 - 0.009) * strength;

    // ====== FINAL COLOR ======
    colorCA.rgb *= brightness * flicker * vignette;
    colorCA.rgb += noise;

    return colorCA * color;
}
