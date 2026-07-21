// shaders/boot_moon_vortex.glsl — REDEMOINHO NA LUA (entrada v12).
// Mesma doutrina do seal_glow/star_twinkle: nada desenhado por cima — os
// PRÓPRIOS pixels da lua giram. Cada raio gira numa velocidade diferente
// (forte no miolo, zero na borda → a borda casa perfeita com a arte parada),
// como um portal/galáxia se agitando. Justifica as cartas serem sugadas:
// elas espiralam no mesmo movimento que a lua faz.
//
//   t          — tempo do SPLASH (bounded; getTime() enrolaria o miolo infinito)
//   moon_uv    — centro da lua em UV da textura
//   tex_size   — dimensões da arte em px (256,192)
//   radius_px  — raio do disco em px da ARTE
//   strength   — 0..1 (carga da lua + flare)

extern number t;
extern vec2 moon_uv;
extern vec2 tex_size;
extern number radius_px;
extern number strength;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec2 ap = uv * tex_size;               // posição em px da arte
    vec2 mp = moon_uv * tex_size;          // centro da lua em px da arte
    vec2 d = ap - mp;
    number r = length(d) / max(radius_px, 1.0);
    if (r > 1.0) discard;                  // fora do disco: fica a arte base

    // falloff do giro: máximo no miolo, ZERO na borda (emenda invisível)
    number fall = 1.0 - smoothstep(0.10, 0.95, r);

    // cada anel gira na própria velocidade → vórtice; velocidade cresce com
    // strength (a lua agita conforme as cartas entram)
    number ang = fall * strength * (0.55 * t + 0.8);
    number s = sin(ang);
    number c = cos(ang);
    vec2 rd = vec2(d.x * c - d.y * s, d.x * s + d.y * c);

    vec2 uv2 = (mp + rd) / tex_size;
    vec4 px = Texel(tex, uv2);

    // fade suave no aro (segurança extra além do fall=0 na borda)
    number m = 1.0 - smoothstep(0.90, 1.0, r);
    return vec4(px.rgb, px.a * m) * colour;
}
