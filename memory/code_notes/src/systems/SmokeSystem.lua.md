---
name: code_notes/src/systems/SmokeSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/SmokeSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/SmokeSystem.lua`

Origem: `src/systems/SmokeSystem.lua` em `7dbdb60d` (8 de 47 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local Debug = require("src.core.Debug")`)

> src/systems/SmokeSystem.lua
> Sistema de partículas de smoke para efeitos de fundo sutis

## L14 (em `SmokeSystem.config`, junto a `minOpacity = 0.02,`)

> Opacidade mínima (muito sutil)

## L15 (em `SmokeSystem.config`, junto a `maxOpacity = 0.08,`)

> Opacidade máxima (ainda sutil)

## L21 (em `SmokeSystem.config`, junto a `maxOffscreenDistance = 200`)

> Distância máxima fora da tela antes de remover

## L84 (em `SmokeSystem:update`, junto a `particle.vy = particle.vy + math.sin(particle.age * 2) * 0.5 * dt`)

> Adiciona movimento vertical sutil para mais naturalidade

## L91 (em `SmokeSystem:update`, junto a `particle.currentScale = particle.scale * (1 + dt * 0.01)`)

> Atualiza escala com crescimento sutil

## L140 (em `SmokeSystem:spawnParticle`, junto a `local vx = love.math.random(-8, 8)`)

> Movimento horizontal sutil

## L155-158 (em `particle`, junto a `rotation = (love.math.random() - 0.5) * 0.3,`)

> SEM GIRO (Out/2026, dono: "fumaça girando 360 graus na sala do
> chefe"). love.math.random(a, b) devolve INTEIRO: o antigo
> random(-0.05, 0.05) sorteava -0.05 ou 0.95 rad/s — uma volta a
> cada ~6,6 s em metade dos fiapos. Ângulo fixo e sutil por fiapo.

