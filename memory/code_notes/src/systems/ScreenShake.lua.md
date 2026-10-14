---
name: code_notes/src/systems/ScreenShake.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ScreenShake.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ScreenShake.lua`

Origem: `src/systems/ScreenShake.lua` em `7dbdb60d` (10 de 30 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local ScreenShake = {}`)

> src/systems/ScreenShake.lua
> Screen shake global Balatro-style: sine waves multifrequência em X/Y/rot
> + jiggle decay exponencial + parallax sutil do cursor.
>
> Uso:
> ScreenShake.trigger(intensity, duration)  -- ou _G.triggerShake(...)
> ScreenShake.jiggle(amount)                -- empilha "energia" (Balatro)
> ScreenShake.update(dt)                    -- no love.update
> ScreenShake.push()                        -- antes do draw (translate+rotate)
> ScreenShake.pop()                         -- depois do draw
>
> Mantém _G.triggerShake registrado em .install() pra chamadas legadas
> (Game:_onEnemyDeath, CombatSequence._handleResult, EnemyRenderer) funcionarem.

## L17 (em `ScreenShake`, junto a `local time = 0`)

> API legacy (intensity-based) — mantida pra back-compat.

## L22 (em `ScreenShake`, junto a `local jiggle = 0`)

> API nova (jiggle accumulator Balatro-style).

## L24 (em `ScreenShake`, junto a `local timer = 0`)

> tempo absoluto pra alimentar as sines (cresce sempre)

## L33 (em `ScreenShake`, junto a `local CURSOR_PARALLAX = 0.0`)

> 0 = desliga; 0.005 = sutil. Reservado pra futuro.

## L45 (em `userScreenshakeAmt`, junto a `function ScreenShake.trigger(i, d)`)

> Dispara shake intensity-based (compat). Também adiciona jiggle proporcional.

## L54 (em `ScreenShake.trigger`)

> ============ API nova (Balatro) ============

## L56-59 (em `ScreenShake.trigger`, junto a `function ScreenShake.jiggle(amt)`)

> Empilha energia no jiggle (decay automático). Use em juice grandes:
> ScreenShake.jiggle(0.3)  -- carta jogada
> ScreenShake.jiggle(0.7)  -- crítico / explosão pequena
> ScreenShake.jiggle(1.5)  -- pack abrindo / boss death

## L120 (em `ScreenShake.computeOffsets`, junto a `function ScreenShake.push()`)

> Translação + rotação aplicadas ao contexto gráfico. Sempre pair com pop().

## L152 (em `ScreenShake.getState`, junto a `function ScreenShake.install()`)

> Registra _G.triggerShake global pra back-compat com sistemas que já usam.

