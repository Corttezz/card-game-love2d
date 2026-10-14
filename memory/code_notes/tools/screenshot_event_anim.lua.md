---
name: code_notes/tools/screenshot_event_anim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_event_anim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_event_anim.lua`

Origem: `tools/screenshot_event_anim.lua` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/screenshot_event_anim.lua
> Contact sheet da ENTRADA e da SAÍDA da EventScreen.
>
> A entrada dura 0,34s e a saída 0,30s: num screenshot único elas ou já
> acabaram ou nem começaram. Captura em instantes fixos e monta lado a lado —
> é a única forma de julgar dosagem ("efeitos sutis") sem assistir ao jogo.
>
> Também exercita o caminho que mais quebra: `screen:draw()` é chamado A CADA
> frame simulado, não só no instante da captura. Draw MUTA estado (lição das
> "cartas invisíveis até o hover": Card:draw grava self.x/y), então simular só
> o update esconde feedback loops de draw.
>
> Roda: love . screenshot_event_anim
> Saída: event_anim_enter.png e event_anim_exit.png

## L90 (em `M.run`, junto a `capture(screen)`)

> draw TODO frame: expõe feedback loop

