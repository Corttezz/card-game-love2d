---
name: code_notes/src/ui/UnlockReveal.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/UnlockReveal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/UnlockReveal.lua`

Origem: `src/ui/UnlockReveal.lua` em `7dbdb60d` (4 de 26 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/UnlockReveal.lua
> REVELAÇÃO PÓS-RUN (StS UnlockScreen + popup de desbloqueio do Balatro):
> a barra de MAESTRIA da classe enche com o XP da run (atravessando níveis com
> flash + som), depois as cartas/classes liberadas aparecem UMA POR VEZ com pop.
>
> Consumido por src/scenes/EndScreens.lua (gameOver/victory). Sem update
> externo: tica no draw via love.timer.getDelta, igual ao título DynaText das
> telas finais. Recomeça sozinho quando recebe um `result` novo (identidade).
>
> Layout = UMA banda (x,y,w,h) recebida de quem chama; dentro dela, sub-bandas
> fixas (cabeçalho / barra / vitrine / rodapé). Falta de espaço encolhe a
> ESCALA das cartas, nunca empurra as bandas (lei de layout do projeto).

## L125-126 (em `UnlockReveal.draw`, junto a `setC(Palette.INK, 0.72 * math.min(1, t / 0.3))`)

> Placa escura atrás da banda: o fundo das telas finais é ilustração
> cheia de detalhe e a barra/rotulos sumiam nele.

## L229 (em `parts`, junto a `local nCards, nClasses = 0, 0`)

> Escala das cartas: cabe em altura e em largura (nunca empurra banda).

## L284 (em `parts`, junto a `local img = CardFrame.displayImage(it.inst) or it.inst.image`)

> carta revelada e VIVA como toda carta visivel (dono, 13/Out/2026)

