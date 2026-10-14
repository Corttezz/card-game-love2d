---
name: code_notes/tools/smoke_turn_order.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_turn_order.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_turn_order.lua`

Origem: `tools/smoke_turn_order.lua` em `7dbdb60d` (7 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/smoke_turn_order.lua
> Regressão da ORDEM DO TURNO (nasceu do bug do escudo, Jul/2026):
> o dano do inimigo é diferido pro apex da investida — TUDO que roda
> depois do golpe (expiração do bloqueio, mana, compra) precisa esperar.
> Este teste teria pego o bug que o dono encontrou jogando.
> love . smoke_turn_order

## L19 (em `check`, junto a `for _, f in ipairs(love.filesystem.getDirectoryItems("shaders")) do`)

> Guarda anti-'--' em GLSL (3 incidentes): todo shader precisa COMPILAR.

## L43 (em `pump`, junto a `local game = Game:new()`)

> ===== 1. ESCUDO ABSORVE O GOLPE DIFERIDO (o bug do playtest) =====

## L52 (em `pump`, junto a `game.enemy.nextIntentDamage = 8`)

> telegraph congelado (contrato v2)

## L60-61 (em `pump`, junto a `pump(game, 0.15)`)

> ANTES do apex (~0.34s): o golpe ainda não aterrissou — o escudo NÃO
> pode ter expirado e o HP não pode ter mudado.

## L68-73 (em `pump`, junto a `pump(game, 3.5)`)

> DEPOIS do apex + continuação: golpe absorvido pelo escudo, HP intacto,
> e SÓ ENTÃO o escudo expira (início do turno do jogador).
> Pump 1.0 -> 3.5 (Set/2026): o turno do inimigo virou uma CADEIA de
> beats (telegrafia > golpe > espinhos > veneno > intent > upkeep >
> compra > gatilhos > a vez volta) — ~2.4s em vez de ~1s. Dar menos
> pump nao testa o fim do turno, testa o meio dele.

## L90 (em `pump`, junto a `game2.enemy.nextIntentDamage = 8`)

> telegraph congelado (contrato v2)

