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
├── components/                 # UI de alto nível (telas, widgets)
│   ├── Menu.lua                # Menu principal
│   ├── ClassSelectionScreen.lua# Seleção de classe (warrior/mage/rogue)
│   ├── GameUI.lua              # HUD do gameplay (só delega ao HudManager)
│   ├── CardRewardScreen.lua    # Loja / recompensas pós-batalha (inclui refresh)
│   ├── TopBar.lua              # Barra superior (ouro, deck, ícone config)
│   ├── SettingsMenu.lua        # Overlay modal: volume (music/sfx/master) + fullscreen
│   ├── JokerSlot.lua           # Slot visual de joker ativo
│   └── Button.lua              # Widget de botão (usa FontManager)
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
│   │   ├── CombatAnimationSystem.lua # Cartas voam ao centro (Balatro-style)
│   │   ├── EconomySystem.lua   # Ouro, juros tipo TFT
│   │   ├── ShopSystem.lua      # Ofertas da loja (cartas + upgrades + refresh)
│   │   ├── AudioSystem.lua     # Áudio robusto (detecta WSL2, fallbacks)
│   │   ├── MessageSystem.lua   # Toasts in-game com fade
│   │   ├── ParticleSystem.lua  # Partículas genéricas
│   │   ├── SmokeSystem.lua     # Smoke atmosférico (4 presets)
│   │   └── Timer.lua           # Timer simples
│   ├── ui/
│   │   ├── Theme.lua           # Paleta de cores + utilitários (gradient, interpolate)
│   │   ├── FontManager.lua     # Cache de fontes + fontes responsivas
│   │   ├── ImageCache.lua      # Cache global de imagens (evita carregar PNGs múltiplas vezes)
│   │   ├── HudManager.lua      # Orquestra HudPlayerPanel + HudEnemyPanel
│   │   ├── HudPanel.lua        # Base para painéis de HUD
│   │   ├── HudPlayerPanel.lua  # Painel inferior esquerdo (HP/Armor/Mana)
│   │   ├── HudEnemyPanel.lua   # Painel inferior direito (HP/Damage/Phase)
│   │   ├── CardInfoDisplay.lua # Tooltip de carta no hover
│   │   ├── VisualEffects.lua   # Glass rectangles, glow, partículas
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

## 3. State machine (main.lua)

`currentState` transita entre:

```
menu → classSelection → playing ⇄ cardReward
                          ↓
                    gameOver | victory → menu
```

- **menu**: `Menu:draw()` — botões Jogar / Configurações / Sobre / Sair (últimos dois só imprimem "em desenvolvimento").
- **classSelection**: `ClassSelectionScreen` — escolhe `warrior`, `mage`, ou `rogue` → `startGame(classId)`.
- **playing**: `drawGame()` + `updateGame(dt)`. Desenha background, top bar, HUD, cartas na mão (3D hover), smoke, jokers ativos como cartas no topo (Balatro style), sistema de mensagens, animação de combate por cima de tudo.
- **cardReward**: após `game:isPhaseCleared()` em run mode, `CardRewardScreen` mostra ofertas (ShopSystem). Desenha o jogo por trás como overlay.
- **gameOver / victory**: telas estáticas com score.

### Inputs (gameplay)
- Mouse: hover/select cartas, clica "Jogar Cartas", clica config na TopBar.
- `space`: compra carta do deck (+ som hoverCard).
- `r`: reinicia via `game:startGame()`.
- `f`: toggle fullscreen + `FontManager.clearCache()`.
- `1/2/3/4`: presets de smoke (subtle/default/atmospheric/intense). `0`: limpa smoke.
- `esc`: volta ao menu.

---

## 4. Loop de gameplay (Game.lua)

1. `Game:startGame()` reseta player/enemy/economia, chama `initializeDeck()` (usa RunManager se `isRunMode`, senão DeckManager com `"starter"`), embaralha, compra `Config.Game.INITIAL_HAND_SIZE` (3) cartas.
2. Jogador hover/seleciona cartas — `Game:selectCard(card)` debita mana via `player:spendMana(cost)`. Desselecionar devolve mana.
3. `Game:playSelectedCards()` → remove cartas da mão **imediatamente** → `combatAnimationSystem:startCombat(...)` com callbacks:
   - `onCardProcessed(card)` → `Game:processCardInCombat(card)` aplica dano/defesa/efeito/joker. Efeitos de joker passam por `EffectSystem:applyJokerEffects(game, card, baseValue)`.
   - `onComplete()` → limpa seleção, `turn = "enemy"`.
4. Enquanto `combatAnimationSystem:isBlocking()`, `updateGame` não dispara enemy turn, game over, victory nem próxima fase.
5. `Game:enemyTurn()` — `enemy:performAttack()`, `player:takeDamage(dmg)`, `player:restoreMana()`, `drawCard()`, volta `turn = "player"`.
6. Se `game:isPhaseCleared()` (enemy.health ≤ 0):
   - Run mode: `showCardRewards()` → CardRewardScreen.
   - Classic: `game:nextPhase()` direto.
