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

---

## Entrada v2 — fundo animado + sonoridade (Jul/2026)

Pedido do dono: "deixar a entrada muito mais completa, boa impressão logo de cara". Escolhas: **fundo 100% animado via PixelLab** + **3 SFX novos via ElevenLabs**.

**Fundo animado (PixelLab)**: câmara ritual 256×192 em loop (chamas tremeluzem, sigilo dourado pulsa, brasas sobem, flicker de luz). 11 frames em `assets/sprites/scenes/boot_anim/frame_NN.png` + `meta.lua` (`{ fps = 9 }`). 256×192 → **4× exato** pra 1024×768 (pixels nítidos, `setFilter("nearest")`) — respeita o teto de 256px da animação v3 do PixelLab. `BootScene.drawBootAnimBG` faz cover-fit; `loadBootAnim` carrega lazy no 1º draw. Fallback: `splash.png` estático → menu → ink. Desenhado a alpha 0.9 (contraste pro primeiro plano). Regenerar: `create_map_object` 256×192 side + `animate_object` v3 (frame_count máx **10** nesse tamanho, gera 11 com keep_first_frame); baixar via `scratchpad/dl_boot_anim.py` (token do ~/.claude.json, URLs backblaze i=0..10).

**SFX novos (ElevenLabs, `audio/sfx/boot-*.mp3`, gerados por `scratchpad/gen_boot_sfx.py`)**:
- `bootTvPowerOn` — TV ligando (degauss thunk + zunido de alta-tensão + hum). Tocado em `BootScene.init`, casa com `CRTShader.powerOn(1.8)` de main.lua.
- `bootCardWhoosh` — whoosh grave da convergência das cartas (t=1.35s, antes da cascade).
- `bootImpact` — impacto grave no flash (t=2.70s) + `_G.triggerShake(6, 0.35)` (micro screen-shake, punch Balatro). O `comboTrigger` antigo em 2.85 foi removido. Os `cardDraw` por carta caíram pra volume 0.42 (o whoosh dá o corpo).

Registro em `main.lua` (`loadSound` do bloco boot). Chave ElevenLabs na auto-memória do Claude (`elevenlabs-api-key`); PixelLab via MCP (`pixellab_mcp`).

## Entrada v3 — vórtice procedural + base estática (Jul/2026)

Feedback do dono sobre a v2: o loop PixelLab "piscava/quebrava" (cada frame é redesenhado pela IA → shimmer) e o fundo não refletia as cartas indo pro centro. Redesenho:

- **Base ESTÁTICA**: `BootScene.drawBootAnimBG` agora usa SÓ `frame_00` (idx fixo = 1) — zero flicker. Os 10 frames extras foram removidos (`meta.frames = 1`). A vida vem toda do BootFX.
- **`src/ui/BootFX.lua`** — vórtice 100% procedural (código), dirigido por `intensity` 0..1: buraco escuro abrindo no centro + aro incandescente, **rachaduras** radiais espalhando pela pedra, **eletricidade** (raios jagged azul-elétrico + glow), **brasas sugadas** em espiral pro centro, glow/bloom dourado. RNG cosmético = `love.math.random`. Additivo pro glow/energia; alpha pro buraco/rachaduras. `reset/update(dt,intensity)/draw(cx,cy,baseRadius,intensity)`.
- **Timeline mais longa (~4.25s)** e sincronizada em `startSplashSequence`: 0.85 pedra racha (`bootVortex`, vortex→0.40) → 1.10 carta central SUGADA (dissolve+encolhe pro centro) → 1.30 `bootElectric` (vortex→0.72) → 1.40+ cascade de **22** cartas (stagger 0.07) voando pra DENTRO do buraco → 2.10 título → 3.00 vortex→1.0 (`bootElectric`) → 3.65 flash + `bootImpact` + shake 10 + buraco IMPLODE (vortex→0) → 4.25 menu. BootFX desenhado ATRÁS das cartas em `drawSplash`.
- **SFX v3** (ElevenLabs, `audio/sfx/boot-{electric,vortex}.mp3`, `scratchpad/gen_boot_sfx2.py`): `bootElectric` (crackle de alta-tensão), `bootVortex` (rumble/sucção do portal). Registrados em main.lua.
- **Validar o look**: `love . screenshot_bootfx` (só com o jogo FECHADO) → 3 PNGs (intensity 0.4/0.7/1.0) no save dir `%APPDATA%/LOVE/card-game/`.

## Entrada v4 — o FUNDO anima (warp de sucção) + sync + eletricidade sépia (Jul/2026)

Feedback: "o fundo não tem nada acontecendo (raio na frente de foto parada); o som do raio vaza pro menu; os raios azuis não combinam com o design".

