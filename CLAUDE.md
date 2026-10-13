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
│   ├── QuadMesh.lua            # Lote de quads escrito via FFI + 1 Mesh por passada (domo, estrada, grama do WorldRoad)
│   ├── GrassField.lua          # Motor de vegetação rasteira (SpriteBatch, vento 3 camadas, presets por bioma) — base do cenário WorldRoad
│   ├── LightEngine.lua         # Motor de iluminação 2D do WorldRoad (lightmap ¼ multiply-only, micro-luzes, zero stencil) — memory/lighting_engine.md
│   ├── ShadowEngine.lua        # Motor de sombras projetadas de silhueta (direção pelo sol, comprimento pelo horário, fila pós-grama) — memory/shadow_engine.md
│   ├── LuminaireEngine.lua     # Motor de props emissores de luz (catálogo 2-3 luminárias/bioma, âncora de chama por conteúdo, cadência de spawn, brasas) — memory/luminaire_engine.md
│   └── WeatherEngine.lua       # Clima FINO com profundidade (1 px de tela, densidade pela chegada ao castelo, vagalumes com poça de luz, flush nas fatias da grama, vento do GrassField, raio multiply-only) — memory/weather_engine.md
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
│   ├── IntroTube.lua           # ABERTURA (Out/2026): página de pergaminho + o nosso televisor pequeno (mesmo crt.glsl via `CRTShader.renderTube`) datilografando título/subtítulo e mergulhando no tubo; o CRT de tela cheia liga SÓ no mergulho (`BootScene` fase `intro`, `onTubeOn`); com `src/data/intro_computer.lua` (arte do computador gerada + tela magenta, instalada por `tools/intro_computer_import.py`) o tubo vai DENTRO da tela da arte, uma CARTA entra pela fenda do disquete (fase `insert`, recorte na linha da fenda) e o zoom é na tela — memory/intro_tube.md
│   ├── GameplayScene.lua       # Estado "playing": combate + mão + jokers + drag/reorder
│   └── EndScreens.lua          # drawGameOver + drawVictory
├── components/                 # UI de alto nível (telas, widgets)
│   ├── Menu.lua                # Menu principal (+ FITA ticker no pé com borda de 4 px; rodapé sobe `Menu.RIBBON_H`) — memory/intro_tube.md
│   ├── ClassSelectionScreen.lua# Seleção de classe por EMBLEMA (não personagem) + estado bloqueado/maestria via UnlockSystem — memory/class_emblems.md
│   ├── GameUI.lua              # HUD do gameplay (só delega ao HudManager)
│   ├── CardRewardScreen.lua    # Loja / recompensas pós-batalha (inclui refresh). Loja = Balcão do Mercador (ShopScene/ShopLayout/ShelfItem em src/ui/shop/); v5: vitrine posicionada por parâmetros centrais `ShopLayout.SHELF/TABLE/PLAQUE` em px de arte, preço = plaquinha de latão sob a carta e etiqueta pendurada pela borda da bancada nos objetos (balança no hover), cavalete com volume, hover sem levitar (pacote/poção/cristal flutuam), sons e faíscas por objeto, artes v5 (`assets/sprites/shop/v5`), pergaminho medido (texto nunca corta), zona de leitura do CRT (`CRTShader.setCalmRect`), memory/shop_layout.md v5
│   ├── TopBar.lua              # Barra superior (ouro, deck, ícone config)
│   ├── SettingsMenu.lua        # Abas Áudio/Vídeo/Jogo/Idioma em altura fixa, controles [<] valor [>] (Idioma = LISTA direta, nunca ciclo); VOLTAR retorna ao Pause; SettingsMenu.applyRuntime(settings) no boot (vsync, combatSpeed → CombatBeats.speed)
│   ├── PauseMenu.lua           # Pausa v4 limpa (classe·jornada + semente miúda, atalhos D/J/M em ícone, Continuar primário, abandono = link discreto em 2 etapas); teclado/gamepad via src/ui/MenuKit.lua; _G.togglePauseMenu
│   ├── CreditsScreen.lua       # Créditos (LÖVE/zlib, fonte/OFL) — substituiu o "Sobre" placeholder
│   ├── UnlockShowcase.lua      # Revelações no MENU pós-corrida estilo Balatro (carta/classe/selo/conquista/maestria, um painel por vez); fila persistida no perfil por `src/systems/UnlockQueue.lua` (sobrevive a fechar o jogo)
│   ├── JokerSlot.lua           # Slot visual de joker ativo
│   ├── DeckViewerScreen.lua    # Deck da run em TELA CHEIA (estilo Coleção); abre por clique no deck da TopBar OU tecla D; hover c/ tooltip + forja aplicada
│   ├── JokerManagerScreen.lua  # Gerenciador de Coringas (tela cheia): coleção+bancada, escolhe quais MAX_JOKER_SLOTS ativar; abre por clique no quadro de coringas OU tecla J; _G.toggleJokerManager
│   ├── RunJournalScreen.lua    # ROTEIRO da jornada (tela cheia, sem cenário): o caminho JÁ percorrido em capítulos por ato, coluna = andar, resultado escrito sob cada parada + castelo do bioma fechando a linha; layout puro em `src/ui/RunJournalLayout.lua`; abre por clique no indicador de ATO da TopBar OU tecla M; _G.toggleRunJournal
│   └── Button.lua              # Widget botão: clean (Balatro-inspired, default) | ornate | invisible
├── src/
│   ├── core/
│   │   ├── Game.lua            # Orquestrador (turnos, deck, combate, hooks de settings)
│   │   ├── Config.lua          # Constantes centrais (UI ratios, gameplay, cards, audio)
│   │   ├── BackgroundConfig.lua# Loader e drawer de backgrounds configuráveis
│   │   ├── Debug.lua           # Logger condicional (log/trace/warn/err)
│   │   └── Release.lua         # Modo DEV × RELEASE (flag = existência de build_info.lua), identity do save, errorhandler amigável + crash log — memory/release_pipeline.md
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
│   │   ├── EnemyRoster.lua     # Quem luta em cada nó: pool por ato × tipo (src/data/enemies.lua), stream "enemy", sem repetir — memory/enemies.md
│   │   ├── CombatBeats.lua     # METRÔNOMO: fila "beats" — um acontecimento por instante, bloqueando o próximo (tabela de tempos única) — memory/combat_beats.md
│   │   ├── CardDatabase.lua    # Loader fino (~170 LOC) que merge src/data/cards/*.lua
│   │   ├── CardRegistry.lua    # Classes + pools por raridade + rolagem (substitui ClassSystem); _poolFor filtra UnlockSystem.isCardUnlocked
│   │   ├── UnlockSystem.lua    # Meta-progressão: cartas/classes desbloqueáveis, maestria por classe (5 níveis × pacote de 3), descoberta (Coleção "?"); dados em src/data/unlocks.lua — memory/unlocks.md
│   │   ├── AchievementSystem.lua # Conquistas (gatilhos inline, padrão StS); catálogo em src/data/achievements.lua; ícones próprios via src/ui/AchievementIcons.lua
│   │   ├── SteamBridge.lua     # Mapa conquista → API name Steam; no-op AVISADO sem Steam — memory/steam_achievements.md
│   │   ├── ResumeFlow.lua      # Continuar retoma pelo run.stage (battle/cashout/rewards/rest/event/shop/fork/*_done) — memory/save_system.md
│   │   ├── DeckManager.lua     # Modo clássico: decks estáticos
│   │   ├── RunManager.lua      # Modo Slay the Spire + save/load via love.filesystem
│   │   ├── EffectSystem.lua    # Efeitos data-driven (jokers, effect cards, triggers)
│   │   ├── CombatSequence.lua  # Coreografia do combate via EventManager (voo das cartas, impacto, dissolve) sobre a fila do CombatBeats
│   │   ├── CardFeel.lua        # Game feel v1: tema AV por carta (tag→som+burst temático) — memory/card_feel.md
│   │   ├── ScreenShake.lua     # Shake global (_G.triggerShake via .install())
│   │   ├── CardParticles.lua   # Partículas attach-to-card (dissolve/materialize)
│   │   ├── EconomySystem.lua   # Ouro, juros tipo TFT
│   │   ├── ShopSystem.lua      # Ofertas da loja (cartas + upgrades + refresh)
│   │   ├── (áudio → engine/AudioManager.lua; facade Sfx.lua abaixo)
│   │   ├── WeatherAudio.lua    # Som do clima: camas sem loop fixo (vozes em crossfade de variantes), avulsos, trovão por distância; watchdog no love.update — memory/weather_engine.md
│   │   ├── Sfx.lua             # Wrapper thin: Sfx.play("name") ao invés do guard repetido
│   │   ├── MessageSystem.lua   # Toasts in-game com fade
│   │   ├── ParticleSystem.lua  # Partículas genéricas
│   │   └── SmokeSystem.lua     # Smoke atmosférico (4 presets)
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
│   │   └── UpgradeTile.lua     # Tile da RELÍQUIA (upgrade da loja): bandas nome/arte/chip/preço + layout()/validate() puros
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
- `r` (reinicia) e `1/2/3/4`/`0` (presets de smoke) só existem no **modo clássico em DEV** — numa run eram armadilha (R recriava o player e o checkpoint gravava isso). A tecla `f` foi removida: fullscreen só por **Configurações → Vídeo** ou arrastando a borda.
- **Gamepad**: só dentro de modais (D-pad/A/B/ombros) + START/BACK pausa durante a run.
- `esc` no menu principal pede confirmação antes de sair; "Jogar" com corrida salva pede confirmação.
- `g`: abre o **Guia** (combos gerados do ComboSystem + glossário de palavras-chave) em qualquer tela da run; também pelo atalho "Guia [G]" da Pausa (`components/GuideScreen.lua`).
- **Tutorial = o corvo narrador Pena** (`src/systems/Tutorial.lua` + `src/ui/Narrator.lua`, `memory/onboarding.md`): roteiro da 1ª corrida em conversas curtas, máquina de escrever com blip, véu com RECORTE no objeto explicado; falas de AÇÃO ("selecione uma carta") só deixam passar o clique dentro do recorte (`Tutorial.blocksPointer/blocksKey` no main.lua). Só fala com a cena QUIETA (`GameplayScene.isQuiet`: no chefe, só depois da porta). Esc/B pula a conversa; Configurações → Jogo liga/desliga e recomeça. Objeto novo que mereça explicação: reporte `Tutorial.anchor(id, ...)` no draw dele.
- `d` / `j` / `m`: abrem, em qualquer tela da run (inclusive descanso, evento e cash out), o **Deck Viewer**, o **Gerenciador de Coringas** e o **Roteiro da jornada**. Os três também abrem por clique no bloco correspondente (deck / quadro de coringas / indicador de ATO).
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
5. `onCombatAnimationComplete` → `ComboSystem.applyOnceEffects` (hoje só o banner — combos simples não têm prêmio de fim de jogada) → `turn = "enemy"`.
6. `Game:enemyTurn()` — executa o golpe CONGELADO do **kit** do inimigo (`src/data/enemies.lua`, ver `memory/enemies.md`): bloqueio > golpe(s) > espinhos > debuffs no jogador > força/cura/invocação/carga, um beat cada:
   - `performAttack` (considera `weak`)
   - `takeDamage` aplica no player
   - `enemy:onTurnEnd()` → poison DoT + decrementa durations de debuffs
   - `player:restoreMana`, `player:onTurnStart` (decrementa buffs), `drawCard`
   - `applyTriggerEffects("turn_start")` → regen/DoT do player
