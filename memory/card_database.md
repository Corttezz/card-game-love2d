---
name: Card Database Notes
description: CardDatabase é loader fino (~170 LOC) que merge src/data/cards/{basic,warrior,mage,rogue}.lua; theRock.png é placeholder comum
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
`src/systems/CardDatabase.lua` agora tem ~170 LOC — é só um **loader**. Os dados foram movidos para módulos separados:

- `src/data/cards/basic.lua` — cartas sem classe (attack_001/002, defense_001, warrior_seeing_red/rage/second_wind/spot_weakness, joker_001/002/003).
- `src/data/cards/warrior.lua` — common/uncommon/rare do Guerreiro.
- `src/data/cards/mage.lua` — common/uncommon/rare do Mago + `effect_healing_potion`, `effect_mana_crystal`.
- `src/data/cards/rogue.lua` — common/uncommon/rare do Ladino.
- `src/data/decks.lua` — decks predefinidos (starter, warrior, mage).

Cada módulo retorna uma tabela `{id = {...}, ...}`. `CardDatabase:loadData()` faz merge no primeiro `new()`.

**Armadilhas:**
- `cardData` e `deckData` são **upvalues no escopo do módulo** (singleton). Chamar `CardDatabase:new()` várias vezes não duplica dados.
- `createCardInstance(cd)` injeta `id`, `description`, `rarity`, `effects`, `class` na instância **depois** do constructor — sem isso, tooltip fica vazio e `EffectSystem` não aplica efeitos.

**Estrutura de uma carta:**
```lua
id = "warrior_strike", -- = chave na tabela cards
name = "Golpe",        -- PT-BR, mostrado no tooltip
type = "attack",        -- attack | defense | joker | effect
subtype = "common",     -- metadata livre
cost = 1,               -- mana
attack = 6, defense = 0,
description = "...",
image = "assets/cards/attack/theRock.png",
rarity = "common",      -- common | uncommon | rare | legendary | basic
class = "warrior",      -- warrior | mage | rogue | nil (básica)
effects = { ... }       -- array de {type, value, target, stacks, description}
```

**Classes e pools (CardRegistry):**
- **warrior** — starter: `warrior_strike`, `warrior_defend`, `warrior_bash`, `warrior_iron_wave`, `warrior_heavy_blade`, `attack_001`, `defense_001`, `attack_002` (8 cartas). Pool tem common/uncommon/rare pesadas em ataque + bloqueio.
- **mage** — starter: `mage_zap`, `mage_dualcast`, `mage_ball_lightning` + básicas + 2 effect cards (`effect_healing_potion`, `effect_mana_crystal`) + joker_001. Muitos efeitos de orbe declarados mas não implementados.
- **rogue** — starter: `rogue_strike`, `rogue_defend`, `rogue_survivor`, `rogue_neutralize`, `rogue_backstab` + básicas.

**Raridades (`CardRegistry:rollRarity`):** 37% common / 37% uncommon / 25% rare / 1% legendary. (Na loja `ShopSystem:rollRarity` usa 70/25/5 — diferente.)

**Jokers notáveis:**
- `joker_001` "God of the Abyss" — `damage_multiplier: 2.0` em ataques.
- `joker_002` "God of the Abyss" (sic, nome duplicado) — `defense_multiplier: 2.0`.
- `joker_003` "God of the Abyss" (sic) — `heal_multiplier: 2.0`. Agora processado pelo EffectSystem (multiplica `instant_heal`, `on_attack_heal`, `regen_per_turn`).

**Effect cards:**
- `effect_healing_potion` — `instant_heal: value 20`
- `effect_mana_crystal` — `restore_mana: value 2`

**Decks estáticos (modo classic):** `"starter"`, `"warrior"`, `"mage"` (formato `{cards = {{id=..., quantity=...}, ...}}`). `DeckManager:setCurrentDeck("starter")` é o default.

**Imagens disponíveis:**
- `assets/cards/attack/`: bloodSword, rage, secondWind, seeingRed, theRock (+ deck.png)
- `assets/cards/defense/`: ironShield
- `assets/cards/effect/`: manaCrystal, potionOfHealing
- `assets/jokers/`: joker1

Quase todas as cartas novas apontam pra `theRock.png` como placeholder. Se der erro ao carregar, o Card.lua também usa `theRock.png` como fallback final.

**How to apply:**
- Ao adicionar carta: edite o arquivo correto em `src/data/cards/` (basic/warrior/mage/rogue). Se for de classe específica, setar `class = "warrior"|"mage"|"rogue"` — o CardRegistry pool filtra automaticamente.
- Para incluir no starter deck: também adicionar o ID em `CardRegistry:getStarterDeckForClass`.
- Antes de buscar "por que essa carta não faz X", cheque se `card.effects` tem um `type` que o EffectSystem suporta (ver `memory/gameplay_systems.md`).
