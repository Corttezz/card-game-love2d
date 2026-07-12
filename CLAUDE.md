# CLAUDE.md — Card Game (LÖVE2D)

Guia de contexto para o Claude Code neste repositório. Mantenha este arquivo em sincronia com o código: se uma afirmação aqui conflita com o que está no código, **confie no código** e atualize este arquivo.

---

## 1. Visão geral do projeto

Card game estratégico em Lua + **LÖVE2D 11.3**, inspirado em **Slay the Spire** (deck dinâmico por classe, recompensas pós-batalha, sistema de raridade) e **Balatro** (jokers passivos, efeitos 3D em cartas, animações de combate cinematográficas). Idioma de UI e comentários: **português (BR)**.

- **Entry point:** `main.lua`
- **Config Love:** `conf.lua` (janela 1024×768, resizable, `identity="card-game"`, physics/touch/video desabilitados, audio habilitado)
- **Rodar:** `love .` no diretório raiz (no WSL2 o som pode estar indisponível — o `AudioSystem` detecta isso e degrada graciosamente)

---

## 2. Estrutura de diretórios

```
card-game-love2d/
├── main.lua                    # Entry point: state machine (menu / classSelection / playing / cardReward / gameOver / victory); love.resize reposiciona tudo
├── conf.lua                    # LÖVE config 11.5 (janela, módulos)
├── engine/                     # Infra genérica reutilizável (portada do Balatro)
│   ├── Event.lua               # Classe Event (trigger=after/immediate/condition/ease)
│   ├── EventManager.lua        # Fila global de eventos temporais, _G.EventManager
│   ├── Easing.lua              # Funções de easing + lookup por nome
│   ├── Moveable.lua            # Mixin juice_up() + T/VT opcional
│   ├── GrassField.lua          # Motor de vegetação rasteira (SpriteBatch, vento 3 camadas, presets por bioma) — base do cenário WorldRoad
│   ├── LightEngine.lua         # Motor de iluminação 2D do WorldRoad (lightmap ¼ multiply-only, micro-luzes, zero stencil) — memory/lighting_engine.md
│   ├── ShadowEngine.lua        # Motor de sombras projetadas de silhueta (direção pelo sol, comprimento pelo horário, fila pós-grama) — memory/shadow_engine.md
│   └── LuminaireEngine.lua     # Motor de props emissores de luz (catálogo 2-3 luminárias/bioma, âncora de chama por conteúdo, cadência de spawn, brasas) — memory/luminaire_engine.md
├── shaders/                    # GLSL (LÖVE 11.x format)
│   ├── crt.glsl, holo.glsl, card_perspective.glsl  # Pré-existentes
│   ├── dissolve.glsl           # Próprio (value noise + FBM + threshold animado)
│   ├── flash.glsl              # Próprio (full-screen white + ring radial)
│   ├── booster.glsl            # Próprio (iridescente azul-prata pra packs)
│   ├── holo.glsl               # Próprio (rare/legendary — multi-banda + sweep + sparkle)
│   ├── light_dither.glsl       # Próprio (LightEngine — falloff posterizado + dither Bayer 4×4)
│   ├── foil.glsl               # Próprio (edition Foil — metálico frio sem rainbow)
│   ├── polychrome.glsl         # Próprio (edition Polychrome — hue cycle saturado)
│   └── negative.glsl           # Próprio (edition Negative — invertido + halo)
├── src/scenes/                 # Scenes extraídas de main.lua (padrão init(deps) + update/draw/input)
│   ├── GameplayScene.lua       # Estado "playing": combate + mão + jokers + drag/reorder
│   └── EndScreens.lua          # drawGameOver + drawVictory
├── components/                 # UI de alto nível (telas, widgets)
│   ├── Menu.lua                # Menu principal
│   ├── ClassSelectionScreen.lua# Seleção de classe (warrior/mage/rogue)
│   ├── GameUI.lua              # HUD do gameplay (só delega ao HudManager)
│   ├── CardRewardScreen.lua    # Loja / recompensas pós-batalha (inclui refresh)
│   ├── TopBar.lua              # Barra superior (ouro, deck, ícone config)
│   ├── SettingsMenu.lua        # Overlay modal: volume (music/sfx/master) + fullscreen
│   ├── PauseMenu.lua           # Menu de pausa (engrenagem da TopBar, StS-style): continuar/config/salvar e sair/abandonar (confirmado); _G.togglePauseMenu
│   ├── JokerSlot.lua           # Slot visual de joker ativo
│   └── Button.lua              # Widget botão: clean (Balatro-inspired, default) | ornate | invisible
├── src/
│   ├── core/
│   │   ├── Game.lua            # Orquestrador (turnos, deck, combate, hooks de settings)
│   │   ├── Config.lua          # Constantes centrais (UI ratios, gameplay, cards, audio)
│   │   ├── BackgroundConfig.lua# Loader e drawer de backgrounds configuráveis
│   │   └── Debug.lua           # Logger condicional (log/trace/warn/err)
│   ├── data/                   # DADOS — tabelas Lua puras (sem lógica)
│   │   ├── cards/
│   │   │   ├── basic.lua       # Cartas sem classe + 3 jokers lendários
│   │   │   ├── warrior.lua     # Guerreiro (common/uncommon/rare)
│   │   │   ├── mage.lua        # Mago + effect cards (potions)
│   │   │   └── rogue.lua       # Ladino
│   │   └── decks.lua           # Decks predefinidos
│   ├── cards/
│   │   ├── base/Card.lua       # Classe base: render 3D, hover, sombras (usa ImageCache)
│   │   └── types/              # AttackCard, DefenseCard, JokerCard, EffectCard (thin)
│   ├── entities/
│   │   ├── Player.lua          # HP, armor, mana, spendMana/restoreMana
│   │   └── Enemy.lua           # HP, damage scaling, attackPattern, statusEffects
│   ├── systems/
│   │   ├── CardDatabase.lua    # Loader fino (~170 LOC) que merge src/data/cards/*.lua
│   │   ├── CardRegistry.lua    # Classes + pools por raridade + rolagem (substitui ClassSystem)
│   │   ├── DeckManager.lua     # Modo clássico: decks estáticos
│   │   ├── RunManager.lua      # Modo Slay the Spire + save/load via love.filesystem
│   │   ├── EffectSystem.lua    # Efeitos data-driven (jokers, effect cards, triggers)
│   │   ├── CombatSequence.lua  # Combate via EventManager (substitui CombatAnimationSystem)
│   │   ├── ScreenShake.lua     # Shake global (_G.triggerShake via .install())
│   │   ├── CardParticles.lua   # Partículas attach-to-card (dissolve/materialize)
│   │   ├── CardRevealSequence.lua # Orquestrador pack-opening (explode + materialize)
│   │   ├── EconomySystem.lua   # Ouro, juros tipo TFT
│   │   ├── ShopSystem.lua      # Ofertas da loja (cartas + upgrades + refresh)
│   │   ├── (áudio → engine/AudioManager.lua; facade Sfx.lua abaixo)
│   │   ├── Sfx.lua             # Wrapper thin: Sfx.play("name") ao invés do guard repetido
│   │   ├── MessageSystem.lua   # Toasts in-game com fade
│   │   ├── ParticleSystem.lua  # Partículas genéricas
│   │   ├── SmokeSystem.lua     # Smoke atmosférico (4 presets)
│   │   └── Timer.lua           # Timer simples
│   ├── ui/
│   │   ├── WorldRoad.lua       # Circle Land: mundo-domo que gira (inimigo emerge da curva, castelo cresce) — memory/worldroad_scene.md
│   │   ├── Theme.lua           # Paleta de cores + utilitários (gradient, interpolate)
│   │   ├── FontManager.lua     # Cache de fontes + drawWithOutline helper
│   │   ├── ImageCache.lua      # Cache global de imagens (evita carregar PNGs múltiplas vezes)
│   │   ├── IconLoader.lua      # Resolve nome → PNG (64×64) OU matriz 16×16, + computeScale helper
│   │   ├── HudManager.lua      # Orquestra HudPlayerPanel + ManaOrb + PlayerBuffPills
│   │   ├── HudPlayerPanel.lua  # Painel inferior esquerdo flat sepia (HP + Armor shield PNG)
│   │   ├── ManaOrb.lua         # Orb circular Balatro-style (mana) canto inferior direito
│   │   ├── PlayerBuffPills.lua # Row horizontal de pills de buff (strength/dexterity/focus)
│   │   ├── EnemyHud.lua        # HP bar + intent icon + status pills ancorados no sprite
│   │   ├── StatusPill.lua      # Componente único de pill circular (usado por EnemyHud + PlayerBuffPills)
│   │   ├── StatusTooltip.lua   # Tooltip global sépia com explicação de status effects
│   │   ├── CardInfoDisplay.lua # Tooltip de carta no hover
│   │   └── Animation.lua       # Easing helpers
│   └── config/
│       └── SmokeConfig.lua     # Presets de smoke (default/subtle/atmospheric/intense)
├── assets/
│   ├── cards/{attack,defense,effect}/  # PNGs das cartas
│   ├── jokers/                 # Imagens de jokers
│   ├── icons/                  # coin/mana/armor/attack/deck/config (escala ~0.05 no HUD)
│   ├── backgrounds/step1.png   # Background do gameplay
│   └── effects/smoke1-4.png    # Texturas de smoke
├── audio/                      # music.mp3, hoverCard.wav, sword/armor/select SFX
├── test-audio/, test-game/     # Scratchpads (não é o jogo principal)
├── README.md                   # Apresentação em PT-BR
├── AUDIO_README.md             # Doc do sistema de áudio + troubleshooting WSL2
├── GUIA_NOVO_SISTEMA.md        # Como adicionar cartas/decks ao CardDatabase
└── SISTEMA_SLAY_THE_SPIRE.md   # Doc do modo corrida
```

