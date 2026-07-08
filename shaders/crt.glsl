// shaders/crt.glsl — CRT v3 "A Crônica no Tubo" (Jul/2026)
// O jogo vive num televisor: GABINETE procedural visível (plástico escuro
// com relevo, lábio com brilho na abertura, sombra do vidro recuado —
// referência do dono: mockup pixelbuddha), tubo com curvatura de domo,
// power físico (ligar/desligar SÓ apaga o vidro — a TV continua ali),
// tremidinha ocasional, grille/scanlines/halation.
// Matemática própria — plano: docs/plan/crt-identity-v1.md.
//
// Uniforms:
//   time       (number) — segundos correntes
//   resolution (vec2)   — {w, h} px
//   strength   (number) — intensidade da identidade 0..1
//   power      (number) — estado do tubo: 0=desligado, 1=ligado
//   glitch/glitchY      — tremidinha ocasional (agendada em Lua)
//
// HERANÇA: NUNCA reintroduzir distorção viajante (trauma do GrassField).
// REGRA v2.3: legibilidade > efeito — escurecimento sobre conteúdo é mínimo.

extern number time;
extern vec2 resolution;
extern number strength;
extern number power;
extern number glitch;
extern number glitchY;

// Largura do gabinete em px (a moldura vive AQUI, fora do conteúdo).
const float BEZEL_PX = 26.0;

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

    // ====== GEOMETRIA DA JANELA: gabinete + abertura do tubo ======
    vec2 ar = vec2(resolution.x / max(1.0, resolution.y), 1.0);
    vec2 pp = (uv - 0.5) * ar;
    float bezelU = BEZEL_PX / max(1.0, resolution.y);
    float cornerR = 0.012;   // v3.2: canto pequeno de gabinete real
    vec2 halfExt = 0.5 * ar - bezelU;
    // v3.2 (intuição do dono, fisicamente correta): a abertura da moldura
    // ACOMPANHA a curvatura convexa do vidro — as arestas fazem um leve
    // arco pra fora no meio de cada lado. SDF avaliado em espaço com
    // pincushion leve = abertura bojada como o tubo.
    vec2 nn = pp / (0.5 * ar);
    float rrA = dot(nn, nn);
    vec2 ppA = pp * (1.0 + 0.016 * rrA);
    float dTube = roundedBoxSDF(ppA, halfExt, cornerR);

    // ====== GABINETE v3.1: tronco de pirâmide com 4 FACETAS ======
    // A moldura de um CRT real é um frustum: facetas trapezoidais
    // (topo/base/esq/dir) inclinadas até o vidro recuado, encontrando-se
    // em JUNTAS DIAGONAIS de 45° nos vértices (miter, como moldura de
    // quadro). Cada faceta tem iluminação própria (luz de cima-esquerda).
    if (dTube > 0.0) {
        vec3 plastic = vec3(0.115, 0.104, 0.095);

        // penetração além do retângulo interno, por eixo (>0 na moldura)
        vec2 aPen = abs(ppA) - halfExt;
        aPen = max(aPen, vec2(0.0));

        // FACETA por penetração dominante + iluminação própria
        float facetLum;
        if (aPen.x > aPen.y) {
            facetLum = (pp.x < 0.0) ? 0.98 : 0.78;   // esq clara / dir média
        } else {
            facetLum = (pp.y < 0.0) ? 0.55 : 1.22;   // topo SOMBRA / base LUZ
        }

        // JUNTA de 45° nos vértices: linha escura onde as facetas se
        // encontram (a "linha com sombra" da referência do dono).
        float seam = 0.0;
        if (aPen.x > 0.0005 && aPen.y > 0.0005) {
            float dSeam = abs(aPen.x - aPen.y);
            seam = 1.0 - smoothstep(0.0, 0.0018, dSeam);
            // some perto da abertura (colidia com o arco do canto)
            seam *= smoothstep(0.004, 0.011, dTube);
        }

        vec3 cab = plastic * facetLum;
        // textura fina de plástico (estática)
        cab *= 0.95 + 0.10 * rand(floor(uv * resolution * 0.5));
        // junta escura + micro-realce do lado iluminado da junta
        cab *= 1.0 - 0.22 * seam;

        // RANHURA escura onde o vidro senta (anel fino colado na abertura)
        float groove = smoothstep(0.0045, 0.0, dTube);
        cab *= 1.0 - 0.55 * groove;

        // LÁBIO especular POR FACETA logo após a ranhura: forte na base
        // (pega a luz), nulo no topo (assimetria que vende o recesso)
        float lipZone = smoothstep(0.013, 0.0045, dTube)
            * (1.0 - smoothstep(0.0045, 0.0, dTube));
        float lipStrength;
        if (aPen.x > aPen.y) lipStrength = (pp.x < 0.0) ? 0.5 : 0.35;
        else lipStrength = (pp.y < 0.0) ? 0.06 : 0.9;
        cab += vec3(0.20, 0.19, 0.175) * lipZone * lipStrength;

        // face externa: leve escurecimento até a borda da janela
        vec2 wq = abs(uv - 0.5) * 2.0;
        cab *= 1.0 - 0.30 * pow(max(wq.x, wq.y), 10.0);

        return vec4(cab, 1.0) * color;
    }

    // ====== COORDENADAS DO TUBO (0..1 dentro da abertura) ======
    vec2 tuv = (pp / halfExt) * 0.5 + 0.5;

    // ====== POWER: warm-up/colapso SÓ no vidro (a TV fica visível) ======
    float p = clamp(power, 0.0, 1.0);
    float surge = 1.0;
    float hotline = 0.0;
    if (p < 0.999) {
        float vScale = 1.0;
        float hScale = 1.0;
        if (p < 0.02) {
            // vidro apagado: reflexo fraco do ambiente pra não ser breu
            vec2 og = tuv - vec2(0.5, 0.3);
            float offGlow = 0.012 + 0.02 * exp(-dot(og, og) * 3.0);
            return vec4(vec3(offGlow), 1.0) * color;
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
        tuv.x = 0.5 + (tuv.x - 0.5) / hScale;
        tuv.y = 0.5 + (tuv.y - 0.5) / vScale;
        if (tuv.x < 0.0 || tuv.x > 1.0 || tuv.y < 0.0 || tuv.y > 1.0) {
            return vec4(vec3(0.012), 1.0) * color;
        }
    }

    // ====== DOMO: curvatura r² + r⁴ (centro plano, cantos fechados) ======
    vec2 cc = tuv - 0.5;
    float r2 = dot(cc, cc);
    vec2 curvXY = vec2(0.045, 0.062) * strength;
    vec2 suv = tuv + cc * (curvXY * r2 * 1.6 + curvXY * r2 * r2 * 7.0);
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        return vec4(vec3(0.012), 1.0) * color;
    }

    // ====== TREMIDINHA (sync jitter ocasional — evento discreto) ======
    if (glitch > 0.001) {
        float band = exp(-pow((suv.y - glitchY) * 22.0, 2.0));
        float lineNoise = rand(vec2(floor(suv.y * resolution.y), floor(time * 90.0)));
        suv.x += (lineNoise - 0.5) * 0.006 * glitch * band;
        suv.y += (rand(vec2(floor(time * 60.0), 7.0)) - 0.5) * 0.0016 * glitch;
    }

    // ====== ABERRAÇÃO CROMÁTICA (cresce com a distância do centro) ======
    float caOffset = (0.0006 + 0.0022 * r2 * 4.0) * strength;
    vec4 colR = Texel(tex, suv + vec2(caOffset, 0.0));
    vec4 colG = Texel(tex, suv);
    vec4 colB = Texel(tex, suv - vec2(caOffset, 0.0));
    vec3 rgb = vec3(colR.r, colG.g, colB.b);

    // ====== HALATION (brilho sangrando) ======
    vec2 hpx = 2.0 / resolution;
    vec3 halo = Texel(tex, suv + hpx).rgb + Texel(tex, suv - hpx).rgb
        + Texel(tex, suv + vec2(hpx.x, -hpx.y)).rgb
        + Texel(tex, suv + vec2(-hpx.x, hpx.y)).rgb;
    halo *= 0.25;
    float haloLum = dot(halo, vec3(0.299, 0.587, 0.114));
    rgb += halo * haloLum * 0.10 * strength;

    // ====== SCANLINES + INTERLACE SHIMMER + GRILLE RGB ======
    float frameParity = mod(floor(time * 60.0), 2.0);
    float lineParity = mod(floor(suv.y * resolution.y * 0.5) + frameParity, 2.0);
    float shimmer = 1.0 - lineParity * 0.012 * strength;
    float scan = 1.0 - sin(suv.y * resolution.y * 1.5) * 0.035 * strength;
    float triad = mod(px.x, 3.0);
    vec3 grille = vec3(1.0);
    grille.r += (triad < 1.0 ? 0.05 : -0.03) * strength;
    grille.g += (triad >= 1.0 && triad < 2.0 ? 0.05 : -0.03) * strength;
    grille.b += (triad >= 2.0 ? 0.05 : -0.03) * strength;

    // ====== RELEVO POR LUZ (v2.3: legibilidade > efeito) ======
    float dome = 1.0 - (0.05 * r2 * 2.0 + 0.10 * r2 * r2 * 8.0) * strength;
    dome = clamp(dome, 0.85, 1.0);
    vec2 sheenPos = (suv - vec2(0.5, 0.24)) * vec2(1.0, 2.1);
    float sheen = exp(-dot(sheenPos, sheenPos) * 3.2) * 0.045 * strength;

    // sombra do vidro recuado — DIRECIONAL: a moldura de cima projeta
    // mais sombra no vidro (0.28 topo → 0.08 base), como na referência.
    float shadowW = mix(0.08, 0.28, clamp(1.0 - tuv.y, 0.0, 1.0));
    float glassShadow = 1.0 - shadowW * strength
        * smoothstep(-0.020, -0.001, dTube);

    // ====== VIGNETTE + FLICKER + NOISE ======
    vec2 vPos = (suv - 0.5) * 0.45;
    float vignette = clamp(1.0 - dot(vPos, vPos), 0.0, 1.0);
    vignette = mix(1.0, pow(vignette, 2.0), 0.55 * strength);
    float flicker = (1.0 - 0.008 * strength)
        + 0.008 * strength * sin(time * 60.0);
    float noise = (rand(suv * resolution + time * 40.0) * 0.018 - 0.009)
        * strength;

    // ====== COMPOSIÇÃO ======
    rgb *= grille * scan * shimmer * flicker * vignette * dome * glassShadow;
    rgb += sheen;
    rgb += noise;
    rgb *= surge;
    rgb = mix(rgb, vec3(1.0, 0.98, 0.92), hotline * 0.85);

    return vec4(rgb, 1.0) * color;
}
