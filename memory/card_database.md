---
name: Card Database Notes
description: Schema de carta pós-redesign (tags + effects processados), starter deck de 2 cartas, como adicionar conteúdo
type: project
---

# Card Database

96 cartas em 4 módulos merged por `CardDatabase:loadData()`. Dados são Lua puro; `CardDatabase` é um loader fino que expõe queries.

## Módulos

- `src/data/cards/basic.lua` — 7 cartas (basics + 5 jokers lendários compartilhados).
- `src/data/cards/warrior.lua` — 23 cartas (armor stack / strength / thorns / exhaust).
- `src/data/cards/mage.lua` — 32 cartas (channel / evoke / magic / heal).
- `src/data/cards/rogue.lua` — 27 cartas (poison / discard / exhaust / draw).
- `src/data/decks.lua` — decks predefinidos (modo classic).

## Schema da carta (pós-redesign)

```lua
my_card_id = {
    id          = "my_card_id",             -- único, prefixado por classe
    name        = "Nome Visivel",           -- PT-BR
    type        = "attack",                  -- attack | defense | joker | effect
    subtype     = "common",                  -- metadata livre
    cost        = 1,                         -- mana
    attack      = 8, defense = 0,            -- stats base
    description = "...",                     -- tooltip
    image       = "assets/cards/.../png",    -- fallback: theRock.png
    rarity      = "common",                  -- common | uncommon | rare | legendary
    class       = "warrior",                 -- warrior | mage | rogue | basic
    tags        = { "strike", "strength" },  -- Fase 1 (TagSystem)
    innate      = false,                     -- opcional; Fase 2
    retain      = false,                     -- opcional
    effects     = { ... },                    -- data-driven
}
```

## Tags implícitas

`TagSystem.getCardTags` deriva automaticamente: `attack→strike`, `defense→defend`, `joker→passive`, `effect→utility`. Não precisa declarar — se a carta só precisa da implícita, pode omitir `tags`.

## Tipos de effect processados

Ver lista completa em `memory/gameplay_systems.md`. Novo tipo requer:
1. Implementação em `src/systems/EffectSystem.lua`
2. Atualização do dict `PROCESSED_EFFECT_TYPES` em `tools/validate_cards.lua`
3. `love . validate_cards` deve passar com 0 unknown types

## Injeção em runtime

`CardDatabase:createCardInstance(cd)` copia para a instância:
- `id`, `description`, `rarity`, `effects`, `class`
- `tags` (normalizadas via TagSystem)
- `innate`, `retain` (flags)
- `image` substituída por canvas procedural do `CardFrame.render` se possível
- `visualEffect` (nil | "shine" | "glow" | "holo") baseado em rarity

## Starter decks (CardRegistry)

**Fase 5:** cada classe começa com **2 cartas**:
```lua
warrior = { "warrior_strike", "warrior_defend" }
mage    = { "mage_zap",       "defense_001" }
rogue   = { "rogue_strike",   "rogue_defend" }
```
Deck cresce via map nodes (rewards/shop/event/forge).

## Raridade (CardRegistry:rollRarity)

Default 37/37/25/1 (common/uncommon/rare/legendary). Aceita `weights` customizados via arg — `ActSystem.getRarityWeights(actNumber)` passa pesos por ato (70/25/5/0 no ato 1, crescendo até 10/35/45/10 em endless).

`generateCardRewards(classId, numCards, { rarityWeights, minRarity })` — `minRarity` força piso (uncommon+ em elites, rare+ em bosses).

## Jokers (pool básico)

- `joker_001` Deus do Abismo — `damage_multiplier: 2.0`
- `joker_002` Guardião do Escudo — `defense_multiplier: 2.0`
- `joker_003` Senhor Vampiro — `on_attack_heal: 3`
- `joker_004` Bobo da Corte — rare (placeholder damage_bonus)
- `joker_005` Chapéu do Bufão — rare (`damage_bonus: +2`)

## Imagens disponíveis

- `assets/cards/attack/`: bloodSword, rage, secondWind, seeingRed, theRock
- `assets/cards/defense/`: ironShield
- `assets/cards/effect/`: manaCrystal, potionOfHealing
- `assets/jokers/`: joker1
- `assets/sprites/icons/`: 33+ PNGs via IconLoader

Muitas cartas novas ainda apontam pra `theRock.png` como placeholder (não é estilo — é falta de arte; ver `memory/sprite_design_queue.md`).

## How to apply

- Ao adicionar carta: edite arquivo correto em `src/data/cards/`. Se classe-específica, setar `class = "warrior"|"mage"|"rogue"`.
- Starter deck: ajustar `CardRegistry:getStarterDeckForClass`.
- Se carta "não faz X": checar `card.effects[].type` contra lista processada em `memory/gameplay_systems.md`.
- Depois de qualquer mudança: `love . validate_cards` + `love . smoke_all`.
