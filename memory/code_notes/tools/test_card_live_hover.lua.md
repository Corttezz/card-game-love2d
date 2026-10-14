---
name: code_notes/tools/test_card_live_hover.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_card_live_hover.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_card_live_hover.lua`

Origem: `tools/test_card_live_hover.lua` em `7dbdb60d` (6 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_card_live_hover.lua
> ROBUSTEZ do cache de animação das cartas (CardFrame.liveImage / update).
>
> Histórico: nasceu em Set/2026 pra travar "a carta anima no HOVER em toda
> tela" (o Deck Viewer não animava). Em 13/Out/2026 o dono revogou a regra
> "idle = estático": toda carta VISÍVEL é viva — essa regra agora mora em
> CardFrame.displayImage e é travada por tools/test_cards_always_live.lua.
> O que SOBRA aqui é o mecanismo, que não mudou de contrato:
> • render estubado (tools/balance_sim.setup vazando) nunca estoura e AVISA
> — o set nascia {nil, c2..c9} e test_class_select caía em draw(nil) uma
> vez a cada nove rodadas, por horário (memory/card_icon_animation.md);
> • render real: set inteiro sem buraco;
> • relógio não-finito não vira índice NaN;
> • teto MACIO do cache: MAX_LIVE+ cartas vivas no MESMO quadro não se
> expulsam (thrash piscava o estático); o excesso só sai quando PARADO.
>
> love . test_one test_card_live_hover

## L43-44 (em `animated`, junto a `local realGetTime, realPrint = love.timer.getTime, print`)

> Relógio SIMULADO (o índice do frame, o orçamento por quadro e a janela
> "parada" dependem dele). Cada tick = um love.update.

## L72 (em `warm`, junto a `local realRender = CardFrame.render`)

> (a) render estubado como no balance_sim: nunca estoura, fica no estático

## L105 (em `CardFrame.render`, junto a `now = 1 / 0`)

> (c) relógio não-finito nunca vira índice NaN

## L110 (em `CardFrame.render`, junto a `local N = math.min(#animated - 1, CardFrame.MAX_LIVE + 6)`)

> (d) teto MACIO: MAX_LIVE+ cartas vivas no MESMO quadro ficam todas

## L130-132 (em `insts`, junto a `now = now + CardFrame.STALE_SECS * 4`)

> quem continua em uso não é descartada pelo teto: pede uma que ainda
> está no cache (vira "fresca"), monta uma animação NOVA (estoura o
> teto de novo) — sai uma PARADA, nunca a fresca