- **`shaders/boot_warp.glsl`** — o PRÓPRIO fundo agora anima: swirl (giro) + pinch (contração) da imagem-base em torno do centro, dirigido por `state.vortex`, concentrado no miolo (`f2 = frac²`). A pedra inteira roda e é sugada pro buraco — suave, sem flicker (distorção de UV de UMA imagem). `t` = `state.splashTime` (BOUNDED; `love.timer.getTime()` enrolaria infinito). `drawBootAnimBG(alpha, warp, warpT)` aplica o shader + zoom dolly-in (`1+0.12*warp`). Base com `setWrap("clamp")`. Verificado por screenshot: a câmara vira um maelstrom dourado espiralando no vazio central.
- **Eletricidade SÉPIA**: `BootFX` `SPARK` mudou de azul-elétrico `{0.72,0.92,1.0}` → branco-dourado quente `{1.0,0.94,0.66}` (arcana, não sci-fi).
- **Sync de som (bug do vazamento)**: (1) `bootElectric` regerado CURTO (~1.4s) e tocado SÓ em 1.30 (o play de 3.00 vazava 2.8s pro menu — removido). (2) `BootScene._finish()` (e skip, via _finish) chama `_G.audioSystem:stopGroup("sfx")` ANTES do `onComplete` — mata raio/rumble/impacto pendentes; a música (grupo "music") não é afetada. Nada de SFX de boot vaza pro menu.

## Entrada v5 — REBASE no Balatro de verdade (Jul/2026) ⭐

Feedback do dono: v3/v4 ficaram "toscas" (tela girando, raio, warp de foto). Fui ler o `balatro-source` de verdade — `game.lua:1373 Game:splash_screen` + `resources/shaders/splash.fs` + `vortex.fs`. O que o Balatro FAZ:
- Fundo = shader `splash.fs` = **plasma/swirl de cor SUAVE** (não foto distorcida, não raio). Swirl de centro + domain-warp "fumaça" 5 iterações, blend de 2 cores sobre base escura. `mid_flash`→branco no fim.
- Carta "joker" central materializa → dissolve (whoosh1/introPad1/magic_crumple/splash_buildup).
- 200 cartas **sugadas** pro centro: `ease_value` escala→NEGATIVA (encolhe através do zero) + pos→centro, decelerando; `card.vortex=true` (o `vortex.fs`, um VERTEX shader, curva as CARTAS — não a tela).
- Flash branco → main_menu.

**O que fiz (adaptado, não copiado)**:
- **`shaders/boot_splash.glsl`** = port do splash.fs pra paleta SÉPIA (colour_1 ouro, colour_2 pergaminho, base ink marrom). É o fundo profissional suave. `BootScene.drawPlasmaBG(t, midFlash)` desenha fullscreen com `time = splashTime`.
- **JOGADO FORA**: `src/ui/BootFX.lua` (vórtice/raio/rachaduras procedurais) e `shaders/boot_warp.glsl` (warp da foto) — DELETADOS. Nada de tela girando nem raio.
- Cartas sugadas pro centro (mini-cards existentes, escala colapsa no centro) sobre o plasma.
- Sons Balatro-like: powerOn (init) → deckStart (0.5) → bootVortex buildup no dissolve (1.10) → bootCardWhoosh (1.35) + cardDraw por carta → flash + bootImpact + shake leve (3.55) → menu (4.10). `bootElectric` não é mais usado.
- `frame_00.png` da pedra vira só FALLBACK se o shader falhar.
- **Validar**: `love . screenshot_bootfx` (jogo FECHADO) → `bootsplash_t{2,5,9}.png` + `_flash.png` no save dir.

## Entrada v6 — pixel art de volta + energia "nossa" + letra-a-letra (Jul/2026)

Feedback do dono na v5: (1) o pixel art sumiu — tem que ser O fundo, com animação; (2) o plasma não pode ser o Balatro literal — "baseado, com a nossa cara"; (3) rápido demais — as letras do título devem entrar UMA A UMA e ter respiro antes do menu.

**Fundo em 3 CAMADAS** (`drawBackground`):
1. **Câmara ritual pixel art** (frame_00, estática) — SEMPRE, é o background.
2. **Energia arcana** (`boot_splash.glsl` retrabalhado): MÁSCARA RADIAL in-shader (`edge = 1-smoothstep(0.16,0.46,uv_len)`) concentra o plasma no MIOLO em volta do sigilo — a câmara fica visível nas bordas. Paleta ouro+brasa-sangue (não azul/branco), `vort_speed 0.6` (lento), `PIXEL_SIZE_FAC 300` (pixels chunky casando com o 4×), 4 iterações de warp com coeficientes próprios. Alpha do Lua (vertex colour) — fade de 2s via `state.plasmaAlpha`.
3. **Brasas** (`embers` em BootScene): quadradinhos pixel (1-2 "pixels" da arte, `H/256`) subindo — 60% nascem nos BRASEIROS da câmara (x≈0.12/0.88, y≈0.40), 40% do chão; sway senoidal + flicker; ouro/rubro; cap 36. Vivem em TODAS as fases (o cenário respira desde o loading).

