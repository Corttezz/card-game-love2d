---
name: code_notes/src/ui/PolychromeShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PolychromeShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PolychromeShader.lua`

Origem: `src/ui/PolychromeShader.lua` em `7dbdb60d` (2 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local PolychromeShader = {}`)

> src/ui/PolychromeShader.lua
> Wrapper do shaders/polychrome.glsl. Edition "Polychrome": iridescencia na
> paleta do grimorio (ambar -> ocre -> ferrugem -> violeta -> musgo), que
> MODULA a arte em vez de pintar por cima. Continua sendo a edition mais
> notavel das tres -- ver o cabecalho do .glsl pro raciocinio.
>
> Uso: PolychromeShader.draw(cardImage, x, y, 0.7)

## L35-37 (em `PolychromeShader.draw`, junto a `local frozen = _G.gameSettings and _G.gameSettings.reducedMotion`)

> reducedMotion CONGELA a fase em vez de desligar o efeito: a matiz vira um
> gradiente estatico e a carta continua obviamente especial. Edition e
> informacao de RARIDADE, nao enfeite -- some a animacao, nao o sinal.

