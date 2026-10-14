---
name: code_notes/src/ui/card/components/CardArtSlot.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardArtSlot.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardArtSlot.lua`

Origem: `src/ui/card/components/CardArtSlot.lua` em `7dbdb60d` (7 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local CardArtSlot = {}`)

> src/ui/card/components/CardArtSlot.lua
> Art slot: ilustração central com opção de cover/contain.
> Default: **cover fit** — o ícone preenche o slot todo (ambas dimensões);
> overflow é cortado pelo scissor, dando o efeito "ilustração encosta
> nos banners de nome e stats".
>
> Overrides por carta (em `src/data/card_art.lua`):
> artData.artScale  = número (1, 1.5, 2, etc.) — substitui o cover automático.
> nil   → cover-fit inteiro (padrão)
> 1     → ícone nativo sem zoom (64×64 centrado — tipo o visual antigo)
> outro → scale fixo (pode ser fracional pra PNG)
> artData.artOffsetY = pixels pra deslocar o ícone verticalmente (útil pra
> sprites cujo subject não tá no centro do 64×64).
>
> opts:
> skipIcon = true      → não desenha o ícone (usado pelo Joker, anima via overlay)
> iconOverride = handle → substitui artData.icon (frames animados do CardFrame;
> mesmo contrato { size = {w,h}, draw(x, y, scale) })

## L22-23 (em `CardArtSlot`, junto a `local function computeCoverScale(iconW, iconH, slotW, slotH)`)

> Escala inteira que cobre o slot (pixel-perfect, sem blur). Usa ceil pra
> garantir que o ícone preenche as duas dimensões.

## L31-41 (em `computeCoverScale`, junto a `CardArtSlot.VALIGN = 0.2`)

> Geometria compartilhada do ícone no slot (cover-fit ou artScale/artOffsetY).
> Também usada pelo CardAnimationLayer pra desenhar frames animados EXATAMENTE
> onde o ícone estático ficaria — manter as duas em sincronia é obrigatório.
> ENQUADRAMENTO VERTICAL (Out/2026, dono: "o topo das cartas está cortado"
> — o elmo do Defender, o punho da espada, a cabeça da Força Interior). O
> cover-fit inteiro (64→128) passa ~25-31px da altura do slot e o corte era
> dividido meio a meio: metade do excesso sumia em CIMA, justamente onde
> ficam cabeças, punhos e chamas. VALIGN = fração do excesso cortada em
> cima (0 = topo encostado, 0.5 = centro): 0.2 mostra o topo do sujeito e
> tira o resto do pé/chão, que o rodapé de stats já emoldura. Carta cujo
> sujeito importante fica EMBAIXO usa artOffsetY em src/data/card_art.lua.

## L44-45 (em `computeCoverScale`, junto a `local contentTopCache = {}`)

> Primeira linha com conteúdo (alpha > ~5%) do PNG do ícone, em px do ícone.
> Cache por caminho; ícone sem PNG (matriz) = 0.

## L72-73 (em `CardArtSlot.contentTop`, junto a `function CardArtSlot.layout(iconW, iconH, x, y, w, h, artData, iconHandle)`)

> iconHandle: o ícone ESTÁTICO (artData.icon) — o bbox vale pros frames
> animados também, que são desenhados exatamente no mesmo lugar.

## L82-85 (em `CardArtSlot.layout`, junto a `if excess < 0 and not (artData and artData.artOffsetY and artData.artOffsetY ~= 0) then`)

> SUJEITO INTEIRO NO TOPO (dono: "onde começa a sombra do título ela
> corta"): se o conteúdo do ícone começaria acima do slot (atrás do
> banner), desce até a primeira linha de conteúdo ficar no slot — o
> corte vai todo pro pé. Nunca desce além do topo do ícone no slot.

## L106-110 (em `CardArtSlot.draw`, junto a `local top = math.min(y, opts.clipTop or y)`)

> RECORTE: embaixo e dos lados, o slot; em CIMA, opts.clipTop (topo
> interno da moldura). Acima do slot a arte continua e some ATRÁS do
> banner do nome, que é desenhado depois — nunca é decepada por uma
> linha reta no pergaminho (dono: "onde começa a sombra do título
> ela corta").

