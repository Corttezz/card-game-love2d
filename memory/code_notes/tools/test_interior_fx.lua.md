---
name: code_notes/tools/test_interior_fx.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_interior_fx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_interior_fx.lua`

Origem: `tools/test_interior_fx.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_interior_fx.lua
> Regressões dos salões de chefe (Out/2026, dono: "remove todas essas bolas
> de luz das salas de chefe"):
>
> 1. Draw e update usam o MESMO salão (InteriorFX.hallFor). A v1 tickava
> as brasas com math.min(3, ato) e desenhava o salão real — nos atos
> 4-6 as brasas saíam da lava do hall 3 ("veias esquisitas").
> 2. Toda chama declarada cai em cima de FOGO PINTADO (pixels claros
> dentro do retângulo) — âncora vem do que está desenhado.
> 3. Nada de disco: InteriorFX não desenha círculo.
> 4. update/draw/drawFront rodam nos 6 salões em 4:3 e 16:9 sem erro.
>
> Roda via: love . test_one test_interior_fx

## L124 (em `M.run`, junto a `local realW, realH = love.graphics.getWidth, love.graphics.getHeight`)

> 4. smoke nos dois aspectos (janela falsificada — setMode em tool trava)

## L145-148 (em `love.graphics.getHeight`, junto a `t:eq("sem hook: véu zero", InteriorFX.renderedFog(), 0)`)

> ===== névoa de intenção no salão (fogHook / renderedFog) =====
> Mesmo contrato do WeatherEngine.fogHook: o véu persegue o alvo a 4/s,
> engrossa a névoa do chão e põe uma camada NA FRENTE do chefe; clear()
> zera; sem hook, zero. A trava de limiar mora em test_intent_visibility.