7. Se `game:isPhaseCleared()` (enemy.health ≤ 0):
   - Run mode: `showCardRewards()` → `continueAfterReward` → `showMapSelection` → escolha → dispatch
   - Classic: `game:nextPhase()` direto
8. `nextPhase()`:
   - Limpa `_exhaustedThisBattle` — **Exaurir é POR BATALHA**: a carta sai do baralho até a próxima batalha e VOLTA no próximo andar (não remove da run; auditoria Jul/2026 corrigiu esta doc — o código sempre foi por batalha)
   - Ganha ouro, reseta mana
   - Usa `ActSystem.getEnemyStats(actNumber, floorInAct, nodeType)` para stats do próximo inimigo
   - Cura inter-ato 30-40% quando cruza para novo ato
9. **Vitória**: `actNumber >= Config.TotalActs` (hoje 6) AND `floorInAct >= 8` AND `currentNode.type == "boss"` AND enemy morto AND **NÃO** `endlessMode`. Após vencer, opção de entrar em endless. O `endlessMode` desliga a vitória, então qualquer caminho que o ligue cedo demais torna o jogo invencível — foi o que aconteceu ao passar de 3 pra 6 atos (defect_doctrine 14).
10. **Endless** (Out/2026): a tela de vitória oferece **Seguir no Endless** — `Game:enterEndless()` só aceita run com `run.campaignWon` (gravado no `checkVictory`, viaja no save), liga `endlessMode` e devolve a run ao jogo (cash out → recompensa → encruzilhada → `advanceFloorInAct` = `endless_start`; ciclos seguintes = `endless_cycle`). `run.floorsInEndless` = andar absoluto do endless (curva `exp(LIN·n+QUAD·n²)` de `ActSystem.endlessFactors` via 4º arg de `ActSystem.getEnemyStats`, XP, conquistas `alem_da_pagina`/`ciclo_*`). Cada ciclo de 8 andares abre **maldição 1-de-2** empilhável (`EndlessCurseScreen`, obrigatória, reabre no Continuar); **Selos do Grimório** 1-10 (dificuldade cumulativa por classe, escolhida na seleção). Tudo por `src/systems/RunModifiers.lua`, que só multiplica por cima do jogo base — ver [`memory/endless_and_seals.md`](memory/endless_and_seals.md). Morte/abandono no endless: só XP dos andares extras, **nunca** outra vitória nem derrota no perfil. Telas finais (`src/scenes/EndScreens.lua`) têm botões mouse/teclado/gamepad + resumo da run; travas `test_endless` e `test_end_screens`.

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
| Progressão | Cap `VICTORY_PHASES=24` | **6 atos × 8 andares + endless** (era 3 até Set/2026) |
| Mapa | Nenhum | MapManager gera 2-3 node choices |
| Save/load | Não | `run.save.lua` via `love.filesystem` |

Flag: `game.isRunMode` + `runManager:hasActiveRun()`.

---

## 6. Tipos de carta + Tags + Effects (pós-redesign)

Todas herdam de `src/cards/base/Card.lua`. Toda carta tem **`tags = {}`** (array de strings do catálogo em `TagSystem.CATALOG`).

- **`attack`** — dano ao inimigo. Pipeline completo: `applyCardEffects` → `+player.strength` → `ComboSystem.applyToCardValue` → `applyJokerEffects`.
- **`defense`** — armor ao player (**cap por ato: 30/40/50** = `Config.Game.PLAYER_MAX_ARMOR` + `PLAYER_MAX_ARMOR_PER_ACT×(ato-1)`; zera todo turno, StS-style). Mesmo pipeline com `dexterity`. Truncar no cap gera toast `messages.armor_capped` (auditoria Jul/2026; cap fixo 30 sufocava builds de defesa no late game — 20+ turnos no cap medidos pelo autoplay).
- **`joker`** — slots (máx 3), `card.passive(game)` roda 1x, `card.effects` ficam ativos pelo resto da run.
- **`effect`** — `processEffectCard` executa, carta descartada.

