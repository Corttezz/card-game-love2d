// shaders/light_dither.glsl
// Sprite de luz do LightEngine: falloff radial (1-d²)² POSTERIZADO em degraus
// + dither Bayer 4x4 opcional, alinhado ao pixel do LIGHTMAP (canvas 1/4 —
// screen_coords aqui são os pixels do render target ativo).
// Desenhado num quad branco 2x2 escalado (UV [0,1]) com blend "add".
// Bayer via if-chain: o GLSL do LÖVE (compat ES/1.20) não aceita
// inicializador de array const (padrão glsl-dither/hughsk).

extern number levels;      // degraus de posterização (4 = poça; 2 = pequena)
extern number useDither;   // 1.0 = Bayer (só poças de chão); 0.0 = sem dither
extern number intensity;   // multiplicador 0..1 aplicado ANTES da posterização

float bayer4(vec2 sc) {
    int x = int(mod(sc.x, 4.0));
    int y = int(mod(sc.y, 4.0));
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
    vec2 p = uv * 2.0 - 1.0;                     // [-1,1] no quad da luz
    float i = clamp(1.0 - dot(p, p), 0.0, 1.0);
    i = i * i;                                   // falloff (1-d²)²
    i = i * intensity;
    float thr = mix(0.5, bayer4(sc), useDither);
    i = floor(i * levels + thr) / levels;        // quantiza (+ dither)
    if (i <= 0.0) discard;
    return vec4(color.rgb * i, 1.0);
}
