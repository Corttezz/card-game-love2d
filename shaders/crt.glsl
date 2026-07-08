// shaders/crt.glsl — CRT v2 "A Crônica no Tubo" (Jul/2026)
// O jogo inteiro vive num televisor de tubo: máscara de cantos
// arredondados (superelipse), curvatura de vidro (barrel), sombra de
// bezel, grille RGB, scanlines, aberração cromática nas bordas, ruído,
// e o ESTADO FÍSICO do tubo (power 0..1: ligar/desligar com linha quente).
// Matemática própria — plano: docs/plan/crt-identity-v1.md.
//
// Uniforms:
//   time       (number) — segundos correntes
//   resolution (vec2)   — {w, h} px
//   strength   (number) — intensidade da identidade 0..1
//   power      (number) — estado do tubo: 0=desligado, 1=ligado
//
// HERANÇA IMPORTANTE: a onda horizontal viajante foi REMOVIDA (4 rodadas
// de caça a "bug" no GrassField até isolar que era o CRT). A curvatura
// barrel é ESTÁTICA — nunca reintroduzir distorção que viaja.

extern number time;
extern vec2 resolution;
extern number strength;
extern number power;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    if (strength < 0.01 && power > 0.99) {
        return Texel(tex, uv) * color;
    }

    // ====== POWER: estado físico do tubo (warm-up / colapso) ======
    // p<0.35: linha horizontal crescendo do centro (vScale mínimo)
    // p<0.85: abertura vertical (ease quadrático)
    // p<1.0 : assentamento com overshoot de brilho
    float p = clamp(power, 0.0, 1.0);
    float vScale = 1.0;
    float hScale = 1.0;
    float surge  = 1.0;
    float hotline = 0.0;   // 1 = linha branca quente domina
    if (p < 0.999) {
        if (p < 0.02) {
            return vec4(0.0, 0.0, 0.0, 1.0) * color;
        } else if (p < 0.35) {
            float k = (p - 0.02) / 0.33;
            hScale = max(0.02, k);
            vScale = 0.006;
            surge  = 2.4;
            hotline = 1.0;
        } else if (p < 0.85) {
            float k = (p - 0.35) / 0.5;
            k = k * k;
            vScale = 0.006 + 0.994 * k;
            surge  = 1.9 - 0.7 * k;
            hotline = clamp(1.0 - vScale * 12.0, 0.0, 1.0);
        } else {
            float k = (p - 0.85) / 0.15;
            surge = 1.2 - 0.2 * k;
        }
    }
    vec2 puv;
    puv.x = 0.5 + (uv.x - 0.5) / hScale;
    puv.y = 0.5 + (uv.y - 0.5) / vScale;
    if (puv.x < 0.0 || puv.x > 1.0 || puv.y < 0.0 || puv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0) * color;
    }

    // ====== BARREL: curvatura de vidro (estática) ======
    vec2 cc = puv - 0.5;
    float r2 = dot(cc, cc);
    float curv = 0.035 * strength;
    vec2 buv = puv + cc * r2 * curv * 2.4;

    // ====== MÁSCARA DE TUBO: superelipse (cantos arredondados REAIS) ======
    vec2 q = abs(buv - 0.5) * 2.0;
    float corner = pow(pow(q.x, 8.0) + pow(q.y, 8.0), 0.125);
    float tubeMask = 1.0 - smoothstep(0.985 - 0.035 * strength, 1.0, corner);
    if (tubeMask <= 0.0 || buv.x < 0.0 || buv.x > 1.0
        || buv.y < 0.0 || buv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0) * color;
    }
    // sombra de bezel encostada na borda do tubo
    float bezel = 1.0 - 0.35 * strength
        * smoothstep(0.80, 0.995, corner);

    // ====== ABERRAÇÃO CROMÁTICA (cresce com a distância do centro) ======
    float caOffset = (0.0006 + 0.0022 * r2 * 4.0) * strength;
    vec4 colR = Texel(tex, buv + vec2(caOffset, 0.0));
    vec4 colG = Texel(tex, buv);
    vec4 colB = Texel(tex, buv - vec2(caOffset, 0.0));
    vec3 rgb = vec3(colR.r, colG.g, colB.b);

    // ====== SCANLINES + GRILLE RGB (máscara de fósforo sutil) ======
    float scan = 1.0 - sin(buv.y * resolution.y * 1.5) * 0.035 * strength;
    float triad = mod(px.x, 3.0);
    vec3 grille = vec3(1.0);
    grille.r += (triad < 1.0 ? 0.05 : -0.03) * strength;
    grille.g += (triad >= 1.0 && triad < 2.0 ? 0.05 : -0.03) * strength;
    grille.b += (triad >= 2.0 ? 0.05 : -0.03) * strength;

    // ====== VIGNETTE + FLICKER + NOISE ======
    vec2 vPos = (buv - 0.5) * (0.62 + 0.38 * (1.0 - strength));
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, pow(vignette, 3.0), strength);
    float flicker = (1.0 - 0.008 * strength)
        + 0.008 * strength * sin(time * 60.0);
    float noise = (rand(buv * resolution + time * 40.0) * 0.018 - 0.009)
        * strength;

    // ====== COMPOSIÇÃO ======
    rgb *= grille * scan * flicker * vignette * bezel * tubeMask;
    rgb += noise;
    rgb *= surge;
    // linha quente do warm-up: o fósforo satura pra branco
    rgb = mix(rgb, vec3(1.0, 0.98, 0.92), hotline * 0.85);

    return vec4(rgb, 1.0) * color;
}