7. `nextPhase()` incrementa fase, ganha ouro via `economySystem:earnBattleGold()`, reseta max mana, reembaralha deck, cura a cada `HEALTH_RESTORE_INTERVAL` (3) fases, cria enemy escalado.
8. Vitória: `currentPhase > VICTORY_PHASES` (10). Game over: `player:isAlive() == false`.

---

## 5. Dois modos de deck

Convivem no mesmo `Game`:

| | **Classic (legacy)** | **Run mode (Slay the Spire)** |
|---|---|---|
| Trigger | Default quando não há `startNewRun` | `game:startNewRun("warrior")` — vindo da ClassSelectionScreen |
| Deck source | `DeckManager` → `CardDatabase:buildDeckCards("starter")` | `RunManager.currentDeck` (lista de IDs) |
| Deck cresce? | Não | Sim, via `game:addCardToRun(cardId)` após recompensa |
| Classes | Ignoradas | Warrior / Mage / Rogue têm pools por raridade (CardRegistry) |
| Recompensas | Vai direto pra próxima fase | Tela CardRewardScreen (ShopSystem gera ofertas) |
| Fim | `endCurrentRun(victory)` ou nunca | Stats completas salvas via `RunManager:endRun` |

Flag: `game.isRunMode` + `runManager:hasActiveRun()`.

---

## 6. Tipos de carta

Todas herdam de `src/cards/base/Card.lua` (render 3D Balatro-style, hover, shadows, tooltip):

- **`attack`** — `AttackCard`: `card.attack` dano ao inimigo; efeitos de joker são multiplicadores/bônus via `EffectSystem`.
- **`defense`** — `DefenseCard`: `card.defense` vira armor do player (limitado a `maxArmor=50`).
- **`joker`** — `JokerCard`: ao jogar vai pro `game.jokerSlots` (máx 3) e executa `card.passive(game)`. Permanece ativo pelo resto da run aplicando efeitos continuamente.
- **`effect`** — `EffectCard`: executa `card.passive(game)` (via `EffectSystem:processEffectCard`) e é descartada. Tipos: `instant_heal`, `restore_mana`, `increase_max_mana`, `add_armor`, `magic_damage`, `draw_cards`.

Jokers/efeitos com dados **data-driven** (array `effects = { {type, target, value}, ... }`). Tipos conhecidos em EffectSystem:
- Continuous (joker): `damage_multiplier`, `defense_multiplier`, `damage_bonus`, `defense_bonus`
- Trigger: `on_attack_heal`, `on_defend_damage`, `regen_per_turn`, `damage_per_turn`

Ver `src/systems/CardDatabase.lua` para ~80+ cartas hard-coded. **Não há JSON externo ainda** apesar do comentário "sistema de banco de dados baseado em JSON" — é tudo Lua puro no `loadData()`.

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

### AudioSystem (`src/systems/AudioSystem.lua`)
Exposto como `_G.audioSystem` em `main.lua`. Detecta WSL2 via `/proc/version`, tenta inicializar áudio com `pcall`, mantém um cache `audioCache[name]`. Sons carregados: `hoverCard`, `cardSelect`, `deckStart`, `swordSound`, `armorSound` + música de fundo streaming. **Sempre passe por `_G.audioSystem:playSound(name)` — o sistema já faz fallback gracioso.**

### CombatAnimationSystem (`src/systems/CombatAnimationSystem.lua`)
Máquina de estados: `idle → cards_flying → processing → damage_dealing → complete`. Bloqueia a lógica do jogo via `isBlocking()`. Usa easing out-quart, escalas aumentadas (1.3x) no centro, números de dano flutuantes. Timings em `self.timings`.

### EconomySystem + ShopSystem
`economySystem.currentGold` inicia em 10 na run. `earnBattleGold(phase, healthLost, consecutiveWins)` gera ouro + juros estilo TFT (10% do cofre, máx 50). Shop gera ofertas (70% cartas, 30% upgrades) com raridade 70%/25%/5% (common/uncommon/rare). `rollRarity` da shop é diferente do `CardRegistry:rollRarity()` (37/37/25/1 legendary).

### HUD
`HudManager` orquestra `HudPlayerPanel` (canto inferior esquerdo, verde) e `HudEnemyPanel` (canto inferior direito, vermelho). `GameUI.lua` só delega pro `HudManager` — suas funções antigas `drawPlayerInfo/drawEnemyInfo` foram removidas. Salva/restaura estado de gráficos explicitamente após draw.

### Smoke
`SmokeSystem` spawna partículas que sobem lentamente. 4 presets em `SmokeConfig`. Pode ser alterado em runtime via teclas 1-4.

---

## 9. Convenções do projeto