---

## 3. State machine (main.lua) — pós-redesign

`currentState` transita entre:

```
menu → classSelection → playing
                         ↓ (enemy dies)
                       cardReward (overlay)
                         ↓ (skip ou comprou)
                       mapSelection
                         ↓ (escolhe node)
                    ┌────┴─────────────────┐
         playing (battle) │ rest │ event │ shop
                           (back to mapSelection)
                         ↓
                    gameOver | victory → menu
```

**States novos:** `mapSelection` (MapScreen), `rest` (RestScreen), `event` (EventScreen). O state `cardReward` agora serve tanto recompensa de batalha quanto loja (SHOP node).

- **menu**: `Menu:draw()` — botões Jogar / Configurações / Sobre / Sair (últimos dois só imprimem "em desenvolvimento").
- **classSelection**: `ClassSelectionScreen` — escolhe `warrior`, `mage`, ou `rogue` → `startGame(classId)`.
- **playing**: `drawGame()` + `updateGame(dt)`. Desenha background, top bar, HUD, cartas na mão (3D hover), smoke, jokers ativos como cartas no topo (Balatro style), sistema de mensagens, animação de combate por cima de tudo.
- **cardReward**: após `game:isPhaseCleared()` em run mode, `CardRewardScreen` mostra ofertas (ShopSystem). Desenha o jogo por trás como overlay.
- **gameOver / victory**: telas estáticas com score.