**Tipos de effect processados** (fontes: `EffectSystem.processEffect` / `processEffectCard` / `applyCardEffects` / `processTriggerEffect`):
- **Continuous jokers**: `damage_multiplier`, `defense_multiplier`, `damage_bonus`, `defense_bonus`, `heal_multiplier`
- **Card self-effects**: `strength_scaling`, `dexterity_scaling`, `multi_hit`, `damage_bonus_self`
- **Effect cards / passives**: `instant_heal`, `restore_mana`, `increase_max_mana`, `add_armor`, `magic_damage`, `aoe_magic_damage`, `draw_cards`, `discard_cards`, `apply_debuff`, `apply_buff`, `gain_strength`, `gain_dexterity`, `channel_orb`, `evoke_orb`, `evoke_all_orbs`, `mystery`
- **Orbes PULSAM** (Jul/2026, `EffectSystem:orbPassiveTick` chamado em `Game:endTurn`): cada orbe canalizado dispara meio-efeito no fim do turno do jogador (raio=dano, gelo=armor, fogo=dano/3, holy=cura/3, sombra=cresce +2). Foco soma no valor antes da divisão. Sem isso o mago era 0/6 no autoplay (orbe inerte = dano anêmico).
- **Intent do inimigo é CONGELADO no anúncio** (`Enemy.nextIntentDamage`, setado em `rollNextIntent`): o golpe executado NUNCA excede o número que o jogador viu no HUD — Fúria/BUFF entre telegraph e execução só valem no próximo intent (anomalia "escudo furado" do autoplay). Weak aplica por cima (só reduz). Testes que mutam `enemy.damage` devem setar `nextIntentDamage` junto.
- **Flags**: `exhaust` (por batalha), `innate`, `retain`
- **Jokers multiplicadores NÃO compõem** (rebalance v2, Jul/2026): em `EffectSystem:applyJokerEffects`, só o MAIOR `damage_multiplier` e o MAIOR `defense_multiplier` entre jokers ativos contam (largest-wins); bônus flat somam todos. Regressões em `test_effects_full`.
- **INIMIGOS TÊM KIT PRÓPRIO** (Out/2026, `memory/enemies.md`): `src/data/enemies.lua` = roster por ato (3 comuns, 2 elites, mini-chefe próprio, chefe — todos do bioma) + golpes nomeados por criatura (multi-golpe, perfurante, debuff NO jogador — `weak`/`frail`/`vulnerable`/`poison`/`burn` em `player.debuffs`, decaem no fim do turno do inimigo pulando o turno aplicado —, carga, revoada, fases). O inimigo é sorteado no stream "enemy" quando o NÓ nasce (`node.enemyId`), nunca repete o último. Execução lê os CAMPOS do intent, não o `kind`; todo número (inclusive nº de golpes e Vulnerável) congela no anúncio. Roster SÓ do bioma do ato (`HOME_BIOME`, trava em `test_enemies`); chefe NÃO dá coringa extra (decisão do dono — deck perfeito tem que ser difícil). Golpe novo = nome nos 5 `enemy_kit` locales; trava `test_enemies`.
- **INIMIGO ENFURECIDO tem instante próprio** (Set/2026): cruzar 30% de vida (`Enemy:takeDamage`) dá +50% de dano permanente — antes era MUDO. Agora vira status `enraged` (nome obrigatório; `fury` é o anti-stall do turno 8+, outra mecânica) + beat bloqueante via `Game:announceEnrageIfPending`. `nextIntentDamage` segue congelado: o golpe já telegrafado não muda.
- **NÉVOA DE INTENÇÃO** (Out/2026, `memory/intent_visibility.md`): nos biomas frost (ato 4) e dusk (ato 6) e em criaturas com `veil` no kit, o HUD esconde o NÚMERO do intent (`type_only` → "?") ou o TIPO (`hidden` → ícone de desconhecido). `Enemy.intentVisibility` é resolvido UMA vez por anúncio (`Enemy:rollIntent` → `IntentVisibility.resolve`, stream "misc" — o "enemy" fica intocado), guardado com a causa (`fog`/`veil`/`reveal`). O golpe continua CONGELADO e exato: só a leitura muda. Dados em `src/data/intent_fog.lua` (por bioma; ausente = céu limpo) e `veil = { level, chance }` em `src/data/enemies.lua`. Contadores: efeito `reveal_intent` (Achar a Brecha, Expor Fraqueza, Visão Arcana, Pergaminho da Sabedoria) e o pulso do orbe de Raio (`revealNextIntent`). O WeatherEngine engrossa a nevasca pelo ESTADO (`fogHook`), nunca o contrário. Piloto e UI leem `getKnownIntent`/`getKnownIncomingDamage` (nil = escondido) — nunca `getIntent` pra decidir. Trava: `test_intent_visibility`.
- **ESPINHOS são ESTADO, não dano na hora** (Set/2026, `memory/combat_beats.md`): `on_defend_damage` ARMA `player:addBuff("thorn", 1, N)` quando a defesa é jogada; o dano só sai quando o **inimigo ataca** (beat `player.thorn_reflect` → `EffectSystem:fireThornReflect`), e o buff expira no upkeep seguinte. Antes o reflexo acontecia ao JOGAR a carta, mesmo que o inimigo nunca atacasse. A regra P2.3 sobrevive: joker ARMA 1×/turno, carta arma por carta — mesmo teto por turno, momento diferente. Travas em `test_beats` + `test_effects_full`.
- **Ofertas por ato** (rebalance v2): pesos de raridade vêm de `ActSystem.getRarityWeights(ato)` (A1 70/25/5/0 → A3 15/45/32/8); neutras `class="basic"` ofertáveis com peso 0.6; afinidade com cap progressivo 0.9/1.2/1.5 e blacklist de tags genéricas; elite→minRarity uncommon, boss→rare; oferta nunca repete joker possuído. Ver `memory/rng_and_offers.md`.
- **Triggers**: `on_attack_heal`, `on_defend_damage`, `regen_per_turn`, `damage_per_turn`

Ver `memory/gameplay_systems.md` para referência completa.

## 6b. Tags e Combos

Catálogo em `src/systems/TagSystem.lua` (`TagSystem.CATALOG`), categorias: archetype, mechanic, element, role.

**Combos SIMPLES (Out/2026, decisão do dono: "combos muito fortes e não explicados"):** as 13 regras por TAG saíram. `ComboSystem.RULES` tem TRÊS regras, todas bônus PLANO por posição na jogada (ordem de seleção), somado depois da Força e antes dos coringas:
- **Saraivada** (`volley`) — cada ATAQUE ganha +3 por ataque antes dele na jogada (2º +3, 3º +6, 4º+ +9)
- **Muralha** (`wall`) — cada DEFESA ganha +5 de Bloqueio por defesa antes dela (até +15)
- **Par** (`pair`) — cada cópia repetida da MESMA carta ganha +4 por cópia anterior (até +8)

Carta com a tag `combo` conta como duas na fila. Coringas de combo (`combo_boost`): Chuva de Lâminas / Muro de Escudos / Espelho Gêmeo dobram uma regra. Sem prêmio de fim de jogada. Como os combos antigos davam ~40% do dano e ~50% do Bloqueio e a curva de inimigos fora calibrada com eles, a força do inimigo caiu junto: `Config.Game.ENEMY_POWER = { damage = 0.75, health = 0.8 }` + `ENEMY_POWER_BY_ACT = { [3] = 0.9/0.9 }` (`ActSystem.getEnemyStats`; eram 0,8/0,85 até o Stage 2 de Out/2026). Ver `memory/combo_rules.md` e `memory/balance_curves.md`.

**Prévia de dano (Out/2026):** a conta de UMA carta mora em `DamagePreview.cardValue` (`src/systems/DamagePreview.lua`) — o combate (`Game:_resolveCardInCombat`) chama a MESMA função e só adiciona efeitos colaterais; `DamagePreview.simulate` simula a leva inteira (Ímpeto, Vulnerável/Força ganhos no meio, orbes, Bloqueio do inimigo, morte no meio). O painel (`src/ui/DamagePreviewPanel.lua`) mostra acima do JOGAR o total, LETAL, combos/coringas (hover explica) e a conta carta a carta; a barra do inimigo pisca o trecho que sai; carta que fecharia combo ganha selo `+COMBO`. Trava: `love . test_one test_damage_preview` (300 levas reais, divergência 0). Mudou `Enemy:takeDamage`, orbes ou efeitos? Atualize o `simulate`. Ver `memory/combo_rules.md` e `memory/damage_preview.md`.

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

**Música NUNCA sobrepõe música**: `AudioManager:playMusic` para toda faixa órfã do grupo `music` antes de montar o crossfade novo. O crossfade é UM só — uma troca que chega antes de a anterior terminar (abrir a forja e fechar faz ato→loja→forja→volta em segundos, com fade de 2,5s) substituía o registro e a faixa que saía nunca recebia `stop()`, ficando tocando para sempre. Trava em `test_music`.

**Trilha por contexto** (Set/2026): 9 faixas em `audio/music/` (6 atos, boss, loja, descanso) + `audio/music.mp3` (menu), registradas por SCAN em `main.lua` e escolhidas por `src/systems/MusicDirector.lua`, que OBSERVA `currentState` no `love.update` em vez de ser notificado pelas telas. Crossfade já existia no `AudioManager` (`playMusic(code, {fadeDuration})`). Faixa nova = soltar o mp3 na pasta. Validar a volta do loop com `love . check_loop` ANTES de commitar — o modelo cola fade-out nas pontas e isso só se ouve na virada. Ver [`memory/music_generation.md`](memory/music_generation.md).

### Ritmo do combate (`src/systems/CombatBeats.lua`, Set/2026)
Toda batalha é uma **fila de beats**: cada acontecimento (dano, buff/debuff no inimigo, proc de joker, pulso/evoke de orbe, veneno, compra) ocupa um instante só dele e SEGURA o próximo. `CombatSequence:isBlocking()` inclui `CombatBeats.isBusy()`. Os tempos vivem numa tabela única (`CombatBeats.HOLD`) com `CombatBeats.speed` como knob global. Sem `_G.EventManager` o push roda síncrono (API antiga preservada pra testes/autoplay). Ver [`memory/combat_beats.md`](memory/combat_beats.md).

