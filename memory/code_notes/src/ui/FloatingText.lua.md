---
name: code_notes/src/ui/FloatingText.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/FloatingText.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/FloatingText.lua`

Origem: `src/ui/FloatingText.lua` em `7dbdb60d` (5 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local FloatingText = {}`)

> src/ui/FloatingText.lua
> Texto flutuante Balatro-style: aparece com pulse, sobe levemente, fade out.
> Usado pra damage numbers, ouro ganho/gasto, +mana, buffs aplicados.
>
> Uso:
> FloatingText.spawn("+5", x, y, { color={1,0.85,0.2,1}, kind="gold" })
> FloatingText.update(dt)  -- no love.update
> FloatingText.draw()      -- no fim do love.draw
>
> Comportamento:
> 1) Pulse-in 0.15s (scale 0 → 1.2 → 1.0).
> 2) Hold 0.35s subindo lentamente (12 px/s).
> 3) Fade-out 0.25s (alpha 1 → 0 + scale 1 → 0.85).

## L32-33 (em `mult`, junto a `movename = { color = {0.95, 0.90, 0.78, 1}, fontSize = 15 },`)

> Nome do golpe do inimigo (ShowMoveName do StS): pergaminho claro —
> anuncia a AÇÃO, não o valor.

## L37-38 (em `movename`, junto a `function FloatingText.spawn(text, x, y, opts)`)

> spawn: x, y são coords de tela. opts = { color, fontSize, kind, hold, lift }
> Retorna o ID do floating text (raramente útil; spawn é fire-and-forget).

## L90 (em `FloatingText.draw`, junto a `local prevFont = love.graphics.getFont()`)

> Salva estado antes de bagunçar font/cor.

## L142 (em `FloatingText.draw`, junto a `function FloatingText.clear()`)

> Limpa todos. Útil em reset de cena.

