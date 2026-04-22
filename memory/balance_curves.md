---
name: Balance Curves
description: Números-alvo de HP, dano, economia e raridades por ato/andar
type: project
---

# Curvas de Balance

**Fase 5 + rebalance pós-playtest.** Fontes de verdade: `Config.Acts`, `Config.Endless`, `Config.Game` (`src/core/Config.lua`). Este doc resume as escolhas.

**Princípio:** curvas dimensionadas pro deck real — starter de 2 cartas cresce ~1 carta/andar, então o ato 1 enfrenta deck médio ~3-5 (não 10 como em Slay). HP dos inimigos foi escalado pra baixo proporcional. Meta de turnos/batalha: 2-3 no floor 1 ato 1, 4-5 em floors finais, 6-10 em bosses.

## Jogador (inicial)

- `PLAYER_MAX_HEALTH = 60` (antes 100; pressão maior num deck pequeno)
- `PLAYER_MAX_MANA = 3`
- `PLAYER_MAX_ARMOR = 50` (cap por batalha, zera no `resetTransientStats`)
- `INITIAL_HAND_SIZE = 4` (compensa deck de 2 cartas na run 1)
- `MAX_JOKER_SLOTS = 3`

## Inimigos por ato

Fórmulas em `Config.Acts[N]`:

| Ato | HP(f) | Dmg(f) | f=1 HP/Dmg | f=8 HP/Dmg | Boss HP | Boss Dmg |
|-----|-------|--------|------------|------------|---------|----------|
| 1 Catacumbas | 8 + f*6 | 3 + f*1.2 | 14/4 | 56/12 | 140 | 14 |
| 2 Torre | 60 + f*10 | 9 + f*1.5 | 70/10 | 140/21 | 300 | 22 |
| 3 Abismo | 150 + f*15 | 18 + f*2.5 | 165/20 | 270/38 | 500 | 32 |

**Elite**: HP × 1.6, Dmg × 1.3.
**Mini-boss**: HP = 70% boss, Dmg = 80% boss.
**Endless**: stats do ato 3 * `1.18^floorsInEndless`.

## Cura

- Inter-ato: 30% maxHP ao entrar no ato 2; 40% ao entrar nos atos 3+.
- Rest node: +30% maxHP.
- Events podem curar/dar maxHP.

## Raridade por ato (`rarityWeights`)

| Ato | common | uncommon | rare | legendary |
|-----|--------|----------|------|-----------|
| 1 | 70 | 25 | 5 | 0 |
| 2 | 40 | 45 | 14 | 1 |
| 3 | 15 | 45 | 32 | 8 |
| Endless | 10 | 35 | 45 | 10 |

## Starter cards (2 por classe)

Valores boostados no rebalance pós-playtest — cada carta pesa mais, dado que o starter só tem 2:

| Classe | Attack | Defense |
|---|---|---|
| Warrior | `warrior_strike` 8 | `warrior_defend` 7 |
| Mage | `mage_zap` 5 (+orb lightning 3) | `defense_001` 8 |
| Rogue | `rogue_strike` 7 | `rogue_defend` 6 |

## Tabela-alvo de stats por carta (Fase 7)

| Raridade / Custo | C0 | C1 | C2 | C3 |
|------------------|----|----|----|----|
| Common | 3-4 | 6-8 | 10-12 | — |
| Uncommon | 4-5 | 8-10 | 12-15 | 16-20 |
| Rare | 5-6 | 10-13 | 15-20 | 22-28 |

Cartas com efeito secundário forte recebem -1 a -3 no valor base.

## Economia

- Ouro inicial: 10
- Battle gold: `10 + floor*5 + bonus_sem_dano(5) + juros(10% * currentGold, cap 50)`
- Shop card cost: `3 × rarityMultiplier` (common:1, uncommon:2, rare:3, legendary:5)
- Shop refresh: `2 + refreshCount`

## Smoke tests de balance

- `love . smoke_acts` valida curvas HP/dano + starter deck = 2 + PLAYER_MAX_HEALTH = 60
- `love . validate_cards` lista cartas fora da curva