### Inputs (gameplay)
- Mouse: hover/select cartas, clica "Jogar Cartas", clica config na TopBar.
- `r`: reinicia via `game:startGame()`.
- `f`: toggle fullscreen + `FontManager.clearCache()`.
- `1/2/3/4`: presets de smoke (subtle/default/atmospheric/intense). `0`: limpa smoke.
- `esc`: abre/fecha o **PauseMenu** nos estados de run (playing/mapSelection/rest/event) — sair, salvar e abandonar são decisões DENTRO do pause. Em gameOver/victory volta ao menu direto.

---

## 4. Loop de gameplay (Game.lua) — pós-redesign

1. `Game:startGame()` reseta player/enemy/economia, chama `initializeDeck()` (usa RunManager → starter de **2 cartas**), embaralha, **promove cartas `innate` pro topo**, compra `Config.Game.INITIAL_HAND_SIZE=4` cartas.
2. Jogador hover/seleciona cartas — `Game:selectCard(card)` debita mana.
3. `Game:playSelectedCards()` → constrói **`turnContext`** (tagCounts, activeCombos, snapshot) → `ComboSystem.detect/announce` → remove cartas da mão → `combatAnimationSystem:startCombat(...)`.
4. Para cada carta: `processCardInCombat(card, turnContext)`:
   - **Attack path**: `damage = card.attack` → `applyCardEffects` (strength_scaling/multi_hit) → `+player.strength` → `ComboSystem.applyToCardValue` → `applyJokerEffects` → floor. Depois processa `card.effects` secundários (`apply_debuff`, etc.).
   - **Defense path**: idem com `player.dexterity`.
   - **Joker/Effect**: passive roda; joker vai pros slots.
5. `onCombatAnimationComplete` → `ComboSystem.applyOnceEffects` (heal/debuff/evoke) → `turn = "enemy"`.
6. `Game:enemyTurn()`:
   - `performAttack` (considera `weak`)
   - `takeDamage` aplica no player
   - `enemy:onTurnEnd()` → poison DoT + decrementa durations de debuffs
   - `player:restoreMana`, `player:onTurnStart` (decrementa buffs), `drawCard`
   - `applyTriggerEffects("turn_start")` → regen/DoT do player
7. Se `game:isPhaseCleared()` (enemy.health ≤ 0):
   - Run mode: `showCardRewards()` → `continueAfterReward` → `showMapSelection` → escolha → dispatch
   - Classic: `game:nextPhase()` direto
8. `nextPhase()`:
   - Processa `_exhaustedThisBattle` (remove permanentemente cartas com `exhaust=true` da run)
   - Ganha ouro, reseta mana
   - Usa `ActSystem.getEnemyStats(actNumber, floorInAct, nodeType)` para stats do próximo inimigo
   - Cura inter-ato 30-40% quando cruza para novo ato
9. **Vitória**: `actNumber >= 3` AND `floorInAct >= 8` AND `currentNode.type == "boss"` AND enemy morto. Após vencer, opção de entrar em endless.
10. **Endless**: `endlessMode = true` trava checkVictory; scaling `1.18^floorsInEndless`.

---

## 5. Dois modos de deck

Convivem no mesmo `Game`:

| | **Classic (legacy)** | **Run mode (default)** |
|---|---|---|
| Trigger | Default sem `startNewRun` | `game:startNewRun("warrior")` (via ClassSelectionScreen) |
| Deck source | `DeckManager` → `"starter"` | `RunManager.currentRun.currentDeck` (IDs) |
| Starter | Deck estático | **2 cartas** (1 attack + 1 defense) |
| Deck cresce? | Não | Sim, via map nodes (battle/event/shop/forge) |
| Classes | Ignoradas | warrior/mage/rogue com pool próprio |
| Progressão | Cap `VICTORY_PHASES=24` | **3 atos × 8 andares + endless** |
| Mapa | Nenhum | MapManager gera 2-3 node choices |
| Save/load | Não | `run.save.lua` via `love.filesystem` |

Flag: `game.isRunMode` + `runManager:hasActiveRun()`.

---

## 6. Tipos de carta + Tags + Effects (pós-redesign)

Todas herdam de `src/cards/base/Card.lua`. Toda carta tem **`tags = {}`** (array de strings do catálogo em `TagSystem.CATALOG`).

- **`attack`** — dano ao inimigo. Pipeline completo: `applyCardEffects` → `+player.strength` → `ComboSystem.applyToCardValue` → `applyJokerEffects`.
- **`defense`** — armor ao player (cap 50, zerado por batalha). Mesmo pipeline com `dexterity`.
- **`joker`** — slots (máx 3), `card.passive(game)` roda 1x, `card.effects` ficam ativos pelo resto da run.
- **`effect`** — `processEffectCard` executa, carta descartada.

