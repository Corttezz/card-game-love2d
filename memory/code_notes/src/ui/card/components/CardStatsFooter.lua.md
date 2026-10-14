---
name: code_notes/src/ui/card/components/CardStatsFooter.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardStatsFooter.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardStatsFooter.lua`

Origem: `src/ui/card/components/CardStatsFooter.lua` em `7dbdb60d` (18 de 34 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local Palette          = require("src.ui.Palette")`)

> src/ui/card/components/CardStatsFooter.lua
> Rodapé ornamentado v2 (Jul/2026, pedido do dono: "mais trabalhado").
> Layout: [medalhão-selo c/ glifo] LABEL ‹corrente por tipo› [cartucho c/ valor]
>
> Identidade POR TIPO (a v1 era uma listra reta atravessando o banner — lia
> como "laser", não ornamento):
> attack  → corrente de LÂMINAS (chevrons sangue)
> defense → banda RIVETADA (aço, rebites)
> effect  → VINHA (musgo, losangos e brotos)
> joker   → constelação (fallback — jokers usam JokerFooter)
> O valor mora num CARTUCHO octogonal (placa engastada), não solto no ar.

## L23-24 (em `CardStatsFooter`, junto a `local TYPE_PATTERNS = {`)

> v3 (feedback do dono): textura de fundo POR TIPO (patterns PixelLab, os
> mesmos da art slot) — o fundo de tinta chapada da v2 ficou pobre.

## L91-93 (em `drawProceduralGlyph`, junto a `local WEDGE_SPANS = { 5, 3, 2, 1, 1 }`)

> Cunha de canto (v3.1): triângulo escalonado 5-3-2-1-1 abraçando as DUAS
> bordas internas do bevel. Os L-brackets da v2 eram "partezinhas" soltas
> e desalinhadas da base (feedback do dono).

## L108-110 (em `drawCornerWedge`, junto a `local MEDAL_HW = { 2, 3, 4, 5, 5, 5, 6, 5, 5, 5, 4, 3, 2 } -- meia-largura por linha`)

> ===== MEDALHÃO-SELO 13×13 (esquerda): anel de ouro + corpo no typeColor
> com luz NW / sombra SE, glifo por cima. Substitui o disco 7×7 que lia
> como "bolinha" na tela.

## L130 (em `drawSealMedallion`, junto a `for i, hw in ipairs(MEDAL_HW) do`)

> Volume: quadrante NW clareia, SE escurece (nunca pillow)

## L151-154 (em `drawSealMedallion`, junto a `local function drawStripeEnd(dX, cy, typeColor)`)

> ===== LOSANGO DE ARREMATE (v3.1): a linha do tipo termina numa ponta de
> lança que "apresenta" o número. Substitui o cartucho octogonal da v3 —
> lia como um "domo" descolado da placa (feedback do dono) e a garra de
> engaste deixava rebarba dourada colada no número.

## L183-186 (em `chainBlades`, junto a `local function chainRivets(x1, x2, cy)`)

> defense: banda rivetada — tachas em losango sombreado sobre a linha.
> v3.3: os rebites 2×2 com pixel de INK liam como "quadradinho de quebra
> de cor" na faixa de aço (feedback do dono) — tacha redonda-losango com
> luz em cima e sombra embaixo assenta na linha em vez de brigar com ela.

## L226-230 (em `CHAINS`, junto a `local function seedFrom(id)`)

> ===== DESGASTE (v3.2, pedido do dono: "impressão de algo mais velho,
> carta diferente e velha"): lascas escuras, pontos de ferrugem e poeira
> clara espalhados pela placa. DETERMINÍSTICO: hash por pixel + seed do id
> da carta — cada carta envelhece com padrão próprio, estável entre
> re-renders (nada de random no draw; regra do projeto).

## L241-244 (em `RUST_TINT`, junto a `local function drawWear(bx, by, bw, bh, seed)`)

> v3.3 (feedback: "pixels soltos sem sentido"): desgaste REALISTA —
> concentrado nas bordas/cantos (onde a mão gasta a placa), em LASCAS de
> 2px deitadas (nunca pixel-confete), ferrugem só grudada na moldura, e
> centro da placa quase intocado. Sem poeira branca (era o "quadradinho").

## L277-279 (em `CardStatsFooter.draw`, junto a `local inkTop = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.20)`)

> Fundo em DEGRADÊ contínuo (v3.4): o split 2-tons tinha uma emenda
> horizontal dura no meio — "reta onde a cor muda drasticamente"
> (feedback do dono, visível na defesa). Lerp por linha = sem emenda.

## L286-288 (em `CardStatsFooter.draw`, junto a `local grainSeed = 0`)

> GRÃO do material (v3.4, "mais detalhes e mais pixels no background"):
> variação densa e MUITO sutil por hash — superfície com matéria, sem
> virar ruído (é textura, não o desgaste das bordas).

## L302-303 (em `CardStatsFooter.draw`, junto a `local tex = BackgroundLoader.get(TYPE_PATTERNS[card.type])`)

> Textura por tipo sobre a tinta (v3.4: alpha 0.16→0.26 — a 0.16 o
> pattern era invisível e o fundo lia chapado).

## L313-316 (em `CardStatsFooter.draw`, junto a `local stripeY = cy - 1`)

> v3: a LINHA do tipo está de volta (feedback do dono — a v2 tirou e o
> rodapé perdeu a espinha). Full-width, 3 tons (luz de cima); medalhão,
> label e cartucho desenham POR CIMA, e a corrente ornamental enriquece
> o trecho visível dela.

## L322-325 (em `CardStatsFooter.draw`, junto a `local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)`)

> Bevel direcional (luz top-left, sombra bottom-right).
> v3.2: as linhas internas de baixo/direita eram PRETO puro — abriam uma
> vala escura entre as cunhas de canto e a moldura ("não tá coladinho",
> feedback do dono). Agora bronze (ouro sombreado): flush com as cunhas.

## L342-343 (em `CardStatsFooter.draw`, junto a `drawWear(bx, by, bw, bh, seedFrom(card.id))`)

> Desgaste envelhecido POR CARTA (sobre placa, bevel, linha e cunhas;
> medalhão/label/número desenham depois e ficam limpos por cima)

## L346-348 (em `CardStatsFooter.draw`, junto a `local medCX = bx + 8`)

> ===== MEDALHÃO-SELO com o glifo do tipo, SOLDADO à borda esquerda =====
> (v3.1: flutuando no meio da placa ele lia como "domo" descolado;
> as alças de ouro ancoram o selo na moldura, como um rebite-mestre.)

## L396-398 (em `CardStatsFooter.draw`, junto a `local vx = bx + bw - 6 - valueW`)

> v3.1: número DIRETO na placa (o outline preto garante leitura sobre
> linha/textura, como na v1) — o cartucho-domo morreu. A linha do
> tipo termina num losango que apresenta o número.

## L415 (em `CardStatsFooter.draw`, junto a `love.graphics.setColor(0.55, 0.92, 0.45, 1)`)

> verde-forja (StS)

