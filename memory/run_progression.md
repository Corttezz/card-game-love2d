---
name: Run Progression
description: Estrutura de atos, tipos de nó no mapa, fluxo entre batalhas e endless mode
type: project
---

# Progressão da Run

**Fases 4-5 do redesign.** Substituiu cap linear de 10 fases por 3 atos + endless.

## Atos

Definidos em `Config.Acts` (`src/core/Config.lua`):

| Ato | Nome | Andares | HP base | Dano base | Boss HP | Boss Dmg | InterActHeal |
|-----|------|---------|---------|-----------|---------|----------|--------------|
| 1 | Catacumbas | 8 | 20 + f*8 | 4 + f*1.5 | 200 | 18 | 30% |
| 2 | Torre de Pedra | 8 | 90 + f*14 | 11 + f*2 | 420 | 28 | 40% |
| 3 | Abismo | 8 | 220 + f*22 | 22 + f*3 | 720 | 40 | 40% |

**Endless** (`Config.Endless`): após matar boss do ato 3, runs entram em modo infinito com scaling exponencial `1.18^floorsInEndless` aplicado sobre stats do ato 3.

## Tipos de nó (MapManager)

Em `src/systems/MapManager.lua`. Enum `MapManager.NODE_TYPES`:

- `BATTLE` — batalha normal, recompensa 1 de 3 cartas
- `ELITE` — inimigo 1.6x HP / 1.3x dano, recompensa garantida uncommon+
- `MINI_BOSS` — piso penúltimo do ato (floorInAct = 7)
- `BOSS` — piso último do ato (floorInAct = 8)
- `SHOP` — usa `CardRewardScreen` com gold
- `REST` — `RestScreen`: curar 30% maxHP OU forjar carta
- `EVENT` — `EventScreen`: evento sorteado de `src/data/events.lua`

## Pesos por andar

`MapManager.weightsFor(floorInAct, actNumber)`:
- Inicio (1-2): 70% battle, 15% shop, 10% rest, 5% event, 4% elite
- Meio (3-4): 55/12/10/13/10
- Final (5-6): 55/12/10/13/18 (mais elite)
- Floor 7: sempre mini_boss
- Floor 8: sempre boss

## Fluxo por turno

```
playing → enemy dies
        → cardReward (overlay)
        → continueAfterReward
        → showMapSelection (avança floorInAct via runManager:advanceFloorInAct)
        → mapSelection (2-3 node choice)
        → [onNodeChosen]:
            BATTLE/ELITE/MINI_BOSS/BOSS → game:nextPhase() → playing
            REST → RestScreen → skipBattleAndShowMap (volta ao map)
            EVENT → EventScreen → skipBattleAndShowMap
            SHOP → cardRewardScreen (como loja) → skipBattleAndShowMap
```

## Starter deck

`CardRegistry:getStarterDeckForClass` retorna **2 cartas**: 1 attack + 1 defense da classe. Deck cresce via recompensas, loja, eventos, forge.

## Fim da run

- Vitória: `Game:checkVictory` só retorna true quando o jogador está em `actNumber >= TotalActs` (3) E `floorInAct >= FLOORS_PER_ACT` (8) E `currentNode.type == "boss"` E `enemy.health <= 0`.
- Endless: `run.endlessMode = true` bloqueia `checkVictory`; a run só termina em game over.
- Save/load persistido pelo `RunManager` em `love.filesystem.write("run.save.lua", ...)`.
