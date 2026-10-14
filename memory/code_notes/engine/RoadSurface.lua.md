---
name: code_notes/engine/RoadSurface.lua
description: Comentários com decisão/regra/histórico colhidos de engine/RoadSurface.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/RoadSurface.lua`

Origem: `engine/RoadSurface.lua` em `7dbdb60d` (13 de 33 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local RoadSurface = {}`)

> engine/RoadSurface.lua
> SÍNTESE da superfície do leito da estrada (v10.1 — Jul/2026). O leito era
> um PNG tileado replicado ("textura padrão preenchendo tudo, sem
> profundidade nem desnível" — feedback). Este motor GERA a textura por
> bioma com engenharia de terreno pixel-art:
>
> 1. CLUSTERS TONAIS  — value-noise FBM periódico escolhe entre 4 tons de
> terra (nada de tile repetido; variação de baixa frequência real).
> 2. MICRO-RELEVO     — iluminação top-light por cluster: borda superior
> de um cluster elevado ganha highlight, borda inferior ganha sombra.
> É isso que dá o "desnível" (a leitura 3D de calombos e depressões).
> 3. SULCOS de RODA   — dois canais verticais contínuos, serpenteando,
> mais escuros com rim claro (estrada usada de verdade). Como o
> sampling é CENTRADO no eixo da estrada, os sulcos seguem a curva.
> 4. DESGASTE CENTRAL — faixa do meio mais clara (terra socada por pés).
> 5. SPECKLE          — grãos escuros/claros esparsos (cascalho fino).
> 6. ESPECIAL por bioma:
> highlands — LAJES de calçamento (Voronoi irregular, juntas escuras,
> relevo por laje) — engenharia no LEITO, não decal solto.
> abyss     — terra RACHADA (juntas Voronoi finas sobre os clusters).
> frost     — lama congelada com VEIOS de gelo claros.
> marsh     — lama molhada com BANDAS de brilho úmido.
> dusk      — húmus com flecos quentes (folhiço triturado).
>
> A textura tileia nos DOIS eixos (noise em lattice modular) — o scroll
> vertical da viagem nunca mostra emenda. Gerada 1× por bioma e cacheada.
> O RoadWear (decals determinísticos) continua por cima, mais esparso.

## L33 (em `cache`, junto a `local W, H = 192, 512`)

> texels; ~98 unidades de mundo antes de repetir

## L70-74 (em `mixc`, junto a `local function voronoi(x, y, nx, ny, seed, ky)`)

> VORONOI periódico (lajes/rachaduras): retorna d2-d1 (junta quando pequeno)
> e o id da célula mais próxima (tom da laje). Métrica levemente retangular
> (lajes assentadas, não bolhas).

## L87-89 (em `voronoi`, junto a `local d = math.max(math.abs(dx) * 1.0, math.abs(dy) * (ky or 0.78))`)

> ky > 1 achata a célula na vertical: o leito é esticado ao
> longo da profundidade pela perspectiva, então célula baixa
> na textura lê ~quadrada no chão (v10.1.2 anti-esticado).

## L98-104 (em `voronoi`, junto a `local function bake(bid, pal, yieldEvery)`)

> BAKE por bioma. pal = tabela do bioma (roadA/roadB/roadEdge).
>
> yieldEvery (Out/2026): quando o bake roda DENTRO do pré-aquecimento do
> WorldRoad (coroutine dele), cede a cada N linhas — o bake inteiro (~98k
> texels com FBM/Voronoi) era ~1/3 do engasgo da troca de ato. Fora da
> coroutine (nil) roda direto, como sempre.

## L135-138 (em `idx`, junto a `local dj, id = voronoi(x, y, 14, 36, seed + 11, 1.35)`)

> lajes: tom POR CÉLULA + juntas escuras (idx 0). v10.1.2:
> MAIS lajes (9×16→14×36) e mais curtas (ky 1.35) — antes
> ficavam grandes/esticadas ("muito esticado"). Junta mais
> fina (0.085→0.055) pra pedra menor não virar só junta.

## L148-149 (em `idx`, junto a `local dj = voronoi(x, y, 18, 40, seed + 23)`)

> terra rachada: craquelure FINA (células menores, junta
> de 1 texel — v10.1.1: 0.045 lia como "placas soltas")

## L157-158 (em `idx`, junto a `for y = 0, H - 1 do`)

> PASSE 2: cor + MICRO-RELEVO (top-light: borda de cima do cluster mais
> alto = highlight; borda de baixo = sombra) + sulcos + desgaste + grão

## L173-174 (em `c`, junto a `if up < ti then c = mulc(c, 1.10) end`)

> v10.1.2: relevo MAIS SUTIL (1.17/0.84 → 1.10/0.90) — o
> contraste forte lia como "linhas demais"

## L185-187 (em `c`, junto a `local wob = math.sin(y / H * math.pi * 6) * 0.018`)

> v10.1.2: sulcos MAIS SUTIS (calha 0.20→0.11, rim 1.06→
> 1.03) — os riscos verticais liam como "linha esticada",
> principalmente na neve

## L208-212 (em `c`, junto a `local r = vnoise(x, y, 12, 64, seed + 41)`)

> v10.1.2: gelo em MANCHINHAS quebradas, não veios longos.
> Antes era iso-contorno contínuo (10×24) que a perspectiva
> esticava em riscos ("muito esticado"). Agora: contorno de
> alta freq vertical (12×64 = curto) CORTADO por um segundo
> noise (dash) + mix mais fraco (0.55→0.30).

## L246-248 (em `c`, junto a `function RoadSurface.get(bid, pal, yieldEvery)`)

> pal = tabela de cores do bioma (rawBiome() do WorldRoad serve direto)
> yieldEvery: SÓ quem roda numa coroutine própria passa (pré-aquecimento
> do WorldRoad). O resultado é o mesmo: bake determinístico por bioma.

## L260-261 (em `RoadSurface.get`, junto a `if not cache[bid] then cache[bid] = img end`)

> outro caminho (draw síncrono) pode ter assado no meio de um bake
> cedido: fica o primeiro (conteúdo idêntico)

