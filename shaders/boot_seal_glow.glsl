// shaders/boot_seal_glow.glsl — CARGA DO SELO (entrada v9, Jul/2026).
// Nada de textura por cima do pixel art: este shader redesenha A PRÓPRIA ARTE
// em blend aditivo, realçando só os pixels CLAROS (entalhes/inlay dourado)
// dentro do disco do selo. Efeito: o selo "carrega" — os sulcos acendem e
// respiram, pulsam a cada carta absorvida e estouram no flash. 100% pixel-
// nativo (o glow É a arte), coeso com o resto da tela.
//
//   center   — centro do selo em px de TELA
//   radius   — raio do disco em px de TELA (falloff suave até a borda)
//   strength — 0..1 intensidade (respiração + flare vêm do Lua)

extern vec2 center;
extern number radius;
extern number strength;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 px = Texel(tex, uv);

    // máscara radial do disco do selo (some suave na borda)
    number d = length(sc - center) / max(radius, 1.0);
    number m = 1.0 - smoothstep(0.55, 1.0, d);

    // só o que já é CLARO na arte acende (entalhes, inlay) — pedra escura não
    number lum = dot(px.rgb, vec3(0.35, 0.5, 0.15));
    number hi = max(0.0, lum - 0.18) / 0.82;

    vec3 glow = vec3(1.0, 0.84, 0.48) * hi * m * strength;
    return vec4(glow, 1.0) * colour;   // blend "add": soma glow por cima
}