**Título LETRA-A-LETRA**: `state.titleLetters` = codepoints UTF-8 de `menu.title` (`require("utf8")`); cada letra tem alpha/scale próprios, "carimba" (scale 1.8→1 back_out) com tick `cardDraw` em pitch crescente (espaços não tocam som). Stagger 0.09s, começa DEPOIS da cascade assentar. O glitch RGB antigo do título foi removido (era single-print).

**Timeline v6 (~7s, dinâmica)**: 0.10 carta central → 0.50 deckStart → 1.40 dissolve+bootVortex → 1.65 whoosh → 1.70+i·0.08 cascade (22 cartas) → `tCascadeEnd+0.25` letras (stagger 0.09) → **RESPIRO de 1s** com tudo pousado → flash+bootImpact+shake → +0.60 menu. Tempos do título/flash calculados de `#titleLetters` (i18n muda o comprimento).

v6.1: crescimento de densidade do plasma CAPADO em 2.0 (sem cap, aos ~7s virava borrão dourado engolindo a câmara — pego por screenshot).

## Entrada v7 — o SIGILO é o coração (Jul/2026)

Feedback do dono na v6: energia "jogada aleatoriamente" (ainda cheirava a Balatro), fundo sem animação própria, cartas "indo para nada". Causa-raiz única: a cena não tinha um CORAÇÃO. v7 amarra tudo no SIGILO da câmara:

- **Âncoras NA ARTE** (`SIGIL_IX/IY = 128,64`; `BRAZIERS_IMG = {33,60},{223,60}` — pixels da imagem 256×192): `chamberAnchor(ix,iy)` converte pra tela usando o transform do cover (`bg._tx/_ty/_s` salvos em `drawChamberBG`) — cola em qualquer resolução.
- **Energia EMANA do sigilo**: shader ganhou `center_off` (uv normalizado pela diagonal) e máscara apertada `smoothstep(0.10, 0.30)` — o swirl abraça o círculo do sigilo, nada de blobs soltos pela tela.
- **Cartas voam PRO SIGILO** (mini-cards, carta central e burst usam a âncora). Cada carta absorvida → `bumpSigil()`: flare (+0.32, decai 1.6/s) + ANEL de absorção expandindo (240px/s). O destino existe e RESPONDE.
- **Vida na arte** (`drawChamberLife`): chamas dos braseiros tremulando (2 círculos additive, flicker QUANTIZADO em passos de 1/8s pra ler como pixel art) + poça de luz do sigilo no piso (elipse additive pulsando; flare ilumina o salão). `drawSigilGlow`: 3 círculos additive pulsantes + anéis.
- Ordem de camadas: câmara → plasma (sigilo) → glow do sigilo → chamas/piso → brasas.
- **Preview fiel**: `BootScene.previewBackground(t, plasmaAlpha, flare)` — o tool `screenshot_bootfx` usa as MESMAS camadas do jogo (gera `bootv7_{early,absorb,late}.png`).

⚠️ v7 LUAC-CLEAN mas SEM verificação visual (jogo do dono aberto) — rodar `love . screenshot_bootfx` na primeira janela livre.

## Entrada v8 — "o Selo é um portal" (Jul/2026)

Feedback do dono na v7: (1) tochas estáticas no fundo ficam RUINS — se não dá pra animar direito, o background não deve ter elementos que imploram animação; (2) partículas de faísca/luz desenhadas por cima = "ridículo", TIRAR; (3) efeito das cartas melhor mas ainda tosco — conectar com a identidade CRT, menos Balatro, tudo coeso. **"Planeje bem antes de fazer."**

**Conceito coeso**: o fundo é uma PAREDE de pedra com um SELO entalhado no centro (arte estática por natureza — sem fogo/tocha). O selo é um PORTAL: a energia arcana vive DENTRO do disco dele, as cartas voam pra dentro, e cada absorção dá um pulso de brilho NA PRÓPRIA energia (uniform `flare` no shader — nada desenhado por cima). No flash, flare=1 (o selo estoura junto).