### CombatSequence (`src/systems/CombatSequence.lua`)
Coreografia visual do combate sobre o `EventManager`: cartas voam pro centro (easing out-quart, escala 1.3x), cada uma resolve no apex (`onCardProcessed` → `Game:processCardInCombat`), dissolve depois dos procs de joker (`card._expectedProcs`) e os números de dano flutuam. `Game` ainda guarda a instância em `combatAnimationSystem` (nome histórico do módulo antigo, apagado em Abril/2026) e o fluxo de turno espera `isBlocking()`, que inclui `CombatBeats.isBusy()`. Os TEMPOS não moram aqui: vivem em `CombatBeats.HOLD` (seção acima).

### EconomySystem + ShopSystem
Ouro inicial $10; renda pela folha do cash out (`Game:_buildRoundEvalSources`): vitória `Config.Economy.victoryGold(ato)`, HP cheio, bônus de risco de elite/chefe (`Config.Economy.nodeBonus` — mini-chefe NÃO paga, é obrigatório) e juros Balatro `floor(ouro/5)` com teto comprável (Cofre). Loja: 4 cartas (raridade por ato, mesmo `pickRewardCard` das recompensas) + 3 relíquias (tesoura e bancada de coringa FIXAS até o teto + 1 rotativa, custos em `Config.Offers.SERVICES`) + 1 pacote; reroll 4+2n. Tabela de preços antes/depois e números medidos em [`memory/balance_curves.md`](memory/balance_curves.md). **Dados do Escriba** (aposta opcional, 1/loja, EV ~justo, save no frame do sorteio): [`memory/scribe_dice.md`](memory/scribe_dice.md).

### HUD (redesign STS + Balatro)
`HudManager` orquestra `HudPlayerPanel` (flat sepia com shield PNG pro armor), `PlayerBuffPills` (row acima do painel com strength/dexterity/focus), `OrbRow` (fileira de orbes ACIMA das pills — ver abaixo), e `ManaOrb` (canto inf-direito Balatro-style).

**OrbRow** (`src/ui/OrbRow.lua`, Jul/2026 — matou a "mecânica fantasma" dos orbes): módulo singleton estilo EnemyHud. Mostra TODOS os slots (vazio = aro apagado, ensina o cap 3), cada orbe com o **valor do PULSO escrito nele** (base+Foco ao vivo — fórmulas canônicas em `EffectSystem.orbPulseValue/orbEvokeValue`, fonte ÚNICA pra lógica e UI), FIFO esquerda→direita com triângulo no próximo-a-evocar, hover→StatusTooltip (`status.orb_*` nos 5 locales; ctx: stacks=pulso, duration=evoke), preview de evoke (hover em carta de Evocar → orbe alvo acende ciano e o número vira o valor de EVOKE, padrão `showEvokeValue` do StS). `EffectSystem` notifica animações via `notifyChannel/notifyPulse/notifyEvoke` (pcall, headless=no-op; a declaração de `notifyOrbUI` PRECISA ficar no topo do arquivo — local Lua só existe abaixo da definição). Pulso do fim de turno solta FloatingText saindo DO orbe (causalidade visível). Validação visual: `lovec . preview_battle_hud` (estado fake já tem mago + 2 orbes). Stats do inimigo ficam ancoradas **no sprite** via `EnemyHud` (HP bar sob os pés, intent icon custom acima, status pills circulares com ícones PixelLab), chamado em `main.lua` após `EnemyRenderer.draw(game, cx, cy)` que retorna o bbox.

**Tooltips** de status effects via `src/ui/StatusTooltip.lua` — singleton global, show() agenda, draw() chamado no final do frame de gameplay. Hover em qualquer pill (inimigo ou jogador) dispara tooltip com `status.<name>.name` + `status.<name>.desc` (interpolando `{stacks}`/`{duration}`) a partir do i18n.

Ícones customizados PixelLab em `assets/sprites/icons/`: `armor_shield`, `intent_attack`, `intent_defense`, `status_poison`, `status_weak`, `status_vulnerable`, `status_strength`, `status_dexterity`.

O painel do canto de inimigo (antigo `HudEnemyPanel`) foi aposentado. `GameUI.lua` só delega pro `HudManager`. Ver [`memory/ui_rendering.md`](memory/ui_rendering.md) e [`tools/preview_battle_hud.lua`](tools/preview_battle_hud.lua).

### Cinemática de chefe (`src/ui/BossCinematic.lua` + `src/data/boss_cinematics.lua`, Out/2026)
Porta abre → salão abre **VAZIO** → entrada do chefe dentro do salão (olhos no escuro, rasantes com rastro, pouso, cartão nome+epíteto) → HUD → luta; morte em câmera lenta + rajada + dessaturação + corpo no salão **antes** do cash out. Roteiro por dados (passos `{kind, dur}`), pular após 1 s, `reducedMotion` = roteiro curto, Continuar NUNCA repete a entrada. Overlay registrado PRIMEIRO no InputFocus; `main.lua` tem a exceção que deixa o relógio correr com ela no topo. Protótipo só no `carrion_king`. Ver [`memory/boss_cinematics.md`](memory/boss_cinematics.md).

### Fim de run (`src/ui/EndTransition.lua`)
Morte e vitória desligam o CRT e só trocam de tela no CALLBACK do desligamento. O gatilho é uma **condição** (`game:checkGameOver()` continua verdadeiro todo frame), não um evento — sem trava de reentrada cada frame reiniciava a animação e o callback nunca chegava ao fim: **tela preta permanente, sem input, só fechando o jogo** (bug do dono, Set/2026). A trava mora no módulo, fora do closure do `love.load`, porque precisava ser testável (`love . test_one test_end_transition`). **Regra geral: animação com callback disparada por CONDIÇÃO precisa de trava; disparada por EVENTO não.**

### Cortina da mão (`src/ui/HandDeal.lua`, Out/2026)
Mão, botões, coringas e prévia NÃO existem durante cutscene (viagem, porta, salão à espera do chefe, entrada/morte do chefe, quicada de chegada); no caminho do castelo o HUD espera junto. Quando a cortina sobe as cartas são DADAS uma a uma da pilha e só depois entram botões/HUD. Chefe sem roteiro ganha a entrada genérica (`BossCinematic.GENERIC`) — nunca "luta como antes" com a mão na tela. Trava: `test_hand_deal`. Ver [`memory/boss_cinematics.md`](memory/boss_cinematics.md).

### Smoke
`SmokeSystem` spawna partículas que sobem lentamente. 4 presets em `SmokeConfig`. Pode ser alterado em runtime via teclas 1-4.

### Game feel (CardFeel + JokerProcFx, Jul/2026)
Ver [`memory/card_feel.md`](memory/card_feel.md). Regras-chave: (1) o TEMA da carta (tags fire/ice/lightning/dark/holy/poison/heal/lifesteal/magic) define som de impacto (`impact*` em audio/sfx/) + burst de partículas com física (`gravity` no engine/Particles) — sem tema, fallback físico sword/armor; ataque também estoura NO INIMIGO. (2) `applyJokerEffects` retorna `(valor, procs)` e os jokers TICAM em sequência estilo Balatro (juice no slot + popup "×2"/"+3" + `jokerTick` com pitch crescente); o stagger do CombatSequence ESTICA via `card._expectedProcs` (`EffectSystem:predictJokerProcs`) e o dissolve da carta espera os procs dela. (3) **v2**: reação FÍSICA por tipo no impacto — ataque dá pulinho+tilt (`Moveable.hop_up`), defesa INCHA (`swell_up`, sem oscilação), efeito rebola com 3 camadas sonoras (cast→chime→resolve); joker proca com puladinha; **cada joker tem som assinatura** em `audio/sfx/joker-sig/<id>.mp3` (registro por SCAN — joker novo = dropar arquivo; fallback jokerTick via `Sfx.has`). Ao criar carta nova, dê tags de tema — o feel vem de graça.

---

## 9. Convenções do projeto

