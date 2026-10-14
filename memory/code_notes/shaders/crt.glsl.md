---
name: code_notes/shaders/crt.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/crt.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/crt.glsl`

Origem: `shaders/crt.glsl` em `7dbdb60d` (20 de 59 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `extern number time;`)

> shaders/crt.glsl — CRT v3 "A Crônica no Tubo" (Jul/2026)
> O jogo vive num televisor: GABINETE procedural visível (plástico escuro
> com relevo, lábio com brilho na abertura, sombra do vidro recuado —
> referência do dono: mockup pixelbuddha), tubo com curvatura de domo,
> power físico (ligar/desligar SÓ apaga o vidro — a TV continua ali),
> tremidinha ocasional, grille/scanlines/halation.
> Matemática própria — plano: docs/plan/crt-identity-v1.md.
>
> Uniforms:
> time       (number) — segundos correntes
> resolution (vec2)   — {w, h} px
> strength   (number) — intensidade da identidade 0..1
> power      (number) — estado do tubo: 0=desligado, 1=ligado
> glitch/glitchY      — tremidinha ocasional (agendada em Lua)
>
> HERANÇA: NUNCA reintroduzir distorção viajante (trauma do GrassField).
> REGRA v2.3: legibilidade > efeito — escurecimento sobre conteúdo é mínimo.

## L26-28 (junto a `extern number degrade;`)

> SURTO de TV velha (v3.8): 0 = sinal limpo (baseline legível); 1 = pico
> do surto — vinheta/CA/ruído/flicker sobem e uma hum bar rola. Agendado
> em Lua (CRTShader.update: a cada 8-20s por 0.6-2s, envelope suave).

## L30-34 (junto a `extern vec4 calmRect;`)

> ZONA DE LEITURA (Loja v5, briefing: "reduza a aberração cromática sobre
> textos pequenos, valores e descrições"): retângulo em px do CONTEÚDO
> (x, y, w, h; w <= 0 = nenhuma) onde a aberração e o surto somem, com
> borda suave de 24 px. Curvatura, scanlines e grille continuam (são a
> identidade, não borram letra). CRTShader.setCalmRect, zerado a cada quadro.

## L60 (junto a `float cornerR = 0.012;`)

> v3.2: canto pequeno de gabinete real

## L62-65 (junto a `vec2 nn = pp / (0.5 * ar);`)

> v3.2 (intuição do dono, fisicamente correta): a abertura da moldura
> ACOMPANHA a curvatura convexa do vidro — as arestas fazem um leve
> arco pra fora no meio de cada lado. SDF avaliado em espaço com
> pincushion leve = abertura bojada como o tubo.

## L68 (junto a `vec2 ppA = pp * (1.0 + 0.042 * rrA);`)

> v3.4: bojo PERCEPTÍVEL

## L71-75 (junto a `if (dTube > 0.0) {`)

> ====== GABINETE v3.1: tronco de pirâmide com 4 FACETAS ======
> A moldura de um CRT real é um frustum: facetas trapezoidais
> (topo/base/esq/dir) inclinadas até o vidro recuado, encontrando-se
> em JUNTAS DIAGONAIS de 45° nos vértices (miter, como moldura de
> quadro). Cada faceta tem iluminação própria (luz de cima-esquerda).

## L83-85 (junto a `float lumX = (pp.x < 0.0) ? 0.98 : 0.78;    // esq clara / dir média`)

> FACETAS com transição SUAVE na diagonal (v3.3: a troca dura de
> luminância era a linha "não natural" — junta real é um gradiente
> de luz entre as faces + vinco de sombra macia por cima).

## L91-92 (junto a `float dSeam = abs(aPen.x - aPen.y);`)

> VINCO da junta: sombra gaussiana LARGA e suave (AO do encaixe),
> presente só no corpo da moldura (longe do lábio da abertura).

## L110-111 (junto a `float lipZone = smoothstep(0.013, 0.0045, dTube)`)

> LÁBIO especular POR FACETA logo após a ranhura: forte na base
> (pega a luz), nulo no topo (assimetria que vende o recesso)

## L129-134 (junto a `float p = clamp(power, 0.0, 1.0);`)

> ====== POWER v3.6: coreografia física do tubo ======
> LIGAR: ponto azulado do canhão frio → linha quente (bloom sangrando
> no vidro) → imagem abre → ROLA procurando sync (v-hold: barra de
> blanking + estática + cores lavadas de fósforo frio) → trava e
> assenta respirando. DESLIGAR: colapso vertical com surto → linha
> encolhe pra PONTO → o fósforo persiste, esfria pro laranja e apaga.

## L155-156 (junto a `float fade = (p - 0.02) / 0.32;`)

> PONTO persistente: o fósforo esfria (branco → laranja)
> e apaga devagar — o clássico das TVs antigas.

## L214-215 (junto a `float k = (p - 0.62) / 0.18;`)

> V-HOLD: a imagem ROLA procurando sync, desacelera e trava;
> barra de blanking escura passa na emenda do rolo.

## L245-246 (junto a `float sigY = 0.012 + vScale * 0.05;`)

> BLOOM: a linha quente SANGRA no vidro escuro ao redor
> (halação real de fósforo saturado, não corte seco)

## L287-293 (junto a `float caPx = (0.9 + mix(1.6, 3.5, deg) * r2 * 4.0) * strength * caBoost;`)

> ====== ABERRAÇÃO CROMÁTICA (cresce com a distância do centro) ======
> caBoost: no warm-up o canhão ainda não convergiu — CA bem maior
> v3.7: 0.0022→0.0010 — CA de canto borrava texto na periferia
> v3.10: no SURTO o canto volta EXATAMENTE ao valor antigo (0.0022)
> v4 (Out/2026, legibilidade em 1080p/1440p): a aberração é medida em
> PIXELS, não em fração da tela — em uv, 1440p deslocava 1,5-6 px e
> borrava o texto. Centro 0,9 px, canto +3,2 px (≈ o que 1280p tinha).

## L322-325 (junto a `float dome = 1.0 - (mix(0.03, 0.05, deg) * r2 * 2.0`)

> ====== RELEVO POR LUZ (v2.3: legibilidade > efeito) ======
> v3.7 (feedback do dono): cantos acumulavam dome×vignette×glassShadow
> ≈ -38% e dificultavam leitura — coeficientes e piso suavizados.
> v3.10: no SURTO o domo volta aos valores antigos (0.05/0.10, piso 0.85)

## L332-334 (junto a `float shadowW = mix(mix(0.05, 0.08, deg), mix(0.16, 0.28, deg),`)

> sombra do vidro recuado — DIRECIONAL: a moldura de cima projeta
> mais sombra no vidro. v3.7: 0.28→0.16 topo, 0.08→0.05 base (a faixa
> superior escondia o texto da TopBar). v3.10: surto restaura a antiga.

## L340-342 (junto a `float dEdge = deg * smoothstep(0.04, 0.32, r2);`)

> ====== VIGNETTE + FLICKER + NOISE ======
> v3.9 (dono): o surto é fenômeno de PERIFERIA — no centro a imagem
> fica idêntica ao baseline. Máscara radial: 0 no centro, 1 nos cantos.

## L347-349 (junto a `vignette = mix(1.0, pow(vignette, 2.0),`)

> v3.7: 0.55→0.30 baseline — a vinheta era o maior fator do
> escurecimento. v3.10: no SURTO volta EXATAMENTE à antiga (0.55);
> radial por natureza, centro intacto.

## L373-374 (junto a `if (dEdge > 0.001) {`)

> ====== SURTO: hum bar rolando + cor levemente lavada (v3.8) ======
> v3.9: mascarado por dEdge — a barra e a lavagem morrem no centro.

