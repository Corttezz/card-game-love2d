---
name: Gameplay Systems
description: Turnos, dois modos de deck (classic vs run), tipos de carta, efeitos data-driven
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
**Turnos (Game.lua):**
1. Player: hover/select cartas (debita mana via `player:spendMana(cost)`, desseleção devolve).
2. Clica "Jogar Cartas" → `playSelectedCards()` remove cartas da mão e inicia `combatAnimationSystem:startCombat(...)`.
3. Cada carta é processada via `processCardInCombat(card)` dentro do callback da animação.
4. `onCombatAnimationComplete` → `turn = "enemy"`.
5. Enemy turn: `enemy:performAttack()` → `player:takeDamage(dmg)` → `player:restoreMana()` → `drawCard()` → volta `turn = "player"`.
6. `checkGameOver` / `checkVictory` / `isPhaseCleared` — bloqueados enquanto `combatAnimationSystem:isBlocking()`.

**Dois modos de deck:**
- **Classic:** `deckManager:setCurrentDeck("starter")` → `CardDatabase:buildDeckCards("starter")`. Deck estático, não cresce.
- **Run (Slay the Spire):** `runManager:startNewRun(classId)` inicializa `currentDeck = {...cardIds}` com starter da classe (via `CardRegistry:getStarterDeckForClass`). Após vitória, `CardRewardScreen` oferece cartas (gerada por `ShopSystem` no código atual, não `RunManager:completeBattle`). `game:addCardToRun(cardId)` insere e `synchronizeRunDeck()` reconstrói `game.deck` a partir do `runManager.currentRun.currentDeck`.

Flag controladora: `game.isRunMode` + `runManager:hasActiveRun()`.

**Tipos de carta (`card.type`):**
- `attack` — `card.attack` dano ao `enemy`. Modulado por `EffectSystem:applyJokerEffects(game, card, baseValue)`. Dispara trigger `attack` em jokers.
- `defense` — `card.defense` vira `player.armor` (limitado a `maxArmor=50`). Também passa por jokers. Dispara trigger `defend`.
- `joker` — adiciona a `game.jokerSlots` (máx 3), roda `card.passive(game)` uma vez, mas **os efeitos em `card.effects` ficam ativos pro resto da run** via aplicação contínua em `EffectSystem:applyJokerEffects`.
- `effect` — `card.passive(game)` roda e carta é descartada. Consulta `EffectSystem:processEffectCard`.

**Efeitos data-driven:** cada carta pode ter `effects = { {type, target, value}, ... }`. Tipos suportados em EffectSystem:

- **Continuous (jokers, aplicados ao baseValue):**
  - `damage_multiplier` / `defense_multiplier` (com `target = "attack"|"defense"`)
  - `damage_bonus` / `defense_bonus`
  - `heal_multiplier` (multiplica qualquer heal — usado por `instant_heal`, `on_attack_heal`, `regen_per_turn`)

- **Effect cards (`processEffectCard`):**
  - `instant_heal`, `restore_mana`, `increase_max_mana`, `add_armor`, `magic_damage`, `draw_cards`
  - `apply_debuff` (push em `enemy.statusEffects`)
  - `discard_cards`

- **Triggers — wired em `Game.lua`:**
  - `on_attack_heal` — em `processCardInCombat` após attack card.
  - `on_defend_damage` — após defense card.
  - `regen_per_turn` / `damage_per_turn` — em `enemyTurn` quando volta turno do player.

- **Declarados mas NÃO processados** (retornam false, só logam descrição): `channel_orb`, `evoke_orb`, `strength_scaling`, `exhaust`, `innate`.

**Constantes (Config.Game):**
- `INITIAL_HAND_SIZE = 3`, `MAX_JOKER_SLOTS = 3`
- `VICTORY_PHASES = 10`, `HEALTH_RESTORE_INTERVAL = 3`, `PLAYER_HEALTH_RESTORE = 20`
- `ENEMY_BASE_HEALTH = 18`, `ENEMY_BASE_DAMAGE = 5`, escalas `+15 HP`/`+3 dmg` por fase
- `PLAYER_MAX_HEALTH = 100`, `PLAYER_MAX_ARMOR = 50`, `PLAYER_MAX_MANA = 3`
- Enemy fica "aggressive" (+50% dmg) quando HP < 30%.

**Economia:** `economySystem.currentGold` inicia em 10 na run. `earnBattleGold(phase, healthLost, consecutiveWins)` = base (`10 + phase*5`) + bônus de não perder vida (+5) + bônus de vitórias consecutivas + juros TFT (10% do cofre, máx 50).

**How to apply:** Ao tocar em combate, respeite `isBlocking()`. Ao adicionar um novo tipo de efeito, adicione o `if t == "meu_tipo"` em `EffectSystem:processEffect` ou `processEffectCard` ou `processTriggerEffect` dependendo do escopo. **Nunca** condicione por `card.name` — o fluxo é puramente data-driven.
