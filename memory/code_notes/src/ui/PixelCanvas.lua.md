---
name: code_notes/src/ui/PixelCanvas.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PixelCanvas.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PixelCanvas.lua`

Origem: `src/ui/PixelCanvas.lua` em `7dbdb60d` (10 de 45 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/PixelCanvas.lua
> Primitivas de desenho pixel-perfect.
> Toda arte procedural do jogo passa por aqui para garantir nearest-neighbor,
> ausência de anti-aliasing e posições inteiras.
>
> Uso típico:
> local canvas = PixelCanvas.new(64, 96)
> PixelCanvas.beginDraw(canvas)
> PixelCanvas.fill(Palette.BG_DEEP)
> PixelCanvas.drawBitmap(sword16, 0, 0, { [1]=Palette.ORANGE, [2]=Palette.YELLOW })
> PixelCanvas.endDraw()
> canvas agora é uma love Image (Canvas é drawable).

## L20-21 (em `PixelCanvas`, junto a `function PixelCanvas.enableNearest()`)

> Chame uma vez em love.load (ou no início do módulo que cria canvases).
> Garante filtro nearest em tudo que for criado a partir daqui.

## L35-41 (em `PixelCanvas.new`, junto a `function PixelCanvas.beginDraw(canvas, clear)`)

> Prepara o ambiente para desenhar num canvas (salva estado COMPLETO).
> push("all") guarda canvas/cor/blend/shader/scissor E a transform;
> origin() + setScissor() zeram translate/scale/clip do chamador. Sem
> isso, um render LAZY no meio de um draw transformado (ex.: slide-in da
> tela de recompensa, scroll com scissor da Coleção) compunha o conteúdo
> DESLOCADO/CLIPADO pra fora do canvas — frames em branco cacheados =
> bug "carta piscando no hover" (Jul/2026).

## L60 (em `PixelCanvas.endDraw`, junto a `function PixelCanvas.pixel(x, y, color)`)

> ===== Primitivas (sempre em coordenadas inteiras) =====

## L84 (em `PixelCanvas.rectOutline`, junto a `love.graphics.rectangle("fill", x, y, w, 1)           -- top`)

> 4 linhas em vez de setLineWidth (evita problemas com filter)

## L97-105 (em `PixelCanvas.rectFramed`, junto a `function PixelCanvas.rectRounded(x, y, w, h, radius, color)`)

> Retângulo sólido com cantos "cortados" (stepped corners) — silhueta arredondada
> em pixel art. radius=1 tira 1 pixel de cada canto (plus shape), radius=2 tira
> 2 pixels, etc. Até 3px fica legal; mais que isso vira losango.
>
> Implementado como 2 retângulos sobrepostos (horizontal + vertical bar):
> ████  ← y+r..y+h-r: largura total
> ██████
> ██████ ← y+0..y+r: largura w-2r
> ████

## L118-119 (em `PixelCanvas.rectRounded`, junto a `end`)

> Não precisa preencher cantos — as duas barras já cobrem o centro e as bordas.
> Resultado: canto cortado quadradinho (stepped), look pixel-perfect.

## L156-163 (em `PixelCanvas.vline`, junto a `local function discHalfWidth(r, dy)`)

> ===== Discos pixel-perfect =====
> Por que existem: todo "selo"/"medalhão" da UI estava sendo desenhado com
> love.graphics.circle, que é um polígono ANTI-ALIASADO. Num jogo cujo resto
> é pixel art de borda dura, um disco suave lê como widget de outra engine —
> foi uma das causas do "cara de IA" reportado pelo dono (Set/2026) nas
> placas de preço da loja. Aqui o disco é construído por HLINES inteiras a
> partir da equação do círculo: a borda tem degraus, como um ícone desenhado
> à mão.

## L202-204 (em `PixelCanvas.discOutline`, junto a `function PixelCanvas.discShaded(cx, cy, r, top, bottom)`)

> Disco com luz direcional: interpola `top` -> `bottom` linha a linha.
> É o gradiente que o projeto aceita — por LINHA INTEIRA de pixel, não o
> degradê contínuo de shader. Dá volume de metal batido sem virar "pillow".

## L220-224 (em `PixelCanvas.discShaded`, junto a `function PixelCanvas.drawBitmap(matrix, ox, oy, palette)`)

> Desenha uma matriz 2D de índices de cor em (ox, oy).
> matrix: tabela de tabelas, ex: {{0,1,0},{1,1,1},{0,1,0}}
> 0 = skip (transparente)
> qualquer outro valor = índice em `palette` (default: Palette.INDEXED)
> palette: tabela {[1]=color, [2]=color, ...} — default usa Palette.INDEXED

