// shaders/reveal_stage.glsl
// PALCO da revelação (components/UnlockShowcase.lua): o brilho atrás do item
// desbloqueado, vivendo na GRADE DE PIXELS da arte — nada de gradiente liso
// nem triângulo vetorial girando (os "raios dourados" v1 eram isso, e o dono
// chamou de "muito tosco").
//
// Tudo é avaliado POR CÉLULA de `cell` px (2 px virtuais = 1 px da arte das
// cartas): o halo radial é posterizado em `levels` degraus com dither Bayer
// 4x4 na célula, e os raios são espinhos de UMA célula de largura com
// decaimento em 3 degraus (cheio / meio / pontilhado). Girar `rot` move os
// espinhos em saltos de célula — borda dura, sem anti-alias.
//
// Desenhado num quad branco 1x1 escalado pra `size` com blend alpha.
//
// Uniforms:
//   size    (vec2)   — lado do quad em px (locais ao transform corrente)
//   cell    (number) — célula da grade em px
//   levels  (number) — degraus do halo (4)
//   rays    (number) — nº de espinhos (12); rayOn 0 desliga (reducedMotion)
//   rot     (number) — rotação dos espinhos (rad)
//   rayOn   (number) — 1 = espinhos ligados
//   pulse   (number) — multiplicador do halo (respiração; 1 = parado)
//   glowCol (vec3)   — cor do halo
//   rayCol  (vec3)   — cor dos espinhos

extern vec2 size;
extern number cell;
extern number levels;
extern number rays;
extern number rot;
extern number rayOn;
extern number pulse;
extern vec3 glowCol;
extern vec3 rayCol;

// Bayer 4x4 por if-chain (o GLSL do LÖVE não aceita array const inicializado).
float bayer4(vec2 c) {
    int x = int(mod(c.x, 4.0));
    int y = int(mod(c.y, 4.0));
    int i = x + y * 4;
    if (i ==  0) return 0.0625;
    if (i ==  1) return 0.5625;
    if (i ==  2) return 0.1875;
    if (i ==  3) return 0.6875;
    if (i ==  4) return 0.8125;
    if (i ==  5) return 0.3125;
    if (i ==  6) return 0.9375;
    if (i ==  7) return 0.4375;
    if (i ==  8) return 0.25;
    if (i ==  9) return 0.75;
    if (i == 10) return 0.125;
    if (i == 11) return 0.625;
    if (i == 12) return 1.0;
    if (i == 13) return 0.5;
    if (i == 14) return 0.875;
    return 0.375;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 g = floor(uv * size / cell);              // índice da célula
    vec2 c = (g + 0.5) * cell - size * 0.5;        // centro da célula, rel. ao centro
    float R = min(size.x, size.y) * 0.5;
    float dist = length(c);
    float d = dist / R;                            // 0 no centro, 1 na borda
    if (d > 0.96) discard;                         // o quad é quadrado; o halo não
    // Bayer COMPRIMIDO (0.125..0.875): o limiar cheio (1.0) acendia 1 célula em
    // 16 onde o halo já era zero — um pontilhado regular no quad inteiro.
    float b = 0.5 + (bayer4(g) - 0.5) * 0.75;

    // halo: (1-d²)² posterizado + dither na célula
    float h = clamp(1.0 - d * d, 0.0, 1.0);
    h = h * h * pulse;
    float hq = floor(h * levels + b) / levels;

    // espinhos: 1 célula de largura, decaem em 3 degraus com dither
    float ray = 0.0;
    if (rayOn > 0.5 && d > 0.16 && d < 0.98) {
        float sector = 6.2831853 / rays;
        float ang = atan(c.y, c.x) + rot;
        float off = mod(ang + sector * 0.5, sector) - sector * 0.5;
        float perp = abs(off) * dist;              // px até a linha do espinho
        // 2 células perto do item, 1 na ponta (afina como um raio de sol)
        if (perp < cell * (d < 0.55 ? 1.5 : 0.75)) {
            float f = clamp((1.0 - d) * 1.25, 0.0, 1.0);
            ray = floor(f * 3.0 + b) / 3.0;
        }
    }

    float ha = hq * 0.65;
    float ra = ray * 0.85;
    if (ha <= 0.0 && ra <= 0.0) discard;
    vec3 col = (ra > ha) ? rayCol : glowCol;
    float a = max(ha, ra);
    return vec4(col, a) * color;
}
