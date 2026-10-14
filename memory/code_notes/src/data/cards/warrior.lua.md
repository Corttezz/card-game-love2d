---
name: code_notes/src/data/cards/warrior.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/cards/warrior.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/cards/warrior.lua`

Origem: `src/data/cards/warrior.lua` em `7dbdb60d` (21 de 24 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `return {`)

> src/data/cards/warrior.lua
> Cartas da classe Guerreiro. Fase 7: tags + effects consistentes.
> Arquetipos principais: armor stack / strength scaling / thorns / exhaust engine.
> Rebalance v2 (Jul/2026): 16 mudancas + 4 cartas novas — WC Berserker completa
> (strength_scaling em twin_strike/colossus), WC Muralha/Thorn (shield_slam common
> de thorn, juggernaut 6, Baluarte Eterno 8 — thorn de JOKER dispara 1x/turno via
> P2.3), draw engine (brutality redesign + Grito de Comando), weak defensivo
> (Provocar) e bateria de mana com Exaurir (Adrenalina, critica A4).

## L42-44 (em `effects`, junto a `warrior_shield_slam = {`)

> Rebalance v2 (Jul/2026): REDESIGN — era duplicata exata de warrior_defend;
> virou a common de thorn que o thorn_reflex nao tinha. Thorn de CARTA reflete
> por carta jogada (a regra 1x/turno do P2.3 e SO para jokers).

## L61 (em `warrior_helm_of_valor`, junto a `description = "Ganha 6 de Bloqueio. Cura 3 de HP.",`)

> Rebalance v2 (Jul/2026): instant_heal 1 -> 3 (com floor no heal_multiplier, 3x1.5=4).

## L113 (em `warrior_flame_barrier`, junto a `description = "Ganha 12 de Bloqueio e arma 7 de Espinhos (o inimigo leva esse dano ao atacar).",`)

> Rebalance v2 (Jul/2026): on_defend_damage 4 -> 7; tag 'fire' removida (morta, poluia afinidade).

## L136 (em `warrior_inflame`, junto a `description = "Ganha 2 de Força e 2 de Destreza.",`)

> Rebalance v2 (Jul/2026): gain_dexterity 1 -> 2 (degrau real sobre seeing_red, common +2 Forca).

## L150 (em `warrior_power_through`, junto a `description = "Ganha 9 de Bloqueio. Descarta 1 carta aleatória.",`)

> Rebalance v2 (Jul/2026): discard_cards 2 -> 1 (preserva a tag discard p/ cycle_motion).

## L171-172 (em `effects`, junto a `warrior_kite_guard = {`)

> Rebalance v2 (Jul/2026): FIX TRAP — ganhou retain (era dominada por 2x Defender);
> vira setup contra intents grandes (intent congelado permite planejar).

## L189 (em `warrior_war_cry`, junto a `description = "Ganha 4 de Força.",`)

> Rebalance v2 (Jul/2026): gain_strength 3 -> 4 (corrige inversao vs seeing_red common +2).

## L202-205 (em `warrior_twin_strike`, junto a `description = "Causa 7 de dano 2 vezes.",`)

> Rebalance v2 (Jul/2026): attack 6 -> 7 + strength_scaling (era dominada pela common heavy_blade).
> Auditoria Out/2026: a Forca passou a valer POR GOLPE em todo multi_hit
> (EffectSystem.hitCount). (7+F)x2 = 14+2F: exatamente o numero que o
> strength_scaling dava aqui — a flag saiu pra nao contar a Forca 4x.

## L218 (em `warrior_iron_discipline`, junto a `description = "Ganha 12 de Bloqueio. Ganha 1 de Força.",`)

> Rebalance v2 (Jul/2026): defense 10 -> 12 (ponte Muralha->Berserker na banda uncommon C2).

## L228-229 (em `effects`, junto a `warrior_taunt = {`)

> Rebalance v2 (Jul/2026): NOVA — weak defensivo (era rogue-only); tech contra o boss A2.
> Weak so REDUZ o intent congelado (invariante preservado).

## L243-244 (em `effects`, junto a `warrior_battle_orders = {`)

> Rebalance v2 (Jul/2026): NOVA — warrior tinha ZERO draw fora de Sangria (rare);
> destrava cycle_motion pra classe.

## L264-265 (em `warrior_colossus_blow`, junto a `description = "Causa 24 de dano. Força conta em DOBRO.",`)

> Rebalance v2 (Jul/2026): + strength_scaling (rare vanilla dominada por 3x Golpe);
> remate do Berserker no A3 (~87 com 12 Forca + combos).

## L302-303 (em `warrior_berserk`, junto a `description = "+5 de dano em cartas de ataque. Perde 2 de HP no início de cada turno.",`)

> Rebalance v2 (Jul/2026): damage_bonus 2 -> 5 (versao high-risk do estandarte:
> +5 sujo vs +3 limpo; bonus FLAT soma normalmente, largest-wins e so p/ multiplicadores).

## L327-329 (em `effects`, junto a `warrior_brutality = {`)

> Rebalance v2 (Jul/2026): REDESIGN — era dominada por second_heart+standard_bearer;
> vira o motor de draw do warrior (identidade StS Brutality). on_turn_start_draw
> so itera jokerSlots — correto, e joker.

## L343-344 (em `effects`, junto a `warrior_dark_embrace = {`)

> Rebalance v2 (Jul/2026): REDESIGN — era dominada por juggernaut; primeiro uso do
> heal_multiplier (sinergia com helm_of_valor/feed/second_heart/rest; floor via P2.4).

## L374-375 (em `warrior_feed`, junto a `description = "Causa 12 de dano. Cura 8 de HP. Exaurir.",`)

> Rebalance v2 (Jul/2026): attack 10 -> 12, instant_heal 5 -> 8 (burst de sustain
> digno de rare; ancora do Vampiro). Exhaust = 1x por batalha.

## L389-390 (em `warrior_immolate`, junto a `description = "Causa 18 de dano. Aplica Vulnerável por 2 turnos. Exaurir.",`)

> Rebalance v2 (Jul/2026): tags 'aoe' (mentira mecanica, jogo single-enemy) e
> 'fire' (morta) removidas; numeros mantidos.

## L400-401 (em `effects`, junto a `warrior_juggernaut = {`)

> Rebalance v2 (Jul/2026): on_defend_damage 3 -> 6; como JOKER, o reflexo dispara
> 1x/turno (regra P2.3) — com Baluarte (8) + joker_002 (4) = 18/turno de jokers.

## L427-428 (em `effects`, junto a `warrior_adrenaline_rush = {`)

> Rebalance v2 (Jul/2026): NOVA (critica A4) — bateria de mana COM Exaurir:
> 1x/batalha, sem loop de mana no reshuffle; sem dominancia vs rogue_adrenaline (C0 sem custo de HP).

## L445-447 (em `effects`, junto a `warrior_eternal_bulwark = {`)

> ========== LEGENDARY ==========
> Rebalance v2 (Jul/2026): NOVA — capstone da Muralha/Thorn; como joker o reflexo
> dispara 1x/turno (regra P2.3). Tripwire: winrate Muralha >65% -> 8 vira 6.

