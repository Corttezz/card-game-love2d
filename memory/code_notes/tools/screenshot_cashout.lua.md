---
name: code_notes/tools/screenshot_cashout.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_cashout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_cashout.lua`

Origem: `tools/screenshot_cashout.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local M = {}`)

> tools/screenshot_cashout.lua
> Contact sheet do VOO DAS MOEDAS do cash out (item "animação da moeda sendo
> resgatada").
>
> O voo dura ~0,83s e passa por cima do painel enquanto ele desliza — num
> screenshot único não se vê nada. Captura em instantes fixos e monta lado a
> lado. Também confirma que as moedas MIRAM no bloco de ouro da TopBar (o
> alvo vem de _G.topBar; sem ele iriam pro centro e ninguém notaria).
>
> Roda: love . screenshot_cashout
> Saída: cashout_fly.png

