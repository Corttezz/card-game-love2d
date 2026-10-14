---
name: code_notes/src/ui/FlashShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/FlashShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/FlashShader.lua`

Origem: `src/ui/FlashShader.lua` em `7dbdb60d` (4 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local FlashShader = {}`)

> src/ui/FlashShader.lua
> Wrapper do shaders/flash.glsl. Overlay branco pixelado pra impactos,
> booster opening, buffs aplicados. Desenha um quad fullscreen ou per-card
> com alfa modulado.
>
> Uso típico (fullscreen flash, via EventManager):
> FlashShader.trigger(0.6)  -- intensidade 0..1
> Em love.draw (depois de tudo):
> FlashShader.draw()
> Em love.update:
> FlashShader.update(dt)

## L36-37 (em `FlashShader.isAvailable`, junto a `function FlashShader.trigger(i, duration)`)

> Dispara um flash. Intensidade 0..1 (0 desliga; 0.5 médio; 1 ofuscante).
> duration em segundos (decay linear até 0).

## L56 (em `FlashShader.update`, junto a `function FlashShader.draw()`)

> Desenha overlay fullscreen. Chame DEPOIS de todo o resto no love.draw.

## L68-69 (em `FlashShader.draw`, junto a `function FlashShader.drawPlain(alpha)`)

> Flash simples sem shader (fallback / uso leve): alpha branco fullscreen.
> Use quando só quer "piscar" sem o look pixelado do flash shader.

