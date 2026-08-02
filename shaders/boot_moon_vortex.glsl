// shaders/boot_moon_vortex.glsl — PORTAL NA LUA (entrada v14).
// v12 girava os PRÓPRIOS pixels do disco — rotação de pixel art vira sopa
// borrada/serrilhada (feedback do dono: "o estranho é a lua em si").
// v14: a arte da lua fica INTACTA; por cima, BRAÇOS DE ESPIRAL luminosos
// procedurais (espiral logarítmica, 2 braços — casa com a correnteza das
// cartas) travados na GRADE do pixel art (floor no px da arte = bandas
// chunky, não gradiente liso), + um OLHO de dreno escurecendo no centro.
// Lê como portal respirando, não liquidificador.
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
    // trava no GRID do pixel art: o padrão é calculado no CENTRO do texel —
    // braços em degraus chunky, coerentes com a arte
    vec2 ap = floor(uv * tex_size) + 0.5;
    vec2 mp = moon_uv * tex_size;
    vec2 d = ap - mp;
    number r = length(d) / max(radius_px, 1.0);
    if (r > 1.0) discard;                  // fora do disco: fica a arte base

    vec4 px = Texel(tex, uv);              // arte INTACTA (base do composite)

    // ===== BRAÇOS DE ESPIRAL (logarítmica: aperta pro centro) =====
    number theta = atan(d.y, d.x);
    // 2 braços; ln(r) dá o enrolar log; gira com o tempo (sentido = cartas)
    number phase = 2.0 * theta + 5.0 * log(max(r, 0.05)) - t * 2.4;
    number arm = sin(phase);
    // bandas discretas (pixel art: liga/desliga com degrau curto)
    number arms = smoothstep(0.35, 0.75, arm);
    // presença: some na borda (emenda invisível) e cresce pro miolo
    number fall = 1.0 - smoothstep(0.20, 0.95, r);
    // cintilação leve ao longo do braço (vida, sem virar ruído)
    number shimmer = 0.85 + 0.15 * sin(phase * 3.0 + t * 1.7);

    // Num disco quase BRANCO, braço aditivo não aparece (satura) — a
    // estrutura vem da SOMBRA: os VÃOS entre os braços escurecem (sombra
    // quente de âmbar), os braços ficam na luz natural + toque dourado.
    number gaps = 1.0 - arms;
    px.rgb *= 1.0 - gaps * fall * strength * 0.30
        * vec3(0.85, 1.0, 1.15);   // esfria levemente a sombra (contraste)
    vec3 glowCol = mix(vec3(1.0, 0.82, 0.48), vec3(1.0, 0.98, 0.90), fall);
    px.rgb += glowCol * arms * fall * shimmer * strength * 0.15;

    // ===== OLHO DO DRENO: centro escurece (a boca do portal) =====
    number eye = 1.0 - smoothstep(0.03, 0.17, r);
    px.rgb *= 1.0 - 0.50 * eye * strength;
    // aro fino de luz na borda do olho (o limiar do portal)
    number rim = smoothstep(0.10, 0.16, r) * (1.0 - smoothstep(0.16, 0.24, r));
    px.rgb += vec3(1.0, 0.95, 0.80) * rim * strength * 0.35;

    return px * colour;
}
