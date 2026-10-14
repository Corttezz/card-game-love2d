---
name: code_notes/engine/ParticlesManager.lua
description: Comentários com decisão/regra/histórico colhidos de engine/ParticlesManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/ParticlesManager.lua`

Origem: `engine/ParticlesManager.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Particles = require("engine.Particles")`)

> engine/ParticlesManager.lua
> Registry global das instâncias Particles ativas. Único lugar onde update/draw
> de partículas é tickado (exceto SmokeSystem, que tem físicas próprias).
>
> USO:
> local p = ParticlesManager.spawn(x, y, w, h, config)
> ParticlesManager.update(dt)   -- chamar uma vez no love.update
> ParticlesManager.draw()       -- chamar uma vez no love.draw
> ParticlesManager.clear()      -- limpa tudo (ex: troca de cena)

## L37-38 (em `ParticlesManager.update`, junto a `function ParticlesManager.draw()`)

> Desenho ordenado por layer (z-order). Estável: layers iguais mantêm ordem
> de spawn (mais antigos primeiro).

## L41 (em `ParticlesManager.draw`, junto a `local sameLayer = true`)

> Single-pass se todos no mesmo layer (caso comum).