- **OOP via metatables:** `setmetatable({}, Klass)` onde `Klass.__index = Klass`. Construtor `Klass:new()`.
- **Strings de UI:** NUNCA cravadas no código — sempre `I18n.t("chave", vars, fallback)` com a chave nos **5 locales**. Isso inclui toasts (`addMessage`), rótulos de tabelas de dados exibidas (nome de ato, tipo de nó, oferta de loja) e títulos de tela. A trava `love . test_one test_no_hardcoded_pt` falha se um literal acentuado aparecer em caminho de desenho. Mensagens de `print()`/`Debug.*` de debug seguem em português — são ferramenta, não UI.
- **NUNCA declare `local` novo no escopo de arquivo do `main.lua`.** O `love.load` vive no TETO de 60 upvalues do LuaJIT: um único `local` a mais no topo derruba o jogo no boot com *"function at line NNN has more than 60 upvalues"* — e derruba TODOS os tools e a suíte junto, porque o erro é de compilação. Use `require("...")` inline dentro da função (é o que o dispatcher inteiro já faz) ou ponha o estado num módulo. Derrubou o boot duas vezes em Set/2026: uma com a janela, outra com a trava de fim de run.
- **`src/ui/BossCinematic.lua` e `src/ui/WorldRoad.lua` vivem no TETO de 200 `local` por função do LuaJIT** (escopo de arquivo conta como uma função). Em Out/2026 a composição tirano + rainha bateu 201 e o jogo parou de COMPILAR (mesmo efeito dos 60 upvalues do main.lua: derruba boot, tools e suíte). Kind/estado novo de chefe entra agrupado numa tabela por chefe (padrão `T3` do tirano), nunca como `local` solto no topo; se passar de ~185, divida o arquivo por chefe.
- **A janela NASCE grande, e isso é decidido no `love.load`, não no `conf.lua`.** O `conf.lua` roda antes do módulo window existir, então não pode perguntar o tamanho do monitor — os 1024x768 de lá são um piso. Quem nunca abriu o jogo entra em fullscreen (`DEFAULT_SETTINGS.fullscreen = true` em `engine/SaveManager.lua`); quem prefere janela ganha 85% do desktop, centralizada, via `Config.Utils.tamanhoJanelaInicial`. **As duas coisas são necessárias**: trocar só o default não alcança quem já tem `fullscreen = false` salvo. Tudo isso é pulado sob `_G.HEADLESS_TOOL`, senão o default vazaria pras capturas e elas deixariam de ser reproduzíveis entre máquinas. Trava: `love . test_one test_window`.
- **Sem travessão em texto do jogo** (pedido do dono, Out/2026: "grita IA"): nada de —, – ou " - " como pontuação nos locales. Reescreva com ponto, vírgula, dois-pontos ou reticências; faixa de número por extenso ("2 a 6"); hífen de palavra composta ("pós-jogo") continua. Trava: `love . test_one test_locale_dashes`.
- **Acento é permitido em TODOS os locales** (a fonte desenha Latin-1 inteiro — `test_locale_glyphs`; fora do Latin-1, como `œ`, NÃO). Para caixa alta use `TextCase.upper` (o `:upper()` do Lua deixa "LéGENDAIRE"); nunca corte texto de UI por byte (UTF-8 inválido derruba a LÖVE). A fonte é a **Grimoire Pixel** (Press Start 2P modificada — OFL com Reserved Font Name, por isso o nome novo): as maiúsculas acentuadas do Latin-1 foram redesenhadas em altura CHEIA com o acento acima da letra (`tools/font_latin_caps.py`; antes "CRÉDITOS" saía "CRéDITOS"). Título em caixa alta leva acento normalmente — nada de "CONFIGURACOES". O acento sobe ~2px de fonte acima do ascender sem mudar a altura de linha: em texto maiúsculo de várias linhas com entrelinha 1.0 ele encosta na linha de cima. Texto de locale é acentuado de verdade nos 5 idiomas; `love . test_one test_locale_accents` falha em ASCII-ismo conhecido ("Forca", "dano" em es, "degats", "fuer"), em glifo encolhido e em glossário de keyword não traduzido (`keyword.<id>.name/text`).
- **DEV × RELEASE**: atalhos e logs de desenvolvedor ficam atrás de `require("src.core.Release").isDev()`. Nunca commitar `build_info.lua`. Saves carregam via `SaveManager.loadDataChunk` (recusa bytecode, sem os/io), nunca `love.filesystem.load`; save novo entra em `Release.MIGRATE_FILES`.
- **TECLADO/GAMEPAD (Out/2026, `src/ui/NavCursor.lua`, ver `memory/nav_cursor.md`):** foco = hover. Algo clicável que NÃO é Button/Card registra `NavCursor.target(chave, x,y,w,h)` no draw (mesmo retângulo do hit-test); ação principal da tela = `NavCursor.action("x"/"y", fn, rect)` (glifo no botão, nunca rodapé); tela com navegação própria declara `ownsNavigation`. Trava: `test_navcursor` + `love . nav_flow` (run inteira sem mouse).
- **ESCALA DE UI (Out/2026, `src/ui/UiScale.lua`, ver `memory/ui_scale.md`):** as telas de UI vivem num espaço VIRTUAL ~1280x720 desenhado com `scale(k)` (k = min(W/1280, H/720) em degraus de 1/4, 1..2.5, × opção "Escala da interface"). Dentro do contexto, dimensões/mouse/scissor são virtuais e a fonte nasce com `dpiscale` (nítida). **Tela nova de UI entra em `UiScale.SCREENS` no mesmo commit** — sem isso ela fica minúscula em 1440p/4K. HUD de batalha e mão ainda 1:1 (adoção pendente). Testes rodam com `UiScale.force(1)` (testkit); o espaço escalado é travado por `test_ui_scale`; capturas: `love . test_one screenshot_uiscale [loc[:tela]]`.
- **Posicionamento responsivo:** sempre `Config.Utils.getResponsiveSize(ratio, maxSize, dimension)` ou `love.graphics.getWidth()/getHeight()` direto — nunca hard-code coordenadas.
- **Fontes:** use `FontManager.getResponsiveFont(ratio, maxSize)` ou `FontManager.getFont(size)` para aproveitar cache. Ao trocar resolução, chame `FontManager.clearCache()`.
- **Cores:** sempre de `Theme.Colors` — evite hex/RGB literais fora de Theme.
- **Áudio:** use `Sfx.play("name")` de `src/systems/Sfx.lua` (wrapper pro `_G.audioSystem`). Os fallbacks legados com `love.audio.newSource` direto foram removidos — não reintroduzir.
- **`print()` é o "logger" do projeto** — há muitos `print` de debug. Não remova em massa sem checar.
- **Efeitos de cartas** são **data-driven** via `effects = {...}` no CardDatabase. Evite `if card.name == "X"` — use o array `effects`.
- **Sequências temporais usam `_G.EventManager`** (ex: `EventManager.after(0.3, function() ... end)`) — evita state machines ad-hoc. Ver `memory/engine_layer.md`.
- **Decisões de RUN usam os streams do `Rng`** (`src/systems/Rng.lua`): `Rng.get():random("card"|"shop"|"map"|"event"|"enemy"|"misc", ...)` — NUNCA `love.math.random` em ofertas/mapa/eventos/economia (quebra a reprodutibilidade por seed e o anti-save-scum). Visual/cosmético (partículas, smoke, jiggle) continua no RNG global. Estado salvo em `run.rngState`; pity de raridade mora em `rng.meta.cardPity`. Ver `memory/rng_and_offers.md`.
- **`DynaText` com `bump`**: SEMPRE declare `bump_phase` (0.42 nas telas de título). O default histórico 200 defasa letras vizinhas em ~-1,06 rad e ESPALHA o texto ("RUND E NAUSW E RTUNG"); fase pequena faz o salto VIAJAR pela palavra. Texto que o jogador LÊ pra decidir (total, número, contador) não leva bump nenhum — informação quer linha de base estável. `love . test_one test_dynatext_bump` trava isso.
- **Juice visual** (kick de scale/rot em objetos) via `Moveable.juice_up(obj, 0.3, 0.1)` ou `obj:juice_up(...)` se já tiver o método. Card já compõe — use nos momentos "algo aconteceu".
- **Card FX** (dissolve/materialize/explode/flip) já disponíveis: `card:start_dissolve(...)`, `card:start_materialize(...)`, `card:explode(...)`, `card:flip(...)`. A coreografia de abertura de pacote mora em `components/PackOpenScreen.lua` (o antigo `CardRevealSequence.lua` nunca foi usado e saiu em Out/2026). Ver `memory/card_fx_pipeline.md`.
- **Shaders**: `shaders/dissolve.glsl`, `flash.glsl`, `booster.glsl`, `holo.glsl` foram **reescritos do zero** (Fase 2 do refactor Balatro, Abril/2026) com matemática própria — value noise hash-based + FBM + multi-banda iridescente. Copyright-safe. Novos: `foil.glsl`, `polychrome.glsl`, `negative.glsl` pra editions (Fase 3).

