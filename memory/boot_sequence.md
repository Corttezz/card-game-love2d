---
name: Boot Sequence
description: BootScene (loading + splash) + Menu intro animation, Balatro-style boot flow
type: project
---
Substitui o flow antigo (boot → menu instantâneo) por uma sequência inspirada em `balatro-source/game.lua:1373-1714` (`Game:splash_screen` + `Game:main_menu`).

**Estado inicial em `main.lua`**: `currentState = "boot"` (era `"menu"`). `BootScene.init` é chamada no fim de `love.load` com callback `onComplete` que: troca pra `"menu"`, chama `menu:show()` + `menu:enterWithIntro()`.

**Componentes:**

- `src/scenes/BootScene.lua` — duas fases: `"loading"` (~0.5s, barra de progresso pixel sépia) → `"splash"` (~3s, sequência cinematográfica).
- `assets/sprites/scenes/splash.png` — background ritualístico gerado via PixelLab MCP (400×256, runas douradas em câmara de pedra). Carregado via `SceneBackground.draw("splash")`.
- `assets/cards/back.png` — verso de carta gerado via PixelLab MCP (256×384, 2:3 aspect das cartas). Borda parchment + filigrana gold + 4 medalhões + banners topo/base + sigilo central (olho em estrela 8 pontas com runas).
- `src/ui/CardBack.lua` — single source of truth pro verso. Tenta carregar `back.png`; cai pro fallback geométrico (corpo INK + borda gold dupla + diamante outline) se PNG faltar. Usado por BootScene (cascade do splash) e Menu (cartas flutuantes).
- `components/Menu.lua` — `enterWithIntro()` reanima alpha+slide+scale via `EventManager.parallelEase` na queue `"menu_intro"`.

**Splash timeline** (orquestrado via `EventManager.after(t, fn, "boot")`):

| t | Evento |
|---|---|
| 0.00 | Burst de 24 partículas douradas no centro (`ParticlesManager.spawn`) |
| 0.10 | Carta central começa a materializar (alpha 0→1, scale 0.3→1 com `back_out`) |
| 0.50 | `Sfx.play("deckStart")` (impacto sonoro) |
| 1.20 | Carta dissolve (alpha→0, dissolve→1) |
| 1.40-2.21 | 12 mini-cartas voam de bordas aleatórias pro centro, staggered 0.07s, com `cardDraw` SFX em pitch 0.85→1.15 |
| 2.40 | `FlashShader.trigger(1.0, 0.4)` — flash branco fullscreen |
| 2.55 | `Sfx.play("comboTrigger")` |
| 2.85 | `BootScene._finish()` → `currentState = "menu"` + `menu:enterWithIntro()` |

**Skip**: qualquer keypress/click em estado `"boot"` chama `BootScene.skip()` que `EventManager.clear("boot")` e dispara onComplete imediato. Usuários impacientes não precisam ver o splash inteiro.

**Menu intro** (queue `"menu_intro"`):
- Background alpha 0→1 em 0.35s (smooth)
- Título alpha 0→1 + scale 0.85→1 em 0.55s (back_out — pop)
- Subtítulo alpha 0→1 em 0.55s
- Botões staggered (0.30 + i*0.08s delay), alpha 0→1 + slide-up 12px (back_out)
- Música: `Sfx.playMusic("menuMusic", { fadeDuration = 1.5 })`

**Música**:
- `audio/music.mp3` carregado em `main.lua:love.load` como `menuMusic` (group="music", stream=true, loop=true, volume=0.6).
- `AudioManager:playMusic` agora suporta fade-in da silêncio (não só crossfade entre tracks) — quando `fadeDuration > 0` e não há `currentMusic`, usa `musicCrossfade` com `from=nil`.
- Click PLAY → `Sfx.fadeMusicOut(0.5)` antes do callback (definido em `src/systems/Sfx.lua`).
- Voltar pro menu (returnToMenu, collection close) chama `menu:enterWithIntro()` que rejoga a música.

**Cartas decorativas flutuantes** (Balatro-style demo): 3 retângulos pixel atrás do título, drift+rotação via `sin(t * freq + phase)` com fases dessincronizadas. Cores AGED_GOLD + BLOOD/STEEL/MOSS. Discretas (alpha 0.55) — não roubam foco do menu.

**Como adicionar tracks novas**:
1. Coloca o MP3 em `audio/`
2. `audioSystem:loadSound("act1Music", "audio/act1.mp3", { volume=0.5, group="music", stream=true, loop=true })` em main.lua
3. Chama `Sfx.playMusic("act1Music", { fadeDuration=1.0 })` no momento certo (Game:startGame ou similar). AudioManager faz crossfade automático com a música atual.

**Como ajustar timings do splash**: edite os `EventManager.after(...)` em `BootScene.lua:startSplashSequence`. Cada evento é independente; reordenar é seguro.

**Performance**: BootScene não cria objetos por frame — só atualiza state via EventManager.ease. Custo médio: ~0.1ms/frame em laptops modernos. Sem hot path issues.
