// shaders/boot_splash.glsl — energia arcana da ENTRADA (v6, Jul/2026).
// BASEADO no princípio do splash.fs do Balatro (swirl de centro + domain-warp),
// mas TRANSFORMADO pro nosso jogo (pedido do dono: "baseado, não igual"):
//   • MÁSCARA RADIAL: a energia vive no MIOLO (em volta do sigilo da câmara)
//     e desvanece pras bordas — o fundo é a CÂMARA PIXEL ART, não o plasma.
//   • Paleta sépia/grimório: ouro + brasa-sangue sobre ink marrom (não azul).
//   • Pixels maiores (PIXEL_SIZE_FAC 300) — casa com o pixel art 4×.
//   • Swirl mais lento e coeficientes próprios (4 iterações de warp, não 5).
// Alpha final multiplica pela COR do draw (controlável do Lua).

extern number time;
extern number vort_speed;
extern vec4 colour_1;      // ouro
extern vec4 colour_2;      // brasa-sangue
extern number mid_flash;   // 0..1 → branco
extern number vort_offset;
// v7: centro do swirl ANCORADO no SIGILO da câmara (não no centro da tela) —
// offset em unidades uv (normalizado pela diagonal). A energia emana DELE.
extern vec2 center_off;
// v8: pulso de ABSORÇÃO (0..1) — cada carta engolida clareia a energia por
// dentro (nada de círculos/anéis desenhados por cima do pixel art).
extern number flare;

#define PIXEL_SIZE_FAC 300.
// base escura QUENTE (ink marrom do grimório)
#define BASE 0.6*vec4(30./255., 22./255., 16./255., 1./0.6)

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    number pixel_size = length(love_ScreenSize.xy) / PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy * (1. / pixel_size)) * pixel_size
              - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    uv -= center_off;          // centro no sigilo
    number uv_len = length(uv);

    // swirl central — mais LENTO e contido que o Balatro
    number speed = time * vort_speed;
    number ang = atan(uv.y, uv.x)
        + (1.7 + 0.35 * min(6., speed)) * uv_len - 1.
        - speed * 0.045 - min(6., speed) * speed * 0.016 + vort_offset;
    vec2 mid = (love_ScreenSize.xy / length(love_ScreenSize.xy)) / 2.;
    vec2 sv = vec2(uv_len * cos(ang) + mid.x,
                   uv_len * sin(ang) + mid.y) - mid;

    // domain-warp "fumaça" (4 iterações; coeficientes próprios)
    sv *= 26.;
    speed = time * 5. * vort_speed + vort_offset + 733.;
    vec2 uv2 = vec2(sv.x + sv.y);
    for (int i = 0; i < 4; i++) {
        uv2 += sin(max(sv.x, sv.y)) + sv;
        sv += 0.55 * vec2(cos(4.31 + 0.31 * uv2.y + speed * 0.117),
                          sin(uv2.x - 0.101 * speed));
        sv -= cos(sv.x + sv.y) - sin(sv.x * 0.63 - sv.y);
    }

    // Crescimento de densidade CAPADO em 2.0 (o original cresce até 10 rumo ao
    // flash; aqui a timeline é longa — sem o cap, aos ~7s a energia virava um
    // borrão dourado que engolia a câmara. Validado por screenshot: com 2.0 a
    // energia estabiliza como fumaça arcana em volta do sigilo).
    number smoke = min(2., max(-2., 1.5 + length(sv) * 0.11
        - 0.16 * (min(2.0, time * 1.1 - 3.))));
    if (smoke < 0.2) smoke = (smoke - 0.2) * 0.6 + 0.2;

    number c1p = max(0., 1. - 2. * abs(1. - smoke));
    number c2p = max(0., 1. - 2. * smoke);
    number cb = 1. - min(1., c1p + c2p);

    vec4 ret_col = colour_1 * c1p + colour_2 * c2p + vec4(cb * BASE.rgb, cb * colour_1.a);
    number mod_flash = max(mid_flash * 0.8, max(c1p, c2p) * 5. - 4.4)
        + mid_flash * max(c1p, c2p);
    vec4 outc = ret_col * (1. - mod_flash) + mod_flash * vec4(1., 1., 1., 1.);

    // MÁSCARA no DISCO do selo: a energia vive DENTRO do círculo entalhado
    // (portal) e some no aro — nada de blobs soltos pela tela. uv_len já é
    // relativo ao centro do selo. O flare expande/clareia levemente (pulso
    // de absorção quando uma carta é engolida).
    number edge = 1. - smoothstep(0.10 + 0.02 * flare, 0.24 + 0.03 * flare, uv_len);

    outc.rgb *= (1. + 0.65 * flare);
    return vec4(outc.rgb, outc.a * edge) * colour;
}