- **Arte nova**: `create_map_object` 256×192 "dark stone wall + carved circular seal, NO fire/torches/light sources" → substitui `boot_anim/frame_00.png`. Âncora `SIGIL 128,96` (centro da imagem). ⚠️ CONFERIR o centro/raio reais na arte gerada e ajustar `SIGIL_IX/IY` + máscara do shader (`smoothstep(0.10, 0.24)`) pro disco do selo.
- **REMOVIDOS**: embers, drawSigilGlow (círculos+anéis), drawChamberLife (chamas/poça) — todo glow "de motor 3D" por cima do pixel art.
- **Rastro de FÓSFORO nas cartas** (identidade CRT nossa): cada mini-carta guarda 3 poses recentes (~35ms) e desenha fantasmas com alpha decaindo (0.17/0.12/0.07) — ghosting de tubo antigo.
- Shader: `extern number flare` → `outc.rgb *= 1+0.65*flare` + máscara expande de leve.
- PixelLab caiu no meio (503/circuit breaker) — download da arte via poll em background; instalar em frame_00.png quando chegar e VALIDAR por screenshot (centro do selo + look).

## Entrada v9 — CARGA DO SELO (o plasma morreu de vez) ⭐ (Jul/2026)

Feedback: "esse efeito que fica em cima ainda não tá bom" — o plasma domain-warp (mesmo mascarado) nunca casou com o pixel art. **v9 mata o boot_splash.glsl** (DELETADO) e troca por:

- **`shaders/boot_seal_glow.glsl`**: redesenha A PRÓPRIA ARTE em blend "add", realçando só pixels CLAROS (`hi = (lum-0.18)/0.82`) dentro do disco do selo (máscara radial `smoothstep(0.55, 1.0, d)`). Efeito = os entalhes/inlay dourado ACENDEM — o glow É a arte, pixel-nativo, zero material estranho. Uniforms: `center`/`radius` (px de tela), `strength`.
- **Arte nova instalada** (`frame_00.png`): PAREDE-SELO — pedra escura + selo entalhado gigante (anel de runas + estrela, inlay ouro/bronze), SEM tochas/fogo (estática por natureza). Âncora `SIGIL 128,96`, `SEAL_RADIUS_IMG 80` (medidos na arte). A câmara ritual antiga saiu.
- **Driver**: `state.sealCharge` (ease 0→1 em 2s no splash) × respiração `0.34+0.14·sin(1.8t)` + `0.66·flare` (pulso por carta absorvida; flare=1 no flash). `drawSealCharge(strength)` desenha com o MESMO transform do cover.
- Validado por screenshot (bootv9_{early,absorb,peak}.png): parede-selo pelo tubo = capa de grimório; brilho cresce com carga/flare, contido.
- Nota: o título letra-a-letra sobrepõe o arco inferior do selo — legível pelo outline ink; lê como lockup de logo.

## Entrada v10 — "noite do Grimoire" (paisagem ANIMÁVEL) — EM ANDAMENTO (Jul/2026)

Feedback do dono na v9: a parede-selo "parece ritual estático, ficou estranho" — quer um fundo que DÊ pra animar. Conceito v10, escolhido pelo que sabemos animar bem:
- **Base**: paisagem noturna — colinas escuras + SILHUETA DO CASTELO (destino da run) no horizonte + LUA dourada grande no alto + estrelas. (`frame_00.png`)
- **Nuvens em PARALLAX** (`boot_anim/clouds.png`, transparente, margens vazias): 2 camadas deslizando em velocidades/alturas/alphas diferentes (2.2 e 3.8 px-de-arte/s, segunda flipada) — `drawClouds()` com wrap horizontal (margens vazias = emenda invisível). Animação clássica, suave, zero flicker. PNG ausente → fundo funciona sem nuvens.
- **A LUA é o coração**: cartas voam pra ela; `boot_seal_glow` (luminância) faz o halo respirar e pulsar por absorção. Reapontar `SIGIL_IX/IY` + `SEAL_RADIUS_IMG` pro centro/raio da lua QUANDO a arte chegar.
- **Status: ENTREGUE e VALIDADO** ✅. O outage do PixelLab foi contornado pelo gerador em background (`scratchpad/pixellab_boot_bg.py`, cliente MCP HTTP que retenta — padrão reutilizável pra outages futuros). Artes instaladas: `frame_00.png` (paisagem) + `clouds.png` (nuvens transparentes). **Âncora da LUA medida por centroide dos pixels claros: (173, 46), raio 34** (`SIGIL_IX/IY`/`SEAL_RADIUS_IMG`). Offsets das nuvens medidos do alpha-bbox (conteúdo y 23..103 do canvas 256×128 → camadas em iy -16/-2). Validado por screenshot pelo tubo: lua flareia entre early/peak, nuvens cruzam a lua, castelo na crista esquerda, título cai sobre as colinas escuras (contraste ótimo).
