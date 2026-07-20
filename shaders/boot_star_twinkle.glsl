// shaders/boot_star_twinkle.glsl — CINTILAÇÃO das estrelas (entrada v11).
// Mesmo princípio da carga da lua: redesenha A PRÓPRIA ARTE em blend aditivo,
// mas só os pixels MUITO claros do CÉU (as estrelas) ganham reforço — e cada
// estrela pisca no seu próprio ritmo (fase pseudo-aleatória derivada da
// posição do pixel na ARTE, então a estrela inteira pisca coerente).
// A lua é excluída (ela tem a própria respiração via boot_seal_glow) e as
// colinas também (rim-light dourado não deve piscar).

extern number t;
extern vec2 moon_center;    // px de TELA
extern number moon_radius;  // px de TELA
extern vec2 art_off;        // offset do cover (tela -> arte)
extern number art_scale;    // escala do cover
extern number sky_limit;    // y na ARTE abaixo do qual não há estrela (colinas)

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 px = Texel(tex, uv);

    // só pixels MUITO claros (estrelas; nuvens/pedra ficam de fora)
    number lum = dot(px.rgb, vec3(0.35, 0.5, 0.15));
    number hi = smoothstep(0.60, 0.85, lum);

    // exclui a lua (disco + halo)
    number dm = length(sc - moon_center) / max(moon_radius, 1.0);
    number outside_moon = smoothstep(0.95, 1.30, dm);

    // exclui as colinas (rim-light não pisca)
    vec2 ap = floor((sc - art_off) / max(art_scale, 0.001));
    number sky = 1.0 - smoothstep(sky_limit - 6.0, sky_limit + 2.0, ap.y);

    // fase própria por pixel da arte -> cada estrela tem ritmo/offset únicos
    number ph = fract(sin(dot(ap, vec2(12.9898, 78.233))) * 43758.5453);
    number tw = 0.5 + 0.5 * sin(t * (1.2 + 2.6 * ph) + ph * 6.2831);

    vec3 add = px.rgb * (hi * outside_moon * sky * tw * 0.9);
    return vec4(add, 1.0) * colour;   // blend "add"
}
