// shaders/holo.glsl
// Brilho das cartas raras/lendárias (src/ui/HoloShader.lua) — v2, Out/2026.
//
// A v1 (Abr/2026) era um arco-íris multi-banda misturado na carta INTEIRA,
// animado o tempo todo. Nunca tinha sido vista em jogo (o load() não era
// chamado); quando foi ligada, lavava a cor da arte e punha a mesma listra em
// todas as cartas — contra duas regras do dono: "idle = estático" e "foil que
// lava a cor, nunca".
//
// v2 = REFLEXO, não sobreposição de cor:
//   • só acende no ARO da carta (silhueta medida pelo alpha: faixa de 6 px,
//     meia-luz até 9 px) e, DENTRO da faixa de varredura, nos pixels de
//     brilho da arte (luminância alta — metal, papel claro). O resto da
//     ilustração sai IDÊNTICO ao texel: nada de hue-shift sobre a arte.
//   • ADITIVO (base + tinta × quantidade), nunca mix — a matiz da arte fica.
//   • varredura em DEGRAUS na grade de pixels da carta (núcleo 2 px, meia-luz
//     2 px, rastro em dither 2x2), diagonal "\" como a da carta inédita.
//     Só se move com `anim` > 0 (hover/selecionada); em repouso é estática.
//   • rara (kind 0) = glint prata-azulado; lendária (kind 1) = dourado
//     prismático (3 matizes em degraus ao longo da faixa).
//
// Uniforms:
//   time     (number) — segundos (só move a faixa quando anim > 0)
//   strength (number) — 0..1 (rara ~0.25 no hover; lendária 0.08 repouso → 0.5)
//   kind     (number) — 0 rara, 1 lendária
//   anim     (number) — 0..1 (hover/selecionada)
//   cardSize (vec2)   — tamanho da textura em px (grade da arte)

extern number time;
extern number strength;
extern number kind;
extern number anim;
extern vec2 cardSize;

float bayer2(vec2 p) {
    float i = mod(p.x, 2.0) + mod(p.y, 2.0) * 2.0;
    if (i == 0.0) return 0.125;
    if (i == 1.0) return 0.625;
    if (i == 2.0) return 0.875;
    return 0.375;
}

// 1 se algum vizinho a `d` px (4 direções) é transparente — ou seja, o pixel
// está a menos de `d` px da borda da silhueta.
float nearEdge(Image tex, vec2 uv, vec2 ts, float d) {
    float a = 1.0;
    a = min(a, Texel(tex, uv + vec2( d, 0.0) * ts).a);
    a = min(a, Texel(tex, uv + vec2(-d, 0.0) * ts).a);
    a = min(a, Texel(tex, uv + vec2(0.0,  d) * ts).a);
    a = min(a, Texel(tex, uv + vec2(0.0, -d) * ts).a);
    return (a < 0.5) ? 1.0 : 0.0;
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.005) {
        return base * colour;
    }
    vec2 ts = 1.0 / cardSize;
    vec2 px = floor(uv * cardSize);

    // aro: cheio até 6 px da borda, meia-luz até 9
    float frame = 0.0;
    if (nearEdge(tex, uv, ts, 6.0) > 0.5) frame = 1.0;
    else if (nearEdge(tex, uv, ts, 9.0) > 0.5) frame = 0.5;

    // brilhos da arte (só contam dentro da faixa de varredura)
    float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    float hi = (frame <= 0.0 && lum > 0.74) ? 0.7 : 0.0;

    // faixa de varredura em degraus, diagonal "\" (desce 2 px por coluna)
    float band = 0.0;
    if (anim > 0.001) {
        float span = cardSize.x + cardSize.y * 0.5 + 60.0;
        float pos = mod(time * 34.0, span) - 30.0;
        float d = (px.x + floor(px.y * 0.5)) - pos;
        float ad = abs(d);
        if (ad < 2.0) band = 1.0;
        else if (ad < 4.0) band = 0.5;
        else if (d < 0.0 && ad < 10.0) {
            float k = 1.0 - (ad - 4.0) / 6.0;
            if (k > bayer2(px)) band = 0.3;
        }
    }

    // aro: 0.6 × força (rara no hover 0.15, lendária 0.05 em repouso → 0.3) —
    // com 0.35 o glint prata da rara sumia dentro do dourado da moldura e
    // rara/lendária só se distinguiam pela faixa. Faixa: 1.2 × força.
    float amt = strength * (frame * 0.6 + max(frame, hi) * band * anim * 1.2);
    if (amt <= 0.0) return base * colour;

    vec3 tint = (kind < 0.5) ? vec3(0.78, 0.88, 1.0) : vec3(1.0, 0.86, 0.50);
    if (kind > 0.5 && band > 0.0) {
        // lendária: prismático em degraus ao longo da faixa
        float h = mod(floor((px.x + px.y * 0.5) / 6.0), 3.0);
        tint = (h == 0.0) ? vec3(1.0, 0.85, 0.45)
             : (h == 1.0) ? vec3(1.0, 0.62, 0.72) : vec3(0.58, 0.95, 0.90);
    }
    vec3 outRgb = min(base.rgb + tint * amt, vec3(1.0));
    return vec4(outRgb, base.a) * colour;
}
