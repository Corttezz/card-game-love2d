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
// Tremidinha ocasional (agendada em Lua — CRTShader.update):
//   glitch  = intensidade 0..1 do evento corrente (0 = estável)
//   glitchY = centro vertical da banda instável (0..1)
extern number glitch;
extern number glitchY;

// SDF de retângulo arredondado (cantos de tubo PERFEITOS — círculo real,
// não superelipse). p centrado, b = meia-extensão, r = raio do canto.
float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

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

    // ====== MÁSCARA DE TUBO: SDF de retângulo arredondado ======
    // Aspecto corrigido → cantos CIRCULARES de verdade (CRT-Geom cornersize).
    vec2 ar = vec2(resolution.x / max(1.0, resolution.y), 1.0);
    vec2 pp = (buv - 0.5) * ar;
    float cornerR = 0.085 * strength + 0.015;   // cantos generosos de tubo
    float dTube = roundedBoxSDF(pp, 0.5 * ar - 0.004, cornerR);
    float tubeMask = 1.0 - smoothstep(-0.004, 0.002, dTube);
    if (tubeMask <= 0.0) {
        return vec4(0.0, 0.0, 0.0, 1.0) * color;
    }
    // sombra de bezel encostada na borda do tubo
    float bezel = 1.0 - 0.32 * strength
        * smoothstep(-0.10, -0.002, dTube);

    // ====== UNDERSCAN (revisão de telas, Jul/2026) ======
    // O CONTEÚDO INTEIRO ocupa a área interna segura do tubo — a máscara e
    // a curvatura comem só a moldura preta, NUNCA mana/vida/HUD nos cantos.
    float inset = 1.0 - 0.045 * strength;
    vec2 suv = (buv - 0.5) / inset + 0.5;
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0) * color * vec4(vec3(tubeMask), 1.0);
    }

    // ====== TREMIDINHA (sync jitter ocasional — RetroArch/CRT-Geom) ======
    // Banda horizontal estreita desloca X por algumas linhas durante um
    // evento raro (~0.15s a cada 4-9s, agendado em Lua). DIFERENTE da onda
    // viajante banida: é um EVENTO discreto de instabilidade, não um padrão
    // constante varrendo a cena.
    if (glitch > 0.001) {
        float band = exp(-pow((suv.y - glitchY) * 22.0, 2.0));
        float lineNoise = rand(vec2(floor(suv.y * resolution.y), floor(time * 90.0)));
        suv.x += (lineNoise - 0.5) * 0.006 * glitch * band;
        // micro-hiccup vertical de quadro inteiro no auge do evento
        suv.y += (rand(vec2(floor(time * 60.0), 7.0)) - 0.5)
            * 0.0016 * glitch;
    }

    // ====== ABERRAÇÃO CROMÁTICA (cresce com a distância do centro) ======
    float caOffset = (0.0006 + 0.0022 * r2 * 4.0) * strength;
    vec4 colR = Texel(tex, suv + vec2(caOffset, 0.0));
    vec4 colG = Texel(tex, suv);
    vec4 colB = Texel(tex, suv - vec2(caOffset, 0.0));
    vec3 rgb = vec3(colR.r, colG.g, colB.b);

    // ====== HALATION (brilho sangrando — CRT-Interlaced-Halation) ======
    vec2 hpx = 2.0 / resolution;
    vec3 halo = Texel(tex, suv + hpx).rgb + Texel(tex, suv - hpx).rgb
        + Texel(tex, suv + vec2(hpx.x, -hpx.y)).rgb
        + Texel(tex, suv + vec2(-hpx.x, hpx.y)).rgb;
    halo *= 0.25;
    float haloLum = dot(halo, vec3(0.299, 0.587, 0.114));
    rgb += halo * haloLum * 0.10 * strength;

    // ====== SCANLINES + INTERLACE SHIMMER + GRILLE RGB ======
    // shimmer: paridade da linha alterna levemente por quadro (30Hz de
    // vida — imperceptível parado, "respira" em movimento).
    float frameParity = mod(floor(time * 60.0), 2.0);
    float lineParity = mod(floor(suv.y * resolution.y * 0.5) + frameParity, 2.0);
    float shimmer = 1.0 - lineParity * 0.012 * strength;
    float scan = 1.0 - sin(suv.y * resolution.y * 1.5) * 0.035 * strength;
    float triad = mod(px.x, 3.0);
    vec3 grille = vec3(1.0);
    grille.r += (triad < 1.0 ? 0.05 : -0.03) * strength;
    grille.g += (triad >= 1.0 && triad < 2.0 ? 0.05 : -0.03) * strength;
    grille.b += (triad >= 2.0 ? 0.05 : -0.03) * strength;

    // ====== VIGNETTE + FLICKER + NOISE ======
    vec2 vPos = (suv - 0.5) * (0.62 + 0.38 * (1.0 - strength));
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, pow(vignette, 3.0), strength);
    float flicker = (1.0 - 0.008 * strength)
        + 0.008 * strength * sin(time * 60.0);
    float noise = (rand(suv * resolution + time * 40.0) * 0.018 - 0.009)
        * strength;

    // ====== COMPOSIÇÃO ======
    rgb *= grille * scan * shimmer * flicker * vignette * bezel * tubeMask;
    rgb += noise;
    rgb *= surge;
    // linha quente do warm-up: o fósforo satura pra branco
    rgb = mix(rgb, vec3(1.0, 0.98, 0.92), hotline * 0.85);

    return vec4(rgb, 1.0) * color;
}
