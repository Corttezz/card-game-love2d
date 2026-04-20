---
name: Architecture Map
description: Mapa de alto nível — state machine em main.lua, Game.lua como orquestrador, hierarquia src/systems + components + ui
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
**Estrutura a macro:**

- `main.lua` — state machine. `currentState` ∈ `menu | classSelection | playing | cardReward | gameOver | victory`. Instancia `Menu`, `GameUI`, `CardRewardScreen`, `ClassSelectionScreen`, `TopBar`, `Game`, `AudioSystem`, `SmokeSystem`. Delega update/draw conforme estado.
- `src/core/Game.lua` (~580 LOC) — orquestrador do gameplay. Dono de: `player`, `enemy`, `deck`, `hand`, `selectedCards`, `jokerSlots`, `currentPhase`, `score`, `isRunMode`, `selectedClass`. Compõe: `deckManager`, `effectSystem`, `runManager`, `combatAnimationSystem`, `economySystem`, `messageSystem`.
- `src/core/Config.lua` — único ponto de constantes. Ratios de UI (`Config.UI.*`), gameplay (`Config.Game.*`), cards (`Config.Cards.*` incluindo parâmetros 3D), audio volumes, Config.Utils para calcular tamanhos responsivos.

**Camadas:**
1. **Data**: `src/data/cards/{basic,warrior,mage,rogue}.lua` + `src/data/decks.lua` — tabelas Lua puras. `CardDatabase` é loader fino (~170 LOC) que merge tudo e expõe queries. `CardRegistry` (classes, pools, raridade) → `DeckManager` (modo clássico) / `RunManager` (modo run, usa CardRegistry direto — `ClassSystem` foi removido).
2. **Entities**: `Player` (HP/Armor/Mana) e `Enemy` (HP, damage escalonado, cooldown, statusEffects).
3. **Cards**: `src/cards/base/Card.lua` (render 3D, hover, sombras, tooltip, usa `ImageCache` pros ícones) + 4 subclasses thin em `src/cards/types/`: Attack, Defense, Joker, Effect.
4. **Systems**: lógica auto-contida — `EffectSystem` (data-driven, sem mocks), `CombatAnimationSystem`, `EconomySystem`, `ShopSystem`, `AudioSystem`, `ParticleSystem`, `SmokeSystem`, `MessageSystem`.
5. **UI**: `HudManager` orquestra `HudPlayerPanel` + `HudEnemyPanel`. `CardInfoDisplay` renderiza tooltip. `VisualEffects` utilitário. `Theme` + `FontManager` (cache) + **`ImageCache`** (cache global de imagens) são singletons de design.
6. **Components (telas)**: `Menu`, `ClassSelectionScreen`, `CardRewardScreen`, `TopBar`, `GameUI` (só delega para `HudManager`), widget `Button`, **`SettingsMenu` (overlay modal)**, `JokerSlot`.
7. **Debug**: `src/core/Debug.lua` — logger condicional (Debug.log/trace/warn/err) com `Debug.verbose` pra silenciar mensagens densas.
8. **Pixel Art (procedural)**: pipeline completo que gera arte em runtime.
   - `Palette` (16 cores fixas), `PixelCanvas` (primitivas), `PixelIcons` (25 ícones 16×16), `PixelFont` (cache).
   - `CardArt` + `src/data/card_art.lua` → mapeia cardId para composição.
   - `CardFrame` → gera canvas 64×96 cacheado por ID em 8 camadas.
   - `PixelBackground` → casinoTable / voidStars / dungeon / parchment cacheados.
   - `CRTShader` + `shaders/crt.glsl` — pós-processamento full-screen Balatro-style.
   - `HoloShader` + `shaders/holo.glsl` — foil arco-íris para rare/legendary.
   - Ver `memory/pixel_art_system.md` e `src/ui/README_PixelArt.md` para detalhes.

**Dependências curiosas:**
- `_G.audioSystem` — única variável global (set em `main.lua` no `love.load`). Acessado por Game, Card, CombatAnimationSystem, SettingsMenu.
- `Game.onToggleSettings` — callback injetado por main.lua, chamado pelo ícone de config da TopBar para abrir/fechar o SettingsMenu.
- Jokers ativos são desenhados no `main.lua` (`drawJokersAsCards()`), não em GameUI — Balatro style no topo. O `components/JokerCard.lua` antigo foi removido (era órfão).
- `love.resize(w, h)` em main.lua reposiciona menu/gameUI/classSelection/cardReward/settingsMenu e invalida FontManager — updates por-frame foram removidos.

**How to apply:** Ao implementar feature nova, pergunte: é gameplay (`src/core/Game.lua`) ou sistema reutilizável (`src/systems/`)? Se é UI de tela inteira, `components/`. Se é widget/panel, `src/ui/`. Config sempre centralizado em `src/core/Config.lua`.
