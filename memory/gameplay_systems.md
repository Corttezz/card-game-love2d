---
name: Gameplay Systems
description: Turnos, modos de deck, tipos de carta, efeitos data-driven, tags, combos, acts
type: project
---

# Gameplay Systems (pós-redesign — fases 1-7)

## Pilhas de carta (Slay-style)

Toda batalha tem 3 pilhas lógicas:
- **`game.deck`** — cartas ainda não compradas (draw pile)
- **`game.hand`** — cartas na mão
- **`game.discard`** — cartas já jogadas neste andar

Quando `drawCard()` encontra `#deck == 0 && #discard > 0`, move todo o discard pro deck e embaralha. Isso faz starter de 2 cartas funcionar: você joga as 2, elas viram descarte, e no próximo draw reembaralham.

Cartas `joker` não entram no discard (ficam em `game.jokerSlots`). Cartas com `exhaust = true` pulam o discard e ainda são removidas da run em `nextPhase`.

### Draw por turno (`drawForTurn`)

No início do turno do jogador (fim do `enemyTurn`), chama `Game:drawForTurn` em vez de `drawCard()` direto:
- **Normal:** puxa 1 carta (reshuffle automático se deck vazio + discard > 0).
- **Emergência (hand vazia):** puxa **3 cartas**. Evita o loop "compra 1 / joga 1" quando o deck inteiro cabe num turno. Mensagem "Recarga: +3 cartas" aparece no feed.
- **Base ampliável:** função tem `bonus = 0` de placeholder pra jokers futuros acrescentarem compras extras.

A mão inicial do floor (`startGame` / `resetHandAndDeck`) continua usando `drawCard` direto N vezes (`INITIAL_HAND_SIZE`), sem passar pela lógica de emergência.

## Turnos (Game.lua)
1. Player: hover/select cartas (debita mana via `player:spendMana`, desseleção devolve).
2. "Jogar Cartas" → `playSelectedCards()` constrói **turnContext** (snapshot, tagCounts, activeCombos), remove cartas da mão, chama `combatAnimationSystem:startCombat(...)`.
3. `ComboSystem.detect(turnContext)` + `ComboSystem.announce(game, turnContext)` — toasts.
4. Cada carta processada via `processCardInCombat(card, turnContext)`:
   - `damage = card.attack` → `applyCardEffects` (strength_scaling/multi_hit) → `+player.strength` → `ComboSystem.applyToCardValue` → `applyJokerEffects` → `math.floor`
   - Mesmo pipeline para defense com `player.dexterity` e `ComboSystem`.
   - Effects secundários da carta (apply_debuff, gain_strength, etc.) rodam via `processEffectCard`.
5. `onCombatAnimationComplete` → `ComboSystem.applyOnceEffects` (debuff, heal, evoke) → `turn = "enemy"`.
6. Enemy turn: `performAttack` (considerando weak -25%) → `player:takeDamage` (considerando vulnerable +50% vs enemy takeDamage) → `enemy:onTurnEnd()` processa poison DoT + decrementa durations em **turnos** → `player:restoreMana` + `player:onTurnStart` (decrementa buffs) → `drawCard`.
7. `checkVictory` passou a requerer ato final + boss (ver `memory/run_progression.md`).

## Dois modos de deck

- **Classic:** `deckManager:setCurrentDeck("starter")`. Deck estático. Usa `VICTORY_PHASES=24` como cap fallback.
- **Run (Slay-style, default):** `runManager:startNewRun(classId)` → starter de **2 cartas**. Deck cresce via nodes de map. Após vitória de batalha, `CardRewardScreen` → `continueAfterReward` → `showMapSelection` → `mapSelection` state → escolha de node tipado.

## Tipos de carta

- `attack` — dano ao enemy, passa por todo pipeline de cima.
- `defense` — armor ao player (cap `PLAYER_MAX_ARMOR=50`, zerado por batalha em `resetTransientStats`).
- `joker` — adiciona a `game.jokerSlots` (máx 3), roda `card.passive(game)` uma vez; `card.effects` ficam ativos pelo resto da run em `applyJokerEffects` / `applyTriggerEffects`.
- `effect` — `card.passive(game)` roda e carta é descartada.

## Efeitos processados (EffectSystem)

**Jokers (continuous, `processEffect`):**
- `damage_multiplier`, `defense_multiplier`, `damage_bonus`, `defense_bonus`, `heal_multiplier`

**Card-effects (`applyCardEffects` no damage path):**
- `strength_scaling`, `dexterity_scaling`, `multi_hit`, `damage_bonus_self`

**Effect cards (`processEffectCard`):**
- `instant_heal`, `restore_mana`, `increase_max_mana`, `add_armor`, `magic_damage`, `aoe_magic_damage`, `draw_cards`, `discard_cards`
- `apply_debuff` (value=name, stacks=intensidade, duration=turnos), `apply_buff`
- `gain_strength`, `gain_dexterity`
- `channel_orb` (orbType lightning/ice/dark/fire/holy, value=pot), `evoke_orb`, `evoke_all_orbs`
- `mystery` (sorteia do pool pré-definido)
- `exhaust` / `innate` / `retain` são flags processadas em Game/resetHandAndDeck

**Triggers (`applyTriggerEffects`):**
- `on_attack_heal`, `on_defend_damage`, `regen_per_turn`, `damage_per_turn`

## turnContext (Fase 1)

Construído em `Game:playSelectedCards` e propagado:
```lua
turnContext = {
  allSelectedCards = { ... },
  tagCounts = TagSystem.countAllTags(selectedCards),
  cardsProcessed = { ... },       -- anexado durante animação
  activeCombos = { ... },          -- preenchido por ComboSystem.detect
  turnNumber = game.turnCount or 0,
}
```
Disponível em `processEffect` e `applyJokerEffects` (args 4+).

## Status effects no inimigo

`statusEffects[]` com `{name, duration (em TURNOS), stacks}`. Processado em `Enemy:onTurnEnd`:
- `poison`: causa `stacks` de dano antes de decrementar duration.
- `weak`: reduz `performAttack` em 25%.
- `vulnerable`: amplifica `takeDamage` em 50%.

## Constantes-chave

Ver `memory/balance_curves.md` para tabela completa. Highlights:
- `PLAYER_MAX_HEALTH=60`, `INITIAL_HAND_SIZE=4`, starter deck = 2 cartas
- `VICTORY_PHASES=24` só é usado em classic mode (fallback)
- Run mode usa `Config.Acts` (3 atos × 8 andares + endless)

## Regra de ouro ao adicionar efeitos

- **Nunca condicione por `card.name`** — use `card.effects` + `card.tags` (data-driven).
- Adicione novo efeito em `EffectSystem` com seu branch novo, documente em `memory/gameplay_systems.md` e acrescente `PROCESSED_EFFECT_TYPES` em `tools/validate_cards.lua`.
- Se o efeito só faz sentido em combo, crie regra em `ComboSystem.RULES`.
