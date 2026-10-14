---
name: code_notes/src/data/cards/basic.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/cards/basic.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/cards/basic.lua`

Origem: `src/data/cards/basic.lua` em `7dbdb60d` (8 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `return {`)

> src/data/cards/basic.lua
> Cartas basicas (sem classe especifica) e jokers lendarios compartilhados.
> Fase 7 rebalance: toda carta tem tags explicitas e effects significativos.

## L95 (em `effects`, junto a `{ type = "discard_cards", value = 1 },`)

> Rebalance Jul/2026: descarte 2 -> 1 (tira o tempo negativo e diferencia de power_through)

## L111 (em `effects`, junto a `{ type = "reveal_intent", value = 2 },`)

> Névoa de intenção (Out/2026): achar a brecha é VER o golpe

## L116 (em `effects`, junto a `joker_001 = {`)

> ========== JOKERS LENDARIOS (sempre disponiveis) ==========

## L141-142 (em `effects`, junto a `{ type = "on_defend_damage", value = 4, description = "Arma Espinhos 4 no primeiro Bloqueio do turno" },`)

> Rebalance Jul/2026: reflexo agregado ao x1.5 (que colide com o cap de bloqueio 30/40/50);
> como e JOKER, on_defend_damage dispara 1x/turno (regra P2.3, engine em EffectSystem/Game)

## L184-186 (em `effects`, junto a `joker_combo_volley = {`)

> ========== CORINGAS DE COMBO (Out/2026, combos simples) ==========
> Cada um DOBRA uma das tres regras do ComboSystem (combo_boost). Neutros:
> servem a qualquer classe, porque Saraivada/Muralha/Par sao de todos.

## L237-238 (em `effect_scroll_wisdom`, junto a `rarity = "uncommon", class = "basic",`)

> Rebalance Jul/2026: common -> uncommon (nerf preventivo — pos-fix do pool volta a ser
> ofertavel; draw 3 por 1 mana em common dominaria mage_arcane_sight e viraria auto-include)

## L243-244 (em `effects`, junto a `{ type = "reveal_intent", value = 2 },`)

> Névoa de intenção (Out/2026): o contador NEUTRO — toda classe
> tem acesso a uma leitura da nevasca