**Tipos de effect processados** (fontes: `EffectSystem.processEffect` / `processEffectCard` / `applyCardEffects` / `processTriggerEffect`):
- **Continuous jokers**: `damage_multiplier`, `defense_multiplier`, `damage_bonus`, `defense_bonus`, `heal_multiplier`
- **Card self-effects**: `strength_scaling`, `dexterity_scaling`, `multi_hit`, `damage_bonus_self`
- **Effect cards / passives**: `instant_heal`, `restore_mana`, `increase_max_mana`, `add_armor`, `magic_damage`, `aoe_magic_damage`, `draw_cards`, `discard_cards`, `apply_debuff`, `apply_buff`, `gain_strength`, `gain_dexterity`, `channel_orb`, `evoke_orb`, `evoke_all_orbs`, `mystery`
- **Flags**: `exhaust`, `innate`, `retain`
- **Triggers**: `on_attack_heal`, `on_defend_damage`, `regen_per_turn`, `damage_per_turn`

Ver `memory/gameplay_systems.md` para referência completa.

## 6b. Tags e Combos

Catálogo em `src/systems/TagSystem.lua` (`TagSystem.CATALOG`), categorias: archetype, mechanic, element, role.

**ComboSystem** detecta sinergias entre cartas do MESMO turno via `turnContext.tagCounts`:
- `strike_combo` — 2+ `strike` → dano ×1.4
- `triple_strike` — 3+ `strike` → +6 dano
- `defend_wall` — 2+ `defend` → defesa ×1.4
- `poison_stack` — 2+ `poison` → aplica poison extra
- `channel_burst` — 3+ `channel` → evoca 1 orb
- `cycle_motion` — `draw` + `discard` → +3 dano
- `finisher_chain` — `strike` + `finisher` → ×1.3
- `lifesteal_burst` — `strike` + `lifesteal` → +4 HP
- `magic_focus` — 2+ `magic` → ×1.5
- `thorn_reflex` — `defend` + `thorn` → +4 defesa
- `armor_tower` — 2+ `armor` → +6 defesa

Combos compõem: `10 dmg` × `strike_combo 1.4` + `triple_strike 6` × `joker 2.0` = `52`. Ver `memory/combo_rules.md` para adicionar regra nova.

---

## 7. Renderização de cartas (Balatro 3D)

`Card:updateMouse` e `Card:draw` implementam:
- Normaliza posição do mouse para `[-1, 1]` → `depthMultiplier` via distância ao centro.
- Tilt 3D baseado em `TILT_RANGE` + `DEPTH_TILT_{X,Y}`.
- Lift: carta **desce** ao fazer hover na mão; **sobe** se `isRewardCard = true`.
- Sombra dinâmica: offset e escala variam com a posição do mouse.
- Borda azul pulsante (`PLAYABLE_BORDER_COLOR`) se `canPlayCard == true` (3 linhas com fade pra profundidade).
- Tooltip via `CardInfoDisplay` no hover (nome/stats/descrição).

Todos os parâmetros em `Config.Cards`: `BASE_SCALE=0.20`, `HOVER_SCALE=0.22`, `LIFT_AMOUNT=25`, `DEPTH_OFFSET=15`, etc.

---

## 8. Sistemas importantes

### Áudio (`engine/AudioManager.lua` + facade `src/systems/Sfx.lua`)
O antigo `src/systems/AudioSystem.lua` virou `engine/AudioManager.lua`; a instância continua exposta como `_G.audioSystem` em `main.lua` (API compatível: `loadSound`, `playSound`, `play(name, {volume, pitch, loop})`, grupos master/music/sfx). Sons registrados em `main.lua` (nativos em `audio/`, gerados via ElevenLabs em `audio/sfx/` — dezenas de códigos camelCase). **Consumers usam `Sfx.play("name")` / `Sfx.playWithVariation(...)` — no-op gracioso sem áudio.** A key do ElevenLabs pra gerar SFX novos fica na memória auto do Claude (`elevenlabs-api-key`).

### CombatAnimationSystem (`src/systems/CombatAnimationSystem.lua`)
Máquina de estados: `idle → cards_flying → processing → damage_dealing → complete`. Bloqueia a lógica do jogo via `isBlocking()`. Usa easing out-quart, escalas aumentadas (1.3x) no centro, números de dano flutuantes. Timings em `self.timings`.

### EconomySystem + ShopSystem
`economySystem.currentGold` inicia em 10 na run. `earnBattleGold(phase, healthLost, consecutiveWins)` gera ouro + juros estilo TFT (10% do cofre, máx 50). Shop gera ofertas (70% cartas, 30% upgrades) com raridade 70%/25%/5% (common/uncommon/rare). `rollRarity` da shop é diferente do `CardRegistry:rollRarity()` (37/37/25/1 legendary).

### HUD (redesign STS + Balatro)
`HudManager` orquestra `HudPlayerPanel` (flat sepia com shield PNG pro armor), `PlayerBuffPills` (row acima do painel com strength/dexterity/focus), e `ManaOrb` (canto inf-direito Balatro-style). Stats do inimigo ficam ancoradas **no sprite** via `EnemyHud` (HP bar sob os pés, intent icon custom acima, status pills circulares com ícones PixelLab), chamado em `main.lua` após `EnemyRenderer.draw(game, cx, cy)` que retorna o bbox.

**Tooltips** de status effects via `src/ui/StatusTooltip.lua` — singleton global, show() agenda, draw() chamado no final do frame de gameplay. Hover em qualquer pill (inimigo ou jogador) dispara tooltip com `status.<name>.name` + `status.<name>.desc` (interpolando `{stacks}`/`{duration}`) a partir do i18n.

Ícones customizados PixelLab em `assets/sprites/icons/`: `armor_shield`, `intent_attack`, `intent_defense`, `status_poison`, `status_weak`, `status_vulnerable`, `status_strength`, `status_dexterity`.

