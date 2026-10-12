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

## Re-baseline pós-Rebalance v2 (Jul/2026, bot v5.17)

Baterias `love . autoplay` com o Piloto v5.17 (prior de defesa pra mago/ladino):

| Bateria | Guerreiro | Mago | Ladino |
|---|---|---|---|
| 15×3 (bot v5, pré-fix de prior) | **12/15 (80%)** — os 15 chegaram ao boss final | 0/15 — morte por chip (decks sem defesa = viés do BOT) | 1/15 (7%) |
| 10×3 (bot v5.17) | 5/10 (50%) | 0/10 (mas muito mais fundo: 4× boss A2, 4× A3) | 1/10 (10%) |
| 10 mago (Conduíte 2 Foco) | — | **3/10 (30%)** + 1 morte no boss final | — |

- **Lição de método**: bot sem afinidade de defesa pra mago/ladino não mede o jogo,
  mede o próprio viés. Corrigir a política do bot ANTES de nerfar o jogo.
- **Levers aplicados**: prior de defesa no bot (v5.17) + Conduíte 1→2 Foco (Game.lua).
- **Banda atual**: 50/30/10 — todas as classes vencem e chegam ao A3. Tripwires formais
  (mago >65%, Muralha >65% → Baluarte 8→6) NÃO dispararam (thorn/turno medido 3-6,
  banda alvo 25-38).
- **Próximos levers monitorados**: conversão do ladino no boss final (morre lá 4/10);
  guerreiro se passar de 60% ("sofrido/turno 0.0" em atos inteiros é o sintoma —
  Onda de Ferro ×4-5 + Escudo de Espinhos + Muralha zera o dano inimigo).

## Kits dos inimigos (Out/2026, ver [[enemies]])

Os inimigos ganharam kit próprio (`src/data/enemies.lua`) — golpe médio ~1,0–1,1×
o dano base contra ~0,76× do kit antigo, mais debuffs no jogador. Calibração:

- `Enemies.DAMAGE_SCALE_BY_ACT = { 1.15, 1.10, 0.92, 0.88, 0.84, 0.84 }` (o começo
  SOBE: atos 1-2 tinham 0,0–0,2 de dano sofrido/turno) e `BOSS_DAMAGE_SCALE = 0.90`.
- Chefes dos atos 4-6: `bossHP/bossDmg` 660/32 → 600/33, 990/38 → 880/38,
  1430/45 → 1200/46 (o do ato 6 era esponja de 11–13 turnos).
- DoT no JOGADOR soma pilhas e fica com a MAIOR duração (somar as duas compunha:
  o Colosso matava pela soma de nuvens).

Baterias `balance_sim` (seed 700000; v6 = 2×15 por classe, seeds 700000+710000):

| | guerreiro | mago | ladino |
|---|---|---|---|
| antes (HEAD 278549b, 20/classe) | 60% | 35% | 30% |
| kits v1 (sem escala) | 15% | 15% | 5% |
| v6 (final) | 73% | ~33–59% (amostra curta) | 47–50% |

| ato | turnos/luta antes → v6 (guerreiro) | dano sofrido/turno | turnos/chefe |
|---|---|---|---|
| 1 | 3,0 → 3,2 | 0,0 → 0,4 | 4,9 → 5,5 |
| 2 | 4,7 → 4,7 | 0,2 → 0,4 | 7,2 → 6,5 |
| 3 | 6,6 → 5,3 | 0,5 → 0,8 | 8,8 → 7,0 |
| 4 | 6,6 → 6,1 | 1,1 → 0,9 | 8,2 → 7,7 |
| 5 | 7,4 → 6,4 | 0,8 → 1,3 | 9,3 → 7,4 |
| 6 | 8,4 → 6,6 | 1,3 → 1,6 | 11,0 → 8,0 |

**Atenção ao ler:** entre v4 e v5 a árvore recebeu mudanças de OUTRAS frentes
(bônus de ouro por elite/chefe, bancada de coringa mais barata, prévia de dano) —
o salto do guerreiro de 25% para 77% veio sobretudo daí. O guerreiro acima de 60%
é questão de CLASSE (já estava em 60% antes dos kits), não de inimigo. Lever
monitorado: o Colosso (A5) concentra as mortes do ladino (regen contra veneno) —
se passar de metade das mortes, baixar `regenPct` 0,02 → 0,015.