### Anti-patterns observados (a evitar ao editar)
- **LAYOUT DE TELA = ZONAS, nunca ancoragem vizinho-a-vizinho (Set/2026).** Tela com vários elementos móveis define bandas (contexto / conteúdo / detalhe / ação) e cada elemento pertence a UMA. Quando falta espaço, quem cede é a ESCALA do conteúdo, não a posição das bandas. Origem: na escolha de carta do pacote, a etiqueta de raridade e os botões confirmar/cancelar tinham **literalmente o mesmo Y** (`ry + imgH + 8`) — dois elementos ancorados na carta sem saber um do outro. Referência: `src/ui/PackChoiceLayout.lua` (expõe `validate()`, rodado por estado nos tools). Banda vazia que só preenche no hover também é bug: informação de hover mora ANCORADA no objeto, não numa tarja fixa.
- **`resize()` tem que cobrir o estado NOVO, não só o original.** `memory/resize_pattern.md` já exigia `resize()` em toda overlay — e foi violado assim mesmo, porque o checklist cobre "tela nova" e o defeito veio de "estado novo em tela existente". Adicionou rect/escala/fonte derivada/canvas/botão? Estenda o `resize()` **no mesmo commit**. E note: **NASCER grande ≠ CRESCER** — capturar a tela já criada em 1920×1080 não exercita o bug. Teste manual obrigatório: abrir em janela pequena, entrar na tela, apertar `f` COM ELA ABERTA, voltar, e arrastar a borda. (O modo `resizeflow` de `tools/screenshot_packopen.lua` trava: `love.window.setMode` repetido dentro de tool não retorna, e pedir janela maior que o desktop trava na 1ª chamada.)
- **Fallback silencioso é PROIBIDO.** Três defeitos da mesma sessão tiveram essa causa: `Easing.apply` caía em `smooth` sem avisar (`"easeOut"` camelCase não resolve — 6 animações do PackOpenScreen rodaram erradas por rodadas de polish); `BoosterShader.load()` com `pcall` degradava pra "sem efeito" e um shader quebrado passou despercebido enquanto se media arte crua; `reducedMotion` zerava o juice e custou uma sessão de debug. Lookup que falha ou recurso que não carrega **AVISA** (um `print` por chave desconhecida basta). Corolário: `reducedMotion` remove MOVIMENTO, nunca INFORMAÇÃO.
- **Antes de somar efeito sobre um asset, ABRA O PNG.** Os pacotes acumularam halo com a própria silhueta (lia como cópia fantasma), cantoneiras de código por cima das chapas metálicas **já pintadas na arte**, e um foil que lavava a cor dando a MESMA listra nos 5 tipos — uniformizando a identidade que se queria criar. A correção foi remover, não somar. Teste objetivo de "está lavando?": renderize 1:1 e compare pixel a pixel com o arquivo — em repouso o desvio deve ser ~0.
- **Performance do WorldRoad (Out/2026):** chão, estrada e grama passam por `engine/QuadMesh.lua`; o vento da grama roda no vertex shader e o frame é reaproveitado com a câmera parada. Nunca ponha closure ou `love.graphics.*` dentro de laço quente da cena. Asset novo por bioma entra em `prewarmJobs` do `WorldRoad.lua`. Travas: `love . test_one test_perf_budget`; medir: `perf_probe 1920x1080:phases`; prova visual: `perf_visual_diff ref|cmp`.
- **REGRA DE PROFUNDIDADE do WorldRoad (lei do projeto, pedido explícito Jul/2026):** TODO elemento novo da cena entra no painter **intercalado por profundidade (`rel`)** — nunca em "camada global por tipo". O padrão é o do v7.5: `drawProps` descarrega fatias de grama entre as árvores (`flushGrassTo` → janelas `relFrom`/`relTo` do GrassField); um elemento na frente do pé de uma árvore desenha DEPOIS dela; atrás, ANTES. Vale pra pedra, animal, efeito, personagem — e também na LUZ (`LightEngine.submitOccluder` com `z`). Elemento desenhado em camada plana por cima do campo é bug, não estilo.
- **Sem faixa de dica no rodapé (Out/2026, pedido do dono: "poluindo").** `HintBar.ENABLED = false` desliga todas; informação que o jogador precisa pra decidir mora ANCORADA no objeto, nunca numa tarja de rodapé. Não reintroduzir rodapé de instruções em tela nova.
- **Salão de chefe sem disco de luz (Out/2026, dono: "remove todas essas bolas de luz").** Atmosfera dos `castle_hall_*` mora em `src/ui/InteriorFX.lua`: a luz é a CHAMA PINTADA redesenhada em aditivo (máscara emissiva), tudo em coordenadas da ARTE pelo cover-fit (fração de tela calibrada em 4:3 desalinha em 16:9), salão escolhido por `InteriorFX.hallFor` (fonte única de draw e update), clima atrás do chefe em `draw` e na frente em `drawFront`. Arte nova precisa do chão começando em ≤0.71 da PNG. Trava: `test_interior_fx`. Ver [`memory/boss_halls.md`](memory/boss_halls.md).
- **Palco do inimigo pela zona da mão (Out/2026).** O inimigo para onde o pé fica acima do topo da carta levantada (`WorldRoad.battleRelFor`, recalculado por frame); o tooltip da carta no combate abre AO LADO. Pé de inimigo APOIADO afunda 2-3px no chão (`FOOT_SINK`, margem medida POR QUADRO); flutuantes seguem no ar. Trava: `test_enemy_stage`. Ver memory/enemy_pose_and_scene_anchor.md §5.
- **Quem some do chão some da grama na mesma curva.** Elemento de chão que faz fade (braço do fork, etc.) tem que encolher a clareira que abre na grama com o MESMO alpha (`roadCenters` → `ws[i] = forkAlpha`) — senão sobra chão liso sem estrada e sem grama.
- **Classe = OBJETO, nunca personagem (Out/2026).** Os heróis chibi foram removidos a pedido do dono ("abre margem para críticas"). A seleção usa emblemas (`assets/sprites/emblems/`, `src/ui/ClassEmblem.lua`). Classe bloqueada vem de `UnlockSystem.isClassUnlocked/getClassUnlockInfo/getClassMastery` e nunca inicia run.
- **Oferta de carta passa por `CardRegistry:_poolFor` ou `BoosterPackSystem`** — os dois filtram `UnlockSystem.isCardUnlocked`. Pool nova de oferta fora deles vaza carta bloqueada (`test_unlocks`, 60 seeds). Abandonar pelo pause é fim de run (`Game:abandonRun`: XP de maestria + derrota, uma vez).
- **Tela nova que não é overlay e precisa sumir ao voltar ao menu**: registre-a no `InputFocus` — o `returnToMenu` usa `InputFocus.hideAll()`. Com modal aberto durante a luta o combate CONGELA (`InputFocus.freezesCombat`).
- **Animação de carta monta progressiva**: `IconFramesLoader.has()` NÃO carrega o set; `CardFrame.liveImage` monta 1 frame por frame (LRU 24). Régua: `love . test_one perf_collection`.
- `src/ui/HudPanel.lua` e `src/ui/VisualEffects.lua` foram removidos no refactor de Abril/2026 (eram legado). Não recriar.
- **A FORJA É POR CÓPIA, NÃO POR ID (Set/2026).** O nível vive em `currentRun.currentDeck[i].up` e a identidade da cópia é o ÍNDICE no deck. Use `upgradeCardAt/canUpgradeAt/removeCardAt/duplicateCardAt/getEntryLevel` do RunManager — nunca indexe forja por `cardId`. Antes o nível morava num mapa por id e `buildPlayableDeck` o aplicava a TODAS as cópias: com três "Golpe", forjar uma forjava as três, e a tela de forja escondia as cópias porque mostrá-las seria mentira de UI. Ver [`memory/rng_and_offers.md`](memory/rng_and_offers.md).
- **Cartas não devem ter `effects = {}` sem tags significativas.** Starter/básicas OK. Rode `love . validate_cards` antes de commitar.
- **O campo `image` da carta é DADO MORTO — não renderiza nada.** 125 das 128 cartas apontam pro mesmo punhado de PNGs (`theRock.png` sozinho serve 49 cartas) e isso NUNCA aparece na tela: a arte real vem do atlas `src/data/card_art.lua` via `CardArt.resolve`, e o `image` só existe como rede do `pcall(CardFrame.render)` em `src/systems/CardDatabase.lua:185` — se o render falhar, sobra algum PNG em vez de nada. Ou seja: o campo é rede de segurança com **nome que engana**, e já custou uma investigação nesta sessão (a queixa "Adrenalina e Poção de Cura têm a mesma foto" parecia ser dele e não era). Ao debugar arte de carta, olhe o ATLAS, não o `image`. Renomear pra `fallbackImage` com um arquivo único é melhoria recomendada e ainda não feita — o mecanismo NÃO deve ser removido.
- **Nunca condicione por `card.name`** — use `card.effects` + `card.tags` (data-driven).
- **Jokers nunca passam por `addCardToRun`/`currentDeck` direto** — sempre via `Game:addJokerToRun` (ou via `addCardToRun` que bifurca). Joker é separado de hand/deck (padrão Balatro G.jokers); persistido em `runManager.currentRun.jokers`. Romper esse invariante reabre o bug "mesmo joker pode ser jogado várias vezes".
- **Coringas = COLEÇÃO + BANCADA (Jul/2026, ver [`memory/jokers_and_hand_layout.md`](memory/jokers_and_hand_layout.md))**: a run POSSUI jokers ilimitados (`currentRun.jokers`); só até `getMaxJokerSlots()` ficam ATIVOS (`currentRun.jokerActive[]`), o resto na bancada. `jokerSlots` = SÓ os ativos, reconstruído por `Game:rebuildJokerSlots()` (fonte única). Comprar NUNCA perde o joker (bancada se cheio). Troca de ativos: `Game:setJokerActive(i, bool)` + Gerenciador de Coringas. NÃO reintroduzir rejeição por slots cheios em `addJokerToRun`/`canAcceptJoker`.
- **Strength/Dexterity são adicionados em Game:processCardInCombat via `statBonus`** — não duplicar no `EffectSystem:applyCardEffects`. O effect `strength_scaling`/`dexterity_scaling` faz o stat contar em **DOBRO** nessa carta (auditoria Jul/2026: era flag-only e a desc "Escala com Força" era promessa vazia) — o ×2 mora SÓ no `scaledStat` de `processCardInCombat`.
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