O painel do canto de inimigo (antigo `HudEnemyPanel`) foi aposentado. `GameUI.lua` só delega pro `HudManager`. Ver [`memory/ui_rendering.md`](memory/ui_rendering.md) e [`tools/preview_battle_hud.lua`](tools/preview_battle_hud.lua).

### Smoke
`SmokeSystem` spawna partículas que sobem lentamente. 4 presets em `SmokeConfig`. Pode ser alterado em runtime via teclas 1-4.

---

## 9. Convenções do projeto

- **OOP via metatables:** `setmetatable({}, Klass)` onde `Klass.__index = Klass`. Construtor `Klass:new()`.
- **Strings de UI:** português. Mensagens de `print()` de debug também.
- **Posicionamento responsivo:** sempre `Config.Utils.getResponsiveSize(ratio, maxSize, dimension)` ou `love.graphics.getWidth()/getHeight()` direto — nunca hard-code coordenadas.
- **Fontes:** use `FontManager.getResponsiveFont(ratio, maxSize)` ou `FontManager.getFont(size)` para aproveitar cache. Ao trocar resolução, chame `FontManager.clearCache()`.
- **Cores:** sempre de `Theme.Colors` — evite hex/RGB literais fora de Theme.
- **Áudio:** use `Sfx.play("name")` de `src/systems/Sfx.lua` (wrapper pro `_G.audioSystem`). Os fallbacks legados com `love.audio.newSource` direto foram removidos — não reintroduzir.
- **`print()` é o "logger" do projeto** — há muitos `print` de debug. Não remova em massa sem checar.
- **Efeitos de cartas** são **data-driven** via `effects = {...}` no CardDatabase. Evite `if card.name == "X"` — use o array `effects`.
- **Sequências temporais usam `_G.EventManager`** (ex: `EventManager.after(0.3, function() ... end)`) — evita state machines ad-hoc. Ver `memory/engine_layer.md`.
- **Decisões de RUN usam os streams do `Rng`** (`src/systems/Rng.lua`): `Rng.get():random("card"|"shop"|"map"|"event"|"enemy"|"misc", ...)` — NUNCA `love.math.random` em ofertas/mapa/eventos/economia (quebra a reprodutibilidade por seed e o anti-save-scum). Visual/cosmético (partículas, smoke, jiggle) continua no RNG global. Estado salvo em `run.rngState`; pity de raridade mora em `rng.meta.cardPity`. Ver `memory/rng_and_offers.md`.
- **Juice visual** (kick de scale/rot em objetos) via `Moveable.juice_up(obj, 0.3, 0.1)` ou `obj:juice_up(...)` se já tiver o método. Card já compõe — use nos momentos "algo aconteceu".
- **Card FX** (dissolve/materialize/explode/flip) já disponíveis: `card:start_dissolve(...)`, `card:start_materialize(...)`, `card:explode(...)`, `card:flip(...)`. Sequências prontas em `src/systems/CardRevealSequence.lua`. Ver `memory/card_fx_pipeline.md`.
- **Shaders**: `shaders/dissolve.glsl`, `flash.glsl`, `booster.glsl`, `holo.glsl` foram **reescritos do zero** (Fase 2 do refactor Balatro, Abril/2026) com matemática própria — value noise hash-based + FBM + multi-banda iridescente. Copyright-safe. Novos: `foil.glsl`, `polychrome.glsl`, `negative.glsl` pra editions (Fase 3).

### Anti-patterns observados (a evitar ao editar)
- **REGRA DE PROFUNDIDADE do WorldRoad (lei do projeto, pedido explícito Jul/2026):** TODO elemento novo da cena entra no painter **intercalado por profundidade (`rel`)** — nunca em "camada global por tipo". O padrão é o do v7.5: `drawProps` descarrega fatias de grama entre as árvores (`flushGrassTo` → janelas `relFrom`/`relTo` do GrassField); um elemento na frente do pé de uma árvore desenha DEPOIS dela; atrás, ANTES. Vale pra pedra, animal, efeito, personagem — e também na LUZ (`LightEngine.submitOccluder` com `z`). Elemento desenhado em camada plana por cima do campo é bug, não estilo.
- `src/ui/HudPanel.lua` e `src/ui/VisualEffects.lua` foram removidos no refactor de Abril/2026 (eram legado). Não recriar.
- **Cartas não devem ter `effects = {}` sem tags significativas.** Starter/básicas OK. Rode `love . validate_cards` antes de commitar.
- **Nunca condicione por `card.name`** — use `card.effects` + `card.tags` (data-driven).
- **Jokers nunca passam por `addCardToRun`/`currentDeck` direto** — sempre via `Game:addJokerToRun` (ou via `addCardToRun` que bifurca). Joker é separado de hand/deck (padrão Balatro G.jokers); persistido em `runManager.currentRun.jokers`. Romper esse invariante reabre o bug "mesmo joker pode ser jogado várias vezes".
- **Strength/Dexterity são adicionados em Game:processCardInCombat via `statBonus`** — não duplicar no `EffectSystem:applyCardEffects`. O effect `strength_scaling`/`dexterity_scaling` é flag-only (semântica para tooltip/validador).
- **Triggers em cartas non-joker** funcionam via `context.sourceCard` em `applyTriggerEffects`. Para fazer uma defense card refletir, adicione `{ type="on_defend_damage", value=N }` ao `effects` da carta — o trigger fica visível em jokerSlots E em sourceCard.
- Cartas procuram imagens em `assets/cards/attack/theRock.png` como fallback — muitas cartas ainda reusam por falta de arte (não é estilo, é débito).
- Ao adicionar novo tipo de effect: implemente em `EffectSystem` + adicione em `PROCESSED_EFFECT_TYPES` de `tools/validate_cards.lua`.
- Ao adicionar nova tag: só use após incluir em `TagSystem.CATALOG`.

