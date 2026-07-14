// shaders/boot_splash.glsl — fundo da ENTRADA no estilo Balatro (v5, Jul/2026).
// Adaptado (NÃO copiado) de balatro-source/resources/shaders/splash.fs: swirl de
// centro + domain-warp "fumaça" (5 iterações) → plasma suave e orgânico. Trocada
// a paleta azul/branco do Balatro pela nossa SÉPIA/GRIMÓRIO (ouro + pergaminho
// sobre ink escuro). É o fundo SUAVE e profissional — sem foto distorcida, sem
// raio, sem flicker. `mid_flash` leva a cena ao branco no clímax.

extern number time;
extern number vort_speed;
extern vec4 colour_1;      // ouro
extern vec4 colour_2;      // pergaminho claro
extern number mid_flash;   // 0..1 → branco
extern number vort_offset;

#define PIXEL_SIZE_FAC 480.
// base escura QUENTE (ink marrom) no lugar do teal do Balatro
#define BASE 0.6*vec4(38./255., 28./255., 20./255., 1./0.6)

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    number pixel_size = length(love_ScreenSize.xy) / PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy * (1. / pixel_size)) * pixel_size
              - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    number uv_len = length(uv);

    number speed = time * vort_speed;
    number new_pixel_angle = atan(uv.y, uv.x)
        + (2.2 + 0.4 * min(6., speed)) * uv_len - 1.
        - speed * 0.05 - min(6., speed) * speed * 0.02 + vort_offset;
    vec2 mid = (love_ScreenSize.xy / length(love_ScreenSize.xy)) / 2.;
    vec2 sv = vec2(uv_len * cos(new_pixel_angle) + mid.x,
                   uv_len * sin(new_pixel_angle) + mid.y) - mid;

    sv *= 30.;
    speed = time * 6. * vort_speed + vort_offset + 1033.;
    vec2 uv2 = vec2(sv.x + sv.y);
    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(sv.x, sv.y)) + sv;
        sv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121),
                         sin(uv2.x - 0.113 * speed));
        sv -= 1.0 * cos(sv.x + sv.y) - 1.0 * sin(sv.x * 0.711 - sv.y);
    }

    number smoke_res = min(2., max(-2., 1.5 + length(sv) * 0.12
        - 0.17 * (min(10., time * 1.2 - 4.))));
    if (smoke_res < 0.2) {
        smoke_res = (smoke_res - 0.2) * 0.6 + 0.2;
    }

    number c1p = max(0., 1. - 2. * abs(1. - smoke_res));
    number c2p = max(0., 1. - 2. * smoke_res);
    number cb = 1. - min(1., c1p + c2p);

    vec4 ret_col = colour_1 * c1p + colour_2 * c2p + vec4(cb * BASE.rgb, cb * colour_1.a);
    number mod_flash = max(mid_flash * 0.8, max(c1p, c2p) * 5. - 4.4)
        + mid_flash * max(c1p, c2p);

    return ret_col * (1. - mod_flash) + mod_flash * vec4(1., 1., 1., 1.);
}