- `python tools/build_release.py` — build de RELEASE: só arquivos do git, comentários removidos SÓ na cópia (prova por bytecode idêntico), `test_all` na cópia limpa, `Grimoire.exe` + pasta de depot Steam (`build/steam/`) e smoke do executável (`GRIMOIRE_SELFTEST`). Templates VDF em `steam/`. Ver `memory/release_pipeline.md`.
- **Balanceamento em minutos** (Out/2026, `memory/balance_pipeline.md`): `python tools/balance.py --runs 60 --classes all --pilots naive,average,expert_fast` roda a bateria em TODOS os cores no relógio INSTANTÂNEO (`tools/instant_engine.lua`: mesma regra, fila drenada por saltos — paridade com o relógio de quadros travada em `test_instant_parity`) e escreve `reports/balance/<label>/report.md` (winrate com IC, mortes por ato/inimigo, turnos e vida por luta, dano por fonte, deck ao longo da run, poder de carta/coringa, forja, compras, minutos estimados). Pilotos = perfis em `tools/autoplay.lua` (`M.PILOTS`: naive/average/expert_fast/expert). `python tools/balance_tune.py` varre knobs (`--enemy-power`, `--boss-hp`, `--combo`) contra as bandas de `memory/sts_difficulty_targets.md`. `love . balance_sim N classe seed piloto` continua valendo (um processo).
- `CARDGAME_HEADLESS=1 love . test_all` roda a suíte **sem janela visível** (janela 1024×768 escondida fora do monitor — a 1×1 do `conf.lua` sozinha quebrava dez suites que desenham no backbuffer real). O runner restaura monkeypatch vazado entre suites (`CardFrame.render`, relógio, janela falsa, mouse, `print`) e imprime `[leak] <suite>: <função>` — a suite que vazou continua dona do defeito (Out/2026: o stub do `balance_sim.setup` derrubava `test_class_select` uma rodada em nove).
- `CARDGAME_IDENTITY=<nome>` isola o save dir (rodar suites em paralelo, worktrees). Qualquer arg de tool liga `UnlockSystem.setOverrideAll(true)` (catálogo inteiro pro autoplay/balanceamento); testes do comportamento real desligam e usam `ProfileStats._swapForTests`. Tool/teste que quebra em DEV imprime o trace e sai com 1 (não pendura na tela azul).

**Infra compartilhada:** [`tools/testkit.lua`](tools/testkit.lua) — helpers de asserção (`t:eq/near/truthy/throws/...`) + fábricas: `TK.newRunGame(class)` (Game de run pronto), `TK.pump(game, secs)` (avança EventManager/animações — combate é diferido pro apex), `TK.mockGame()` (game leve pra EffectSystem isolado), `TK.seedRng(seed)` (Rng determinístico). Novos testes DEVEM usar o testkit e ser registrados em [`tools/run_all_tests.lua`](tools/run_all_tests.lua).

**Cobertura por domínio (novos, Jul/2026):** `test_entities` (Player/Enemy: dano/armadura/mana/buffs/orbs/status/fúria/intent), `test_economy` (ouro/juros), `test_progression` (RunManager/MapManager/ActSystem: atos/andares/endless), `test_forge` (upgrade/custo forja), `test_cards` (catálogo inteiro instancia + rollRarity + pools), `test_effects_full` (todo tipo de efeito + orbs + triggers), `test_combat` (seleção/mana/pipeline de dano/vitória/derrota/jokers), `test_events` (roll/no-repeat + toda opção aplica sem crash), `test_journal` (roteiro da run: ciclo begin/note/end, sinks, backfill do mapHistory, endless, save/load) `test_journal_resize` (auditoria geométrica do Roteiro em 7 tamanhos, janela falsificada) e `test_upgrade_tile` (relíquia da loja: bandas do tile em 5 tamanhos, resize da vitrine com janela falsificada e as 4 camadas de texto nos 5 locales). Somados aos smoke pré-existentes + `validate_cards` + `test_i18n` = **43 suites** (Set/2026: +`test_journal`/`test_journal_resize`, `test_no_hardcoded_pt` (trava anti-PT cravado), `test_dynatext_bump` (trava do bump: título ondula, não espalha) e `test_achievements_i18n` (as 20 conquistas traduzidas de verdade nos 5 idiomas); Jul/2026: +`smoke_packs` e regressões P0.9/P2.3 do rebalance v2 — ver `tools/run_all_tests.lua`, fonte da verdade da contagem).

Nota de comportamento fixada pelos testes: `poison` decrementa **`duration`** por turno e os `stacks` persistem (dano = stacks a cada turno, por duration turnos). O texto i18n foi corrigido (Jul/2026) para refletir isso — antes dizia erroneamente "perde 1 stack por turno". `vulnerable` só existe no Enemy (Player não tem esse caminho).

---

## 12. Status e lacunas conhecidas (pós-redesign)

- ✅ Efeitos `channel_orb`/`evoke_orb`/`strength_scaling`/`exhaust`/`innate`/`mystery` **implementados** (Fase 2).
- ✅ Sistema de **tags** + **combos** ativos (Fases 1 e 3).
- ✅ **MapManager** com node choices (Fase 4), **ActSystem** com **6 atos** + endless (Fase 5; foram 3 atos até Set/2026 — os biomas, chefes e poses dos atos 4-6 ja existiam e so apareciam no endless). `Config.TotalActs` e a fonte unica: `checkVictory` e `advanceFloorInAct` leem dela, e NENHUM chamador de producao passa o total como argumento (passar `3` cravado deixou o jogo impossivel de vencer por uma leva — ver defect_doctrine 14).
- ✅ **RestScreen** + **EventScreen** (Fase 6). Shop reusa CardRewardScreen.
- ✅ Starter deck de **2 cartas** (Fase 5). Rebalance nas 96 cartas (Fase 7).
- ✅ **STS-improvements v1** (Jul/2026, `docs/plan/sts-improvements-v1.md`): RNG seedável com 6 streams + estado no save; **pity de raridade** + **afinidade por tags do deck** nas ofertas (rewards+loja, com badges e "?" explicativo); **forja infinita** (cap 0) com preview/tooltip/custo crescente na loja; TopBar com ato/andar + tooltips em tudo + ouro direcional; rewards com raridade nomeada e skip claro; eventos com custos explícitos `[+/-]`, 4 eventos de deck e no-repeat por ato; picker de carta genérico (`_G.openCardPicker`). Teste: `love . test_systems`. Ver `memory/rng_and_offers.md`.
- ✅ **Rebalance v2 + re-baseline** (Jul/2026, commit `6e7118c` + follow-ups): 46 mudanças de carta + 13 cartas novas por arquétipo; BoosterPackSystem 100% no stream `shop` do Rng seedado (era `love.math.random`); Piloto v5 (lethal fiel ao pipeline, cérebro de orbes, tripwires no diário) + v5.17 (prior de DEFESA pra mago/ladino — bot sem defesa não mede o jogo, mede o próprio viés); **Mago: Conduíte = orbe de Raio (4) + 2 de Foco** (bateria: mago 0/15 → 3/10). Re-baseline 10×3: guerreiro 50% · mago 30% · ladino 10% de winrate do bot, todas as classes chegando ao A3. Próximos levers monitorados: conversão do ladino no boss final, guerreiro >60%.

