// shaders/flash.glsl
// Flash branco pixelado — usado em impactos, buffs aplicados, booster opening.
// Overlay que escurece p/ branco total no pico e some.
//
// PORTED FROM: resources/shaders/flash.fs do Balatro 1.0.1o.
// ⚠️  Copyright LocalThunk/Playstack. Uso: estudo pessoal. Substitua antes de shippar.
//
// Uniforms:
//   time      (number) — segundos desde o início do flash
//   mid_flash (number, 0..1) — intensidade (0 desligado; 1 pico)

extern number time;
extern number mid_flash;

#define PIXEL_SIZE_FAC 700.0

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Pixeliza baseado no tamanho da tela (look "16-bit flash")
    number pixel_size = length(love_ScreenSize.xy) / PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size
        - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);

    // Crescimento do branco do centro pra borda em 2 pulsos
    float mid_white = min(1.0,
        (time > 2.5 ? max(0.0, sqrt(time - 2.5) - 60.0 * length(uv)) : 0.0)
        + (time > 11.0 ? max(0.0, (time - 11.0) * (time - 11.0) - 5.0 * length(uv)) : 0.0)
    );

    return vec4(1.0, 1.0, 1.0, mid_flash * mid_white);
}
