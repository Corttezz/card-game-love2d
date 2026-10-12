// shaders/discovery_sweep.glsl
// Varredura de luz da carta INÉDITA (src/ui/DiscoveryMark.lua). Desenhada em
// modo "add" por cima da carta, pelo MESMO mesh do card_perspective — o vertex
// shader é o mesmo warp, então a luz acompanha o tilt do hover.
//
// A luz mora na GRADE DE PIXELS da carta (96x144): a faixa é diagonal em
// degraus inteiros, núcleo cheio, meia-luz e um rastro em dither Bayer 2x2 —
// nada de gradiente liso (forma vetorial lisa sobre arte pixel lê como
// "cara de IA"). Só acende onde a carta é opaca: segue a silhueta da moldura.
//
// Uniforms:
//   mouse, hover, time, cardSize — idem card_perspective.glsl
//   sweep    (number) — posição da faixa ao longo da diagonal (px da carta)
//   strength (number) — 0..1
//   tint     (vec3)   — cor da luz

extern vec2 mouse;
extern number hover;
extern number time;
extern vec2 cardSize;
extern number sweep;
extern number strength;
extern vec3 tint;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 uv = vertex_position.xy / cardSize;
    vec2 centered = uv - vec2(0.5);
    float proj = dot(centered, mouse);
    float pressAmount = -proj * hover * 0.12;
    float wobble = sin(time * 2.0 + centered.x * 4.0) * 0.005 * hover
                 + cos(time * 1.7 + centered.y * 4.0) * 0.005 * hover;
    vec2 warped = vertex_position.xy + centered * cardSize * (pressAmount + wobble);
    return transform_projection * vec4(warped, vertex_position.zw);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    vec4 t = Texel(tex, uv);
    if (t.a < 0.5) return vec4(0.0);
    vec2 px = floor(uv * cardSize);
    // diagonal "\" inclinada: desce 2 px por coluna
    float d = (px.x + floor(px.y * 0.5)) - sweep;
    float ad = abs(d);
    float a = 0.0;
    if (ad < 2.0) {
        a = 1.0;
    } else if (ad < 4.0) {
        a = 0.5;
    } else if (d < 0.0 && ad < 12.0) {
        // rastro: densidade cai com a distância, em dither 2x2
        float k = 1.0 - (ad - 4.0) / 8.0;
        float bx = mod(px.x, 2.0);
        float by = mod(px.y, 2.0);
        float thr = (bx + by * 2.0 == 0.0) ? 0.125
                  : (bx + by * 2.0 == 1.0) ? 0.625
                  : (bx + by * 2.0 == 2.0) ? 0.875 : 0.375;
        if (k > thr) a = 0.3;
    }
    // pega mais nos claros (papel, metal) que na tinta
    float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    a *= (0.45 + 0.55 * lum) * strength;
    return vec4(tint, a) * color;
}
#endif