---

## 10. Como adicionar conteúdo

### Nova carta
Edite `src/systems/CardDatabase.lua` dentro de `cardData.cards`:
```lua
warrior_nova_carta = {
  id = "warrior_nova_carta",
  name = "Nome",
  type = "attack", -- attack / defense / joker / effect
  cost = 1,
  attack = 10, defense = 0,
  class = "warrior", -- vincula ao pool de recompensas da classe
  rarity = "common", -- common / uncommon / rare / legendary / basic
  image = "assets/cards/attack/theRock.png",
  description = "...",
  effects = { {type = "damage_bonus", value = 3} },
}
```
Para incluir no starter deck da classe, edite `CardRegistry:getStarterDeckForClass`.

### Novo joker com efeito customizado
Adicione em CardDatabase com `type = "joker"` e `effects = { {type = "damage_multiplier", target = "attack", value = 2.0} }`. Se o tipo de efeito é novo, estenda `EffectSystem:processEffect` ou `:processTriggerEffect`.

### Novo background
Adicione em `BackgroundConfig.BACKGROUNDS` com `path`, `scaleMode` (cover/contain/stretch), `opacity`, `tint`. Use com `BackgroundConfig.loadBackground("KEY")` + `BackgroundConfig.drawBackground(...)`.

### Novo som
No `love.load` em `main.lua`: `audioSystem:loadSound("nome", "audio/arquivo.mp3", volume)`. Depois `_G.audioSystem:playSound("nome")`.

---

## 11. Dicas para a LLM

- **Leia antes de editar.** `CardDatabase.lua` tem ~1300 linhas e a maioria das cartas reusa arte — não assuma que o `image` precisa mudar.
- **Não mexa em `conf.lua` casualmente** — mudar versão ou desabilitar módulos pode quebrar o jogo silenciosamente.
- **Ao editar `Game.lua`**, lembre que `playSelectedCards` remove as cartas da mão **antes** da animação iniciar — isso é intencional para evitar duplo-clique.
- **Ao editar renderização de cartas**, teste hover em (a) cartas na mão, (b) cartas de reward (flag `isRewardCard`), (c) jokers ativos no topo — as três têm lift/depth diferentes.
- **O jogo só roda com `love .` do diretório raiz** (conf.lua fica lá). Os diretórios `test-audio/` e `test-game/` são scratchpads isolados.
- **Áudio costuma falhar silenciosamente no WSL2** — se o som "não funciona", cheque o console para o banner `=== STATUS DO ÁUDIO ===` antes de investigar o código.
- **Ao alterar Config.lua**, muitos arquivos leem os mesmos ratios — uma mudança pequena pode realocar layout globalmente. Verifique visualmente.
- **Use o diretório `memory/`** no root do projeto para anotações detalhadas por subsistema (veja seção 13 abaixo).

---

## 11b. Testes automatizados

Não há framework externo — cada teste é um módulo Lua em `tools/` com `M.run() -> bool` (true = passou), rodado via dispatcher em `main.lua` (`love . <nome>`). Todos rodam headless-ish dentro do LÖVE; qualquer arg de tool seta `_G.HEADLESS_TOOL=true`, então **saves vão para `*.tool.lua` — o save do jogador nunca é tocado**.

**Comandos:**
- `love . test_all` — **suite COMPLETA** (unit + integração + smoke + validação + i18n). Roda cada suite em pcall, imprime resumo por suite + total geral, exit code 0/1. É o comando a rodar antes de commitar.
- `love . test_one <nome>` — roda UM teste isolado (ex: `love . test_one test_combat`), útil pra iterar.
- `love . smoke_all` — só os smoke tests de sistema (legado; subconjunto de `test_all`).

**Infra compartilhada:** [`tools/testkit.lua`](tools/testkit.lua) — helpers de asserção (`t:eq/near/truthy/throws/...`) + fábricas: `TK.newRunGame(class)` (Game de run pronto), `TK.pump(game, secs)` (avança EventManager/animações — combate é diferido pro apex), `TK.mockGame()` (game leve pra EffectSystem isolado), `TK.seedRng(seed)` (Rng determinístico). Novos testes DEVEM usar o testkit e ser registrados em [`tools/run_all_tests.lua`](tools/run_all_tests.lua).

**Cobertura por domínio (novos, Jul/2026):** `test_entities` (Player/Enemy: dano/armadura/mana/buffs/orbs/status/fúria/intent), `test_economy` (ouro/juros), `test_progression` (RunManager/MapManager/ActSystem: atos/andares/endless), `test_forge` (upgrade/custo forja), `test_cards` (catálogo inteiro instancia + rollRarity + pools), `test_effects_full` (todo tipo de efeito + orbs + triggers), `test_combat` (seleção/mana/pipeline de dano/vitória/derrota/jokers), `test_events` (roll/no-repeat + toda opção aplica sem crash). Somados aos smoke pré-existentes + `validate_cards` + `test_i18n` = **22 suites**.

