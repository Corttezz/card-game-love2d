---
name: Architecture Map
description: Mapa de alto nível — state machine, Game.lua como orquestrador, sistemas, components. Atualizado pós-redesign (fases 1-7).
type: project
---

# Arquitetura

## Estrutura macro

- `main.lua` — state machine. `currentState` ∈ `menu | classSelection | playing | cardReward | mapSelection | rest | event | collection | gameOver | victory`. Instancia: `Menu`, `GameUI`, `CardRewardScreen`, `ClassSelectionScreen`, `MapScreen`, `RestScreen`, `EventScreen`, `TopBar`, `Game`, `AudioSystem`, `SmokeSystem`.
- `src/core/Game.lua` (~640 LOC) — orquestrador do gameplay. Dono de: `player`, `enemy`, `deck`, `hand`, `selectedCards`, `jokerSlots`, `currentPhase`, `score`, `isRunMode`, `selectedClass`, `_exhaustedThisBattle`, `_currentTurnContext`. Compõe: `deckManager`, `effectSystem`, `runManager`, `combatAnimationSystem`, `economySystem`, `messageSystem`.
- `src/core/Config.lua` — constantes centrais. Adicionado `Config.Acts` (3 atos) + `Config.Endless` + `Config.TotalActs=3`.

## Camadas

1. **Data**: `src/data/cards/{basic,warrior,mage,rogue}.lua` (96 cartas rebalanceadas com tags), `src/data/decks.lua`, `src/data/events.lua` (pool de eventos).
2. **Entities**: `Player` (HP, mana, armor + **strength, dexterity, orbs (max 3), buffs** pós-redesign) e `Enemy` (HP, damage, **statusEffects com duration em turnos**, `onTurnEnd` processa poison).
3. **Cards**: `src/cards/base/Card.lua` (render 3D Balatro) + subclasses Attack/Defense/Joker/Effect.
4. **Systems**:
   - **`TagSystem`** (novo, Fase 1) — catálogo de tags + helpers
   - **`ComboSystem`** (novo, Fase 3) — detecta sinergias entre cartas do turno
   - **`MapManager`** (novo, Fase 4) — gera nodes tipados (BATTLE/ELITE/BOSS/SHOP/REST/EVENT)
   - **`ActSystem`** (novo, Fase 5) — curvas de HP/dano por ato/floor/nodeType + endless
   - `EffectSystem` (expandido) — strength/orbs/exhaust/innate/mystery/apply_buff
   - `CombatAnimationSystem`, `EconomySystem`, `ShopSystem`, `AudioSystem`, `ParticleSystem`, `SmokeSystem`, `MessageSystem`, `DeckManager`, `CardDatabase`, `CardRegistry`
5. **UI**: `HudManager` + `HudPlayerPanel` + `ManaOrb` + `PlayerBuffPills` + `EnemyHud` + `StatusPill` (shared) + `StatusTooltip`, `CardInfoDisplay`, `Theme`/`Palette`, `FontManager` (com `drawWithOutline`), `ImageCache`, `IconLoader` (com `computeScale`).
6. **Components (telas)**: `Menu`, `ClassSelectionScreen`, `CardRewardScreen`, `MapScreen`, `RestScreen`, `EventScreen`, `TopBar`, `GameUI`, `Button`, `SettingsMenu`, `JokerSlot`, `CollectionScreen`.
7. **Debug**: `src/core/Debug.lua` — logger condicional.
8. **Pixel Art**: `Palette`, `PixelCanvas`, `PixelIcons`, `PixelFont`, `CardArt`, `CardFrame`, `PixelBackground`, `CRTShader`, `HoloShader`.
9. **Tools** (novo): `tools/smoke_tags.lua`, `smoke_effects.lua`, `smoke_combos.lua`, `smoke_map.lua`, `smoke_acts.lua`, `smoke_all`, `validate_cards.lua`.

## TurnContext (Fase 1)

Artefato que viaja pelo pipeline de combate, construído em `Game:playSelectedCards`:
```lua
turnContext = { allSelectedCards, tagCounts, cardsProcessed, activeCombos, turnNumber }
```
Propagado a `processCardInCombat(card, turnContext)` → `applyJokerEffects` / `processEffect`. Usado por `ComboSystem.applyToCardValue` para amplificar antes dos jokers.

## State flow (run mode)

```
menu → classSelection → playing
    (battle won) → cardReward (overlay)
    (skip/buy) → continueAfterReward()
    → showMapSelection (advanceFloorInAct)
    → mapSelection
    → onNodeChosen:
        battle/elite/miniboss/boss → nextPhase() → playing
        rest → RestScreen → back to map
        event → EventScreen → back to map
        shop → CardRewardScreen → back to map
    victory condition = ato3 boss killed AND NOT endless
```

## Dependências curiosas

- `_G.audioSystem` — única variável global.
- `Game.onToggleSettings` — callback injetado por main.lua, chamado pelo ícone de config.
- Jokers ativos desenhados em `main.lua:drawJokersAsCards()`.
- `love.resize` invalida `FontManager.clearCache()` e chama `updatePositions` em todas as telas.
- `RunManager.currentRun` agora tem `actNumber`, `floorInAct`, `endlessMode`, `pendingNodes`, `currentNode`, `mapHistory`, `upgraded`.

## How to apply

Ao implementar feature nova, pergunte: é gameplay (`src/core/Game.lua`) ou sistema reutilizável (`src/systems/`)? Se UI de tela cheia → `components/`. Widget → `src/ui/`. Config → `src/core/Config.lua`. Se é novo tipo de efeito: adicionar em `EffectSystem` + atualizar `PROCESSED_EFFECT_TYPES` em `tools/validate_cards.lua` + doc em `memory/gameplay_systems.md`.
