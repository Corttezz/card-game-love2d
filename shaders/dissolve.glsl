// shaders/dissolve.glsl
// Dissolve / materialize mask para cartas. Substitui a textura por um campo
// de noise "queimando" da borda pro centro (dissolve) ou do centro pra borda
// (materialize, via dissolve=1→0). Opcional: burn colors colorem a borda da
// queima — tipo "chamas em papel".
//
// PORTED FROM: resources/shaders/dissolve.fs do Balatro 1.0.1o (adaptado
// pra LÖVE 11.5 sem os prefixos MY_HIGHP_OR_MEDIUMP e sem o path vertex/hover).
// ⚠️  Este código é copyright LocalThunk/Playstack. Uso: estudo pessoal.
//     Antes de shippar o jogo, reescreva a matemática de raiz ou substitua
//     por um dissolve próprio (noise texture + threshold é suficiente).
//
// Uniforms:
//   dissolve       (number, 0..1)  — 0 opaco, 1 sumiu. 0.5 = metade queimada.
//   time           (number)        — tempo em segundos (pra campo animado)
//   texture_details(vec4)          — (pos.x, pos.y, size.x, size.y) do quad do atlas.
//                                    Pra textura inteira: (0, 0, w, h).
//   image_details  (vec2)          — (image.w, image.h) em pixels
//   burn_colour_1  (vec4, opcional) — cor da borda queimada (ex: laranja)
//   burn_colour_2  (vec4, opcional) — cor secundária (ex: vermelho escuro)
//   shadow         (bool)          — se true, tudo vira sombra preta

extern number dissolve;
extern number time;
extern vec4 texture_details;
extern vec2 image_details;
extern bool shadow;
extern vec4 burn_colour_1;
extern vec4 burn_colour_2;

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0, 0.0, 0.0) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }

    // smoothstep → remapeia dissolve pra saturar melhor nas bordas 0 e 1
    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;

    float t = time * 10.0 + 2003.0;
    vec2 floored_uv = (floor((uv * texture_details.ba))) / max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    // 3 campos senoidais combinados → noise orgânico que parece papel queimando
    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483)
        + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73)
        + cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    // res é o valor do campo naquele pixel. A borda dissolve primeiro
    // (penalty nos 4 cantos quando dissolve cresce)
    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * (dissolve)
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * (dissolve)
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * (dissolve)
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * (dissolve);

    // Burn colors: banda colorida na frente da dissolução (chamas na borda)
    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow
        && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5))
        && res > adjusted_dissolve) {
        if (!shadow
            && res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5))
            && res > adjusted_dissolve) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(
        shadow ? vec3(0.0, 0.0, 0.0) : tex.xyz,
        res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0
    );
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;

    // Tint da textura em direção à burn color enquanto dissolve cresce
    if (!shadow && dissolve > 0.01) {
        if (burn_colour_2.a > 0.01) {
            tex.rgb = tex.rgb * (1.0 - 0.6 * dissolve) + 0.6 * burn_colour_2.rgb * dissolve;
        } else if (burn_colour_1.a > 0.01) {
            tex.rgb = tex.rgb * (1.0 - 0.6 * dissolve) + 0.6 * burn_colour_1.rgb * dissolve;
        }
    }

    return dissolve_mask(tex, texture_coords, uv);
}
