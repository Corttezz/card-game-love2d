---
name: Combo Rules
description: ComboSystem — regras ativas de sinergia entre cartas jogadas no mesmo turno
type: project
---

# Combos

**Fase 3 do redesign.** `ComboSystem` lê `turnContext.tagCounts` (construído em `Game:playSelectedCards`) e dispara regras que amplificam dano/defesa ou aplicam efeitos extras.

## Como funciona (pipeline)

1. `Game:playSelectedCards` → `TagSystem.countAllTags(selectedCards)` → `turnContext.tagCounts`
2. `ComboSystem.detect(turnContext)` → popula `turnContext.activeCombos`
3. `ComboSystem.announce(game, turnContext)` → toasts no MessageSystem
4. Para cada carta no `processCardInCombat`: `ComboSystem.applyToCardValue(card, baseValue, turnContext)` aplica multiplicadores/bônus **antes** dos jokers
5. `onCombatAnimationComplete` → `ComboSystem.applyOnceEffects(game, turnContext)` dispara one-shots (debuff, heal, evoke)

## Regras ativas (`src/systems/ComboSystem.lua:RULES`)

| ID | Condição | Bônus |
|----|----------|-------|
| `strike_combo` | 2+ cartas com `strike` | damage_multiplier 1.4 |
| `triple_strike` | 3+ cartas com `strike` | damage_bonus 6 (cumulativo com strike_combo) |
| `defend_wall` | 2+ cartas com `defend` | defense_multiplier 1.4 |
| `armor_tower` | 2+ cartas com `armor` | defense_bonus 6 |
| `poison_stack` | 2+ cartas com `poison` | aplica poison (stacks 2, 2t) |
| `channel_burst` | 3+ cartas com `channel` | evoca 1 orb extra no fim |
| `cycle_motion` | pair `draw` + `discard` | damage_bonus 3 |
| `finisher_chain` | pair `strike` + `finisher` | damage_multiplier 1.3 |
| `lifesteal_burst` | pair `strike` + `lifesteal` | heal 4 |
| `magic_focus` | 2+ cartas com `magic` | damage_multiplier 1.5 |
| `thorn_reflex` | pair `defend` + `thorn` | defense_bonus 4 |

## Regras compõem

Exemplo: 3 ataques com `strike` disparam tanto `strike_combo` (×1.4) quanto `triple_strike` (+6 dano), aplicados em ordem:
```
10 de dano × 1.4 + 6 = 20
```

Se ainda tiver joker `damage_multiplier 2.0`:
```
20 × 2.0 = 40
```

## Efeitos "once" (`applyOnceEffects`)

Disparam uma vez no fim do turno, não por carta:
- `apply_debuff` → injeta debuff no inimigo
- `heal` → cura o player
- `evoke_on_combo` → evoca o orb mais antigo

## Adicionar novo combo

1. Editar `ComboSystem.RULES` em `src/systems/ComboSystem.lua`
2. Usar `rule = "min_count_tag"` (N+ cartas com tag X) ou `rule = "pair_tags"` (requires = {A, B})
3. Tipos de bonus válidos: `damage_multiplier`, `damage_bonus`, `defense_multiplier`, `defense_bonus`, `apply_debuff`, `heal`, `evoke_on_combo`
4. Rodar `love . smoke_combos` para validar

## Tags que ainda não têm combo dedicado

`fire`, `ice`, `dark`, `holy`, `strength`, `dexterity`, `exhaust`, `innate`, `retain`, `mana`, `aoe`, `vulnerable`, `weak` — abertura para expandir sem mudar o engine.
