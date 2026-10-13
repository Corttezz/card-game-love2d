// shaders/posterize.glsl — POSTERIZA um canvas em `levels` degraus por canal
// (cor e alpha) com dither Bayer 4×4 na grade de `block` px de tela.
//
// Uso (BossCinematic, névoa colorida da cinemática de chefe): a névoa é a
// soma de dezenas de puffs translúcidos e o resultado da soma é um
// gradiente LISO ("forma vetorial suave", a cara de IA que o dono aponta em
// pixel art). Desenhada num canvas e composta por aqui, vira degraus na
// grade da arte, como a bruma do WeatherEngine e a poça da lanterna da loja.
// Matemática própria (Bayer recursivo 2×2 → 4×4), nada copiado.

extern number levels;   // degraus por canal (4)
extern number block;    // lado do bloco de dither em px de tela (pixel da arte)

float bayer2(float x, float y) {
    // [[0,2],[3,1]] / 4
    return (3.0 * y + (2.0 - 4.0 * y) * x) / 4.0;
}

float bayer4(vec2 p) {
    vec2 q = floor(p / max(block, 1.0));
    float x0 = mod(q.x, 2.0), y0 = mod(q.y, 2.0);
    float x1 = mod(floor(q.x / 2.0), 2.0), y1 = mod(floor(q.y / 2.0), 2.0);
    // M4 = (4*M2(x%2,y%2) + M2(x/2%2,y/2%2)) / 16, já normalizado em 0..1
    return (bayer2(x0, y0) * 4.0 + bayer2(x1, y1)) / 4.0;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv);
    float d = bayer4(sc) - 0.5;           // -0.5..0.5: limiar deslocado por bloco
    float L = max(levels, 1.0);
    c.rgb = floor(c.rgb * L + d + 0.5) / L;
    c.a   = floor(c.a   * L + d + 0.5) / L;
    return c * color;
}