Nota de comportamento fixada pelos testes: `poison` decrementa **`duration`** por turno e os `stacks` persistem (dano = stacks a cada turno, por duration turnos). O texto i18n foi corrigido (Jul/2026) para refletir isso — antes dizia erroneamente "perde 1 stack por turno". `vulnerable` só existe no Enemy (Player não tem esse caminho).

---

## 12. Status e lacunas conhecidas (pós-redesign)

- ✅ Efeitos `channel_orb`/`evoke_orb`/`strength_scaling`/`exhaust`/`innate`/`mystery` **implementados** (Fase 2).
- ✅ Sistema de **tags** + **combos** ativos (Fases 1 e 3).
- ✅ **MapManager** com node choices (Fase 4), **ActSystem** com 3 atos + endless (Fase 5).
- ✅ **RestScreen** + **EventScreen** (Fase 6). Shop reusa CardRewardScreen.
- ✅ Starter deck de **2 cartas** (Fase 5). Rebalance nas 96 cartas (Fase 7).
- ✅ **STS-improvements v1** (Jul/2026, `docs/plan/sts-improvements-v1.md`): RNG seedável com 6 streams + estado no save; **pity de raridade** + **afinidade por tags do deck** nas ofertas (rewards+loja, com badges e "?" explicativo); **forja infinita** (cap 0) com preview/tooltip/custo crescente na loja; TopBar com ato/andar + tooltips em tudo + ouro direcional; rewards com raridade nomeada e skip claro; eventos com custos explícitos `[+/-]`, 4 eventos de deck e no-repeat por ato; picker de carta genérico (`_G.openCardPicker`). Teste: `love . test_systems`. Ver `memory/rng_and_offers.md`.

Pendente:
- Menu "Sobre" ainda é placeholder.
- 12 cartas ainda com `effects = {}` (intencionalmente — são âncoras de tag starter/básicas).
- Save/load existe mas sem botão "Continuar" no menu.
- Alguns eventos narrativos avançados (trocas complexas Slay-style) não mapeados.
- HUD legacy com gradientes 20-step (não é do redesign de gameplay).

Ver [`memory/known_gaps.md`](memory/known_gaps.md) para lista completa e contexto.

---

## 13. Memory — contexto detalhado por tópico

O diretório `memory/` na raiz do projeto guarda notas persistentes que complementam este arquivo. Use-as quando precisar de profundidade além do resumo acima. Cada arquivo tem frontmatter (`name`, `description`, `type`).

- [`memory/MEMORY.md`](memory/MEMORY.md) — índice.
- [`memory/project_overview.md`](memory/project_overview.md) — identidade, stack, inspirações.
- [`memory/architecture.md`](memory/architecture.md) — mapa detalhado das camadas (core/systems/components/ui/pixel art).
- [`memory/gameplay_systems.md`](memory/gameplay_systems.md) — turnos, turnContext, efeitos processados, dois modos de deck.
- [`memory/tag_system.md`](memory/tag_system.md) — catálogo canônico de tags.
- [`memory/combo_rules.md`](memory/combo_rules.md) — 11 regras ativas do ComboSystem.
- [`memory/run_progression.md`](memory/run_progression.md) — atos, nodes, flow entre batalhas, endless.
- [`memory/balance_curves.md`](memory/balance_curves.md) — HP/dano/gold/raridade por ato.
- [`memory/archetypes.md`](memory/archetypes.md) — 10 builds viáveis + cartas-âncora.
- [`memory/card_database.md`](memory/card_database.md) — schema de carta pós-redesign.
- [`memory/pixel_art_system.md`](memory/pixel_art_system.md) — pipeline procedural.
- [`memory/ui_pixel_system.md`](memory/ui_pixel_system.md) — chrome de UI pixel.
- [`memory/combat_animation.md`](memory/combat_animation.md) — fases + `isBlocking()`.
- [`memory/audio_system.md`](memory/audio_system.md) — `_G.audioSystem`, WSL2.
- [`memory/ui_rendering.md`](memory/ui_rendering.md) — Card 3D, HudManager.
- [`memory/conventions.md`](memory/conventions.md) — OOP via metatables, PT-BR, Config.
- [`memory/known_gaps.md`](memory/known_gaps.md) — o que é intencional vs pendente.
- [`memory/run_instructions.md`](memory/run_instructions.md) — como rodar, smoke tests, atalhos.
- [`memory/rng_and_offers.md`](memory/rng_and_offers.md) — Rng streams (seed/save), pity, afinidade, forja infinita, eventos v2, `love . test_systems`.

**Developer guide visual:** [`src/ui/README_PixelArt.md`](src/ui/README_PixelArt.md) — tutorial completo de como adicionar cartas, ícones, patterns e tunar estética.

**Atualize os memories** quando o comportamento real do código divergir do que está escrito. O código é a fonte de verdade; memory é o resumo amigável-para-LLM.

---

## 14. Sistema de Arte Pixel (estilo grimório sépia)

Visual inspirado nas cartas antigas (`assets/cards/*.png`) — **pergaminho envelhecido + ilustração dramática central + moldura ornamental**. O compositor é **decomposto em componentes** (`src/ui/card/`) pra escalar.

**Entrada do pipeline:**

