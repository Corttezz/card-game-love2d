---
name: code_notes/tools/test_economy.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_economy.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_economy.lua`

Origem: `tools/test_economy.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local TK = require("tools.testkit")`)

> tools/test_economy.lua
> Testes de EconomySystem: gastar/ganhar ouro, juros (Balatro: $1 a cada $5,
> cap $5), stats e reset. Conferido em src/systems/EconomySystem.lua.
> love . test_economy

## L64-69 (em `interestAt`, junto a `local Config = require("src.core.Config")`)

> ===== ALCANCE dos preços (auditoria Out/2026, queixa do dono) =====
> Âncora MEDIDA na bateria (balance_sim, 36 runs): ouro na porta da loja
> no ato 1 ≈ $26, renda ≈ $10/batalha no ato 1. Estes asserts não fixam
> os números exatos — fixam a PROMESSA: a primeira bancada de coringa
> cabe numa loja do ato 1, a segunda em ~3 batalhas a mais, a lendária
> não fica fora da prateleira e o reroll não custa mais que duas comuns.

## L86-87 (em `getServiceCount`, junto a `t:truthy("elite paga bônus", Config.Economy.nodeBonus("elite", 1) > 0)`)

> Bônus de risco existe e é proporcional ao ato (sem ouro infinito: é
> pago 1x por nó vencido, e nós são finitos).

