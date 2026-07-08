// shaders/occluder.glsl
// Oclusor de silhueta do LightEngine: usa SÓ o ALPHA da textura pra recortar
// o formato e pinta uma COR CHAPADA (flat) — nunca a cor interna do sprite.
//
// BUG que isso corrige: desenhar o sprite com setColor multiplicava
// ambiente × cor-do-sprite no lightmap; no multiply final virava
// sprite × (ambiente × cor) = COR AO QUADRADO → partes escuras do dono
// (corpo do monstro, tronco de árvore) esmagavam pra quase preto. Com a
// cor chapada, o lightmap na silhueta = flat (ambiente ou ambiente×lift),
// e o dono fica em sprite × flat = cor padrão levantada, sem esmagar.

extern vec3 flatColor;   // cor chapada ('flat' é palavra reservada GLSL!)

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float a = Texel(tex, uv).a;
    if (a < 0.5) discard;
    return vec4(flatColor, 1.0);
}