- **OOP via metatables:** `setmetatable({}, Klass)` onde `Klass.__index = Klass`. Construtor `Klass:new()`.
- **Strings de UI:** português. Mensagens de `print()` de debug também.
- **Posicionamento responsivo:** sempre `Config.Utils.getResponsiveSize(ratio, maxSize, dimension)` ou `love.graphics.getWidth()/getHeight()` direto — nunca hard-code coordenadas.
- **Fontes:** use `FontManager.getResponsiveFont(ratio, maxSize)` ou `FontManager.getFont(size)` para aproveitar cache. Ao trocar resolução, chame `FontManager.clearCache()`.
- **Cores:** sempre de `Theme.Colors` — evite hex/RGB literais fora de Theme.
- **Áudio:** sempre pelo `_G.audioSystem`. O fallback direto via `love.audio.newSource` cacheado ainda existe em alguns arquivos (`Game.lua`, `Card.lua`, `JokerCard.lua`) como legado — não adicione novos.
- **`print()` é o "logger" do projeto** — há muitos `print` de debug. Não remova em massa sem checar.
- **Efeitos de cartas** são **data-driven** via `effects = {...}` no CardDatabase. Evite `if card.name == "X"` — use o array `effects`.

### Anti-patterns observados (a evitar ao editar)
- `src/MessageSystem.lua` é duplicata antiga de `src/systems/MessageSystem.lua`. O código novo usa o de `systems/`. Não duplique.
- `ClassSystem.lua` está marcado DEPRECATED — apenas delega pro `CardRegistry`. Prefira `CardRegistry` para novas features.
- `EffectSystem:getCardData` tem mocks hard-coded por `card.name == "God of the Abyss"` — isso é legado; o fluxo preferido é via `joker.effects` já no CardDatabase. Ao tocar aqui, leia o bloco todo.
- Cartas procuram imagens em `assets/cards/attack/theRock.png` como fallback quando a imagem falha — muitas cartas do CardDatabase reusam `theRock.png` mesmo sem ser "rock" (por falta de artes).

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

## 12. Status e lacunas conhecidas

- Menu "Sobre" ainda é placeholder (o de Configurações já foi implementado via `SettingsMenu`).
- Muitas cartas do Slay the Spire estão **declaradas mas com `effects = {}`** — não fazem nada além do dano base.
- Tipos de efeito `channel_orb`, `evoke_orb`, `strength_scaling`, `exhaust`, `innate` são declarados em cartas mas ainda não processados (loga descrição).
- Save/load persistente funcional no `RunManager`, mas ainda não há botão "Continuar" no menu principal que chame `loadRun()`.
- `CardRewardScreen` ainda tem `print()` de debug (não limpos ainda).

Para detalhes mais longos sobre cada lacuna, veja [`memory/known_gaps.md`](memory/known_gaps.md).

---

## 13. Memory — contexto detalhado por tópico

O diretório `memory/` na raiz do projeto guarda notas persistentes que complementam este arquivo. Use-as quando precisar de profundidade além do resumo acima. Cada arquivo tem frontmatter (`name`, `description`, `type`).

- [`memory/MEMORY.md`](memory/MEMORY.md) — índice de uma linha por arquivo.
- [`memory/project_overview.md`](memory/project_overview.md) — identidade, stack, inspirações e idioma.
- [`memory/architecture.md`](memory/architecture.md) — mapa detalhado das camadas (core/systems/ui/components/pixel art).
- [`memory/pixel_art_system.md`](memory/pixel_art_system.md) — pipeline procedural Balatro-style (Palette → CardFrame → CRTShader).
- [`memory/ui_pixel_system.md`](memory/ui_pixel_system.md) — chrome de UI pixel: Button reescrito em PixelCanvas, fonte Press Start 2P em `assets/fonts/pixel.ttf`, Palette.BUTTON_*, 6 ícones novos (gear/x_close/arrow_left/arrow_right/play_triangle/check).
- [`memory/gameplay_systems.md`](memory/gameplay_systems.md) — turnos, dois modos de deck, tipos de carta, tabela de efeitos suportados vs. declarados.
- [`memory/combat_animation.md`](memory/combat_animation.md) — fases `idle → cards_flying → processing → damage_dealing → complete` e contrato do `isBlocking()`.
- [`memory/audio_system.md`](memory/audio_system.md) — `_G.audioSystem`, detecção WSL2, fallback pcall e regra de ouro para tocar sons.
- [`memory/ui_rendering.md`](memory/ui_rendering.md) — renderização 3D Balatro (Card.lua), HudManager, Theme, FontManager.
- [`memory/conventions.md`](memory/conventions.md) — regras de estilo: OOP via metatables, PT-BR, Config responsivo, Palette, zero-dep.
- [`memory/known_gaps.md`](memory/known_gaps.md) — lista de legado e incompleto para não "consertar" acidentalmente.
- [`memory/card_database.md`](memory/card_database.md) — estrutura de uma carta, classes (warrior/mage/rogue), raridades e imagens existentes.
- [`memory/run_instructions.md`](memory/run_instructions.md) — como rodar, atalhos de teclado e localização de docs.

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

**Como adicionar arte nova:** ver [`src/ui/README_PixelArt.md`](src/ui/README_PixelArt.md) (guia passo-a-passo atualizado).
