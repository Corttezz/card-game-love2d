// shaders/flash.glsl
// Flash branco fullscreen com pulse radial opcional. Implementação própria.
//
// Modos:
//   • mid_flash > 0 → overlay branco; intensidade 0..1 controla opacidade.
//   • Pulse radial sutil cresce do centro pra borda usando time como animador.
//
// Uniforms:
//   time      (number) — segundos desde o início (alimenta a animação radial)
//   mid_flash (number, 0..1) — intensidade global do flash (envelope externo)

extern number time;
extern number mid_flash;

vec4 effect(vec4 colour, Image texture, vec2 tc, vec2 sc) {
    if (mid_flash <= 0.001) discard;

    // UV centralizado pixel-perfect com aspect compensado.
    vec2 res = love_ScreenSize.xy;
    vec2 uv = (sc - 0.5 * res) / max(res.x, res.y);
    float r = length(uv);

    // Pulse radial: anel branco que expande conforme time cresce, com soft edge.
    // Funciona como "ring expanding" sobreposto ao flash global.
    float ring = 0.0;
    if (time > 0.0) {
        float ringR = clamp(time * 0.55, 0.0, 0.9);
        float thick = 0.18;
        ring = smoothstep(ringR + thick, ringR, r) * (1.0 - smoothstep(ringR + 2.0 * thick, ringR + thick, r));
        ring *= 0.5;
    }

    // Vinheta inversa: centro mais branco que borda no flash inicial.
    float center = 1.0 - smoothstep(0.0, 0.7, r);

    // Mistura final.
    float a = mid_flash * (0.55 + 0.45 * center) + ring * mid_flash;
    a = clamp(a, 0.0, 1.0);

    return vec4(1.0, 1.0, 1.0, a);
}