```
CardDatabase:createCardInstance(cd)
    ↓
CardFrame.render(instance)           -- orquestra 7 componentes, cacheia 96×144 por ID
    ├── CardArtSlot   (fundo pergaminho + pattern PNG overlay + ilustração 64×64)
    ├── CardDecoration (sparks/dust/smoke/flash opcional)
    ├── CardBorder    (outline + borda tipo + cantos raridade)
    ├── CardHeader    (banner com nome dourado)
    ├── CardCostBadge (disco aço canto sup. esq.)
    ├── CardRaritySeal(disco raridade canto sup. dir.)
    └── CardStatsFooter(banner inferior: ATTACK/DEFENSE/... + valor)
    ↓
instance.image = canvas
instance.visualEffect = "holo" | "glow" | nil
    ↓
Card:draw()                          -- HoloShader em rare/legendary
    ↓
CRTShader                            -- pós-processamento full-screen
```

**Módulos-chave:**

| Módulo | Função |
|---|---|
| `src/ui/Palette.lua` | 16 cores DR-Darkworld (legacy) + **seção Grimoire** (PARCHMENT_*, INK, BLOOD, STEEL, AGED_GOLD, MOSS, RUST). Aliases ATTACK/DEFENSE/JOKER/EFFECT/RARITY_* agora sépia. |
| `src/ui/PixelCanvas.lua` | Primitivas nearest-filter: rectOutline, drawBitmapScaled, dither25, hline. |
| `src/ui/PixelIcons.lua` | 25 matrizes 16×16 (**fallback** — 33 PNGs em `icons/` agora têm prioridade). |
| `src/ui/IconLoader.lua` | Resolve nome → PNG em `assets/sprites/icons/<name>.png` OU matriz. |
| `src/ui/CardArt.lua` + `src/data/card_art.lua` | Atlas cardId → {icon, bgPattern, accent, decoration, effect}. |
| `src/ui/CardFrame.lua` | Orquestrador fino (~80 LOC). Cache por ID. |
| `src/ui/card/BackgroundLoader.lua` | Carrega PNG de `assets/sprites/backgrounds/patterns/` com cache. |
| `src/ui/card/components/*.lua` | 7 componentes (border, header, costBadge, raritySeal, artSlot, decoration, footer). |
| `shaders/crt.glsl` + `CRTShader.lua` | Balatro full-screen (toggle em Settings). |
| `shaders/holo.glsl` + `HoloShader.lua` | Foil rainbow em rare/legendary. |

**Assets gerados via PixelLab.ai MCP** (contrato documentado em [`memory/sprite_design_queue.md`](memory/sprite_design_queue.md)):
- `assets/sprites/icons/*.png` — **33 ilustrações 64×64** (sword_short, sword_great, dagger, axe, claw, fang, shield_round, shield_kite, armor_plate, helm, bolt, fireball, crystal, rune, orb, barrier, snowflake, water_drop, flame, heart, skull, skull_crowned, eye, mask, jester_hat, potion_red, potion_blue, gem, coin, scroll, star, moon, question).
- `assets/sprites/backgrounds/patterns/*.png` — **17 texturas 64×64** tileáveis (stone, blood, metal, rage, fire, wind, void, abyss, ghost, impact, wave, storm, arcane, ice, soft, poison, shadow).
- `assets/sprites/characters/joker_*_dir/` — **4 jokers chibi** multi-direção (joker_abyss, joker_shield, joker_vampire, joker_jester).
- `assets/sprites/_style_reference.png` — espada âncora do contrato visual.

**Hierarquia por raridade:**
- `common`: outline ink + borda tipo simples
- `uncommon`: + cantos decorativos verde-musgo
- `rare`: + borda interna `BLOOD` + halo rarity seal + HoloShader glow 0.35
- `legendary`: + borda interna dourada + cantos `AGED_GOLD` com highlight + halo dourado + HoloShader holo 0.75

**Hierarquia por tipo:**
- `attack` → accent `BLOOD` + footer "ATTACK"
- `defense` → accent `STEEL` + footer "DEFENSE"
- `joker` → accent `AGED_GOLD` + footer "PASSIVE"
- `effect` → accent `MOSS` + footer "ACTION"

**Dimensões:**
- Canvas por carta: **96×144 pixels** lógicos
- `Config.Cards.BASE_SCALE = 1.333` → cartas de ~128×192 na tela (mesmo espaço do layout legado).
- Ilustração central: 64×64 centralizada na art slot interna (88×107).

**Ícones animados (cartas "vivas", Jul/2026):** cartas podem ter a ilustração central em loop idle. Frames em `assets/sprites/icons_anim/<icon>/frame_NNN.png` (+ `meta.lua` com fps) → `CardFrame` pré-renderiza um canvas da carta POR FRAME; `instance.image` é o canvas ESTÁTICO (frame 0) e `CardFrame.liveImage(card)` devolve o canvas vivo (blitado por `CardFrame.update()` no `love.update`). **A animação só aparece na INTERAÇÃO** (regra do dono): hover/carta selecionada (`Card:draw` cuida — cobre mão, loja, rewards), hover no grid + inspeção ampliada (CollectionScreen), hover da classe (ClassSelectionScreen), hover no deck viewer. Idle = estático. Warp/holo/editions pegam a animação de graça — nunca desenhar o ícone animado como overlay. Gerar via `tools/pixellab_animate_card_icons.py` (queue/poll/check); validar com `love . preview_card_anim <card_id>` + `love . screenshot_collection <card_id>`. **Doutrina:** olhar a arte (Read no PNG) ANTES de escrever o prompt de animação, e intensidade do movimento segue a raridade (basic=quase imperceptível → legendary=vivo). Ver [`memory/card_icon_animation.md`](memory/card_icon_animation.md).

**Como adicionar arte nova:** ver [`src/ui/README_PixelArt.md`](src/ui/README_PixelArt.md) (guia passo-a-passo atualizado).