- ✅ **Pacote de lançamento** (Out/2026): desbloqueio de cartas/classes + maestria (`memory/unlocks.md`), Coleção com descobertas e sem lag, conquistas repaginadas + Steam (`memory/steam_achievements.md`), emblemas de classe, pause/configurações redesenhados (`memory/pause_settings_menu.md`), save por estágio, build de release (`memory/release_pipeline.md`).

- ✅ **Balanceamento por bateria do piloto v6** (Out/2026, `love . balance_sim 30 <classe> <seed>` — rode em blocos/processos separados por classe): guerreiro 47% · ladino 43% · mago ~28% de vitória. Passivas do mago (Foco inicial 2/3/4 na época; hoje 0/1/2) e do ladino (Veneno 1/2/3) CRESCEM +1 a cada dois atos (`Game:classPassiveTier`) — fixas, as duas classes quebravam nos atos 4-6. Mago ainda abaixo da meta 40-60%: três variantes da passiva deram 20-30% (ruído ±8pp com 30 runs) — próxima suspeita é o piloto jogar orbes pior que ataques, não a classe.

- ✅ **Stage 2 — bandas do StS pelo pipeline instantâneo** (Out/2026, `python tools/balance.py` / `balance_tune.py`, `memory/balance_curves.md`): `ENEMY_POWER` 0,8/0,85 → **0,75/0,8 + ato 3 ×0,9** (`ENEMY_POWER_BY_ACT`). Resultado (30 runs/classe, seeds 720001–030): **expert_full 57% · 53% · 53%** (G/M/L, IC ±17pp; alvo 45–60), mortes no A5 (Colosso), lutas A5–A6 7,4–9,0 turnos (chefe A6 11); **naive 0%** (morre A2–A3, alvo <5 ✓); **average 0–10%** e **expert_fast 0–13%** — ABAIXO das bandas (12–25 / 30–50) e isso NÃO se resolve no inimigo: de 0,8 a 0,55 o average só troca a morte de A2 por A3/A5, e mão 6 / mana 4 movem +0–7pp. Diagnóstico por turno (`battleLog.diag`): o average lê o intent (cobre 59% dos golpes) e gasta a mana; perde porque não se SUSTENTA — 18,8 de vida por luta no A3 contra 6,9 do expert_full com a mesma cobertura, e o expert_full escolhe cura, básicas baratas, forja 3× mais e segura carta. Sinal de design (lead): o jogo pune deck montado por valor-de-face mais que o StS — quem pega carta pelo valor de face perde 100%, no StS ainda vence 10–25%. Das propostas medidas (`memory/balance_curves.md`, tabela de 13/Out), **só o sustento garantido foi adotado** (`Config.Offers.SUSTAIN_GUARANTEE=true` + peso ×2 com < 2 fontes de cura no deck: a 1ª vaga da recompensa de elite/chefe vira cura/lifesteal/regen — mexe na OFERTA, nenhuma carta mudou): foi o único lever que moveu o piloto mediano (+10 a +17pp). Descanso 40%, poção de elite e elite em rampa ficam atrás de flags com default = jogo atual (`BALANCE_REST_HEAL/POTIONS/ELITE_RAMP`, `test_sustain_knobs`). Sustento + névoa medidos juntos no HEAD (13/Out): expert_full 60/80/83, mediano 13/7/13, expert_fast 20/17/13; endurecer os atos 5-6 (A5 ×1,1 / A6 ×1,15) derrubou o mediano pra 3% e o guerreiro expert pra 43% sem tirar mago/ladino de cima da banda, então foi DESCARTADO: a base (Selo 0) serve o mediano e o expert sobe pelos Selos 1-10 (tabela em `memory/balance_curves.md`). Candidato `wip/combo-nerf` medido idêntico nos pilotos rápidos e descartado. Knobs novos: `BALANCE_ENEMY_POWER_ACT`, `BALANCE_BOSS_HP_ID`, `BALANCE_COMBO=step:cap`, `BALANCE_COMBO_JOKER`, `BALANCE_MAGE_FOCUS/ROGUE_POISON` (`Game.MAGE_FOCUS_OFFSET/ROGUE_POISON_OFFSET`), `BALANCE_HAND/MANA`.
- ✅ **Passivas que CRESCEM NA LUTA** (Out/2026, depois do roster novo + Combo v3: guerreiro 43% · mago 13% · ladino 17%): as três passivas têm a forma do Ímpeto — regra de TURNO que soma na batalha. Conduíte: 2+ cartas de orbe no turno → +1 Foco. Toxinas: 2+ ataques no turno → o Veneno da passiva sobe `Game.TOXIN_GROWTH` (2). Dano de orbe (pulso/evoke de raio/fogo/sombra) passa pelo MAIOR `damage_multiplier` de coringa (`EffectSystem.orbDamageMult`, fonte única com OrbRow/DamagePreview/piloto). Ladino: Punhalada 11→8, Adrenalina custo 0→1, `poison_stack` +2→+4. Ímpeto pede 3 ataques (`Game.IMPETUS_ATTACKS`; com 2 o guerreiro foi a 67%). Foco soma inteiro no pulso de orbe. Bateria final 30/classe: guerreiro 47% · mago 43% · ladino 50%; mago ainda luta ~14 turnos no A5-A6 por política do piloto (passa turno com mana e ataque na mão). Depois do f67ebe4 (a passiva do mago só valia na 1ª luta da run) o mago foi a 63%: Foco INICIAL do Conduíte passou de 2/3/4 para 0/1/2 por ato → mago 53% (guerreiro 50%, ladino 55% em 20 runs no mesmo HEAD). Números em `memory/balance_curves.md`. **Revisto com os combos simples (Out/2026):** com `ENEMY_POWER` o mago foi a 73-90% e o crescimento do Conduíte, o orbe pelo multiplicador de coringa e o Foco inteiro no pulso SAÍRAM (mago 47%); Ímpeto e Toxinas continuam crescendo.

Pendente:
- **Licenças antes de vender**: SFX/música gerados no plano FREE do ElevenLabs (não permite uso comercial) — assinar e regenerar; confirmar assinatura PixelLab no período da arte; declarar conteúdo gerado por IA na Steam; documentar origem de `music.mp3`, `hoverCard.wav` e PNGs antigos. Token PixelLab vencido segue no histórico git (`3fc14ea`) — reescrever histórico se o repo for público.
- 12 cartas ainda com `effects = {}` (intencionalmente — são âncoras de tag starter/básicas).
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
- [`memory/combo_rules.md`](memory/combo_rules.md) — combos simples (Saraivada/Muralha/Par), coringas de combo e o `ENEMY_POWER` que caiu junto.
- [`memory/damage_preview.md`](memory/damage_preview.md) — prévia de dano: `DamagePreview.cardValue` fonte única, `simulate` da leva, painel no JOGAR, trava `test_damage_preview`.
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
- [`memory/combat_beats.md`](memory/combat_beats.md) — fila de beats, tabela de tempos, cadeia do turno do inimigo, espinhos como estado.
- [`memory/enemy_pose_and_scene_anchor.md`](memory/enemy_pose_and_scene_anchor.md) — pose do inimigo (apoiado × flutuante, `src/data/enemy_poses.lua`) e linha de chão por cena (`src/data/scene_anchors.lua`); elite luta na ESTRADA, interior é só do boss.
- [`memory/boss_visuals.md`](memory/boss_visuals.md) — chefes: idle assado em loop de 12 quadros a partir do quadro 0 (`tools/bake_boss_idle.py`, nunca regerar idle no PixelLab — deriva), aura assinatura + contorno (`src/data/boss_auras.lua` → `src/ui/BossAura.lua`, só com `enemy.isBoss`), `axisX` quando cajado/capa desequilibram o bbox. Trava `test_boss_visuals`.

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
Card:draw()                          -- HoloShader em rare/legendary (load() no boot do main.lua — ficou 6 meses sem ser chamado; trava: test_holo_shader)
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
- `rare`: + borda interna `BLOOD` + halo rarity seal + HoloShader v2 (kind 0): glint prata-azulado SÓ no aro, 0 em repouso → ~0.25 no hover
- `legendary`: + borda interna dourada + cantos `AGED_GOLD` com highlight + halo dourado + HoloShader v2 (kind 1): aro ouro + faixa prismática em degraus, 0.08 em repouso → ~0.5 no hover. **Regra (Out/2026):** o holo é REFLEXO aditivo no aro/realces — a ilustração em repouso é pixel-idêntica à crua (`test_holo_shader` trava); a v1 (arco-íris sobre a carta inteira, sempre animado) lavava a arte e foi descartada.

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
