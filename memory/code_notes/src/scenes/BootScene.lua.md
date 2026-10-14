---
name: code_notes/src/scenes/BootScene.lua
description: Comentários com decisão/regra/histórico colhidos de src/scenes/BootScene.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/scenes/BootScene.lua`

Origem: `src/scenes/BootScene.lua` em `7dbdb60d` (44 de 97 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local Palette         = require("src.ui.Palette")`)

> src/scenes/BootScene.lua
> Splash + loading bar inicial. Inspirado em balatro-source/game.lua:1373-1515
> (Game:splash_screen) mas escala mais minimalista — 12 cartas em vez de 200,
> e usamos o PNG de splash como background em vez de vortex shader.
>
> Fases internas:
> "intro"   (~5s)   — ABERTURA (Out/2026, IntroTube): página de pergaminho
> com o televisor pequeno datilografando o título;
> mergulha no tubo e só então o CRT de tela cheia liga
> (callbacks.onTubeOn). Desligada em tools/testes
> (callbacks.intro = false, default sob HEADLESS_TOOL).
> "loading" (~0.5s) — barra de progresso pixel sépia, fade-in.
> "splash"  (~3.0s) — burst central + carta materializa/dissolve + cascade
> de 12 mini-cartas + flash final + transição menu.
> "done"            — terminou, BootScene para de desenhar.
>
> Skippable: qualquer keypress/click pula direto pro menu (clear_queue("boot")
> + onComplete).
>
> Uso:
> BootScene.init({ onComplete = function() currentState = "menu" end })
> BootScene.update(dt) / BootScene.draw() / BootScene.keypressed(key)

## L65-78 (em `MINI_SIZE`, junto a `local PHYS = {`)

> v14 (Out/2026, dono: "as cartas entram coordenadas demais, pouco
> aleatórias"): o redemoinho deixou de ser uma curva paramétrica igual pra
> todas (stagger fixo 0.075 s, ângulos em cadeia i·0.7, mesmo expoente) e
> virou FÍSICA por carta, SEMEADA por boot:
> • nascimento em rajadas (intervalos exponenciais + pausas ocasionais);
> • lançamento tangencial com velocidade/quiralidade/entrada próprias;
> • atração da lua ∝ 1/r^PULL_POW + arrasto → espiral que aperta sozinha,
> cada carta com a sua (algumas passam raspando, outras caem reto);
> • giro próprio amortecido somado à tangente; escala própria;
> • leve OVERSHOOT: a carta passa um pouco do centro antes de ser puxada
> de volta e absorvida (nada de colapso seco no ponto);
> • absorção solta LASCAS na grade de pixels da arte (4-7 quadradinhos
> do tamanho de 1 px da arte, vida curta) — pixel-nativo, sem glow.
> A semente é guardada em state.seed (log no console; BOOT_SEED força).

## L84 (em `PHYS`, junto a `maxLife   = 3.2,`)

> teto de voo (s) — nenhuma carta fica orbitando

## L86-88 (em `PHYS`, junto a `lifeMin   = 1.05, lifeMax = 1.75,`)

> ENVELOPE: a física dá o giro orgânico; a chegada é GARANTIDA por um
> raio-teto r ≤ r0·(1 − u^pw) (u = idade/vida, pw sorteado por carta).
> Sem isso uma carta lançada rápido demais orbita ou foge da tela.

## L100-107 (em `rnd`, junto a `local bg = {`)

> ============== Fundo "PAREDE-SELO" (v9, Jul/2026) ==============
> Feedback do dono consolidado: nada de plasma do Balatro por cima, nada de
> partículas/glow de motor, nada de elemento que implore animação. Composição:
> 1. PAREDE-SELO pixel art (frame_00: pedra escura + selo entalhado, estática
> por natureza — sem tochas/fogo) = o fundo.
> 2. CARGA DO SELO (boot_seal_glow.glsl): a PRÓPRIA arte redesenhada em
> blend aditivo — só os entalhes/inlay dentro do disco acendem; respira,
> pulsa por carta absorvida (flare) e estoura no flash. O glow É a arte.

## L155-160 (em `drawShards`, junto a `local SIGIL_IX, SIGIL_IY = 179, 40`)

> ÂNCORA NA ARTE (pixels da imagem 256×192). A arte é a NOITE DO GRIMOIRE
> (v10, PixelLab): colinas + silhueta do castelo + LUA dourada. A lua é o
> coração: destino das cartas e o que "carrega" (halo respira/pulsa).
> Centro do DISCO medido com threshold alto (o centroide anterior misturava
> estrelas): (179, 40); raio útil ~30 (disco + halo) — as cartas caem DENTRO
> da lua (feedback: "centralizar pra ficar realmente dentro").

## L164-165 (em `drawShards`, junto a `local function chamberAnchor(ix, iy)`)

> Converte pixel da arte → tela, usando o transform do último draw (cover).
> A âncora fica COLADA na arte em qualquer resolução/aspect.

## L174-176 (em `chamberAnchor`, junto a `local sigil = { flare = 0 }`)

> Pulso de absorção do selo (0..1, decai): alimenta o uniform `flare` do
> shader — a energia clareia POR DENTRO. Nada é desenhado por cima da arte
> (os anéis/glows/partículas antigos saíram — feedback: "ridículo").

## L204-206 (em `loadBg`, junto a `local pc = bg.dir .. "/clouds.png"`)

> Nuvens em PARALLAX (opcional — v10 "noite do Grimoire"): camada com
> transparência que desliza devagar sobre o céu. Se o PNG não existe
> (arte ainda não gerada), o fundo funciona sem nuvens.

## L214-217 (em `loadBg`, junto a `local function drawClouds()`)

> Camada 1b: nuvens deslizando em 2 profundidades (animação clássica de
> pixel art — suave por natureza, zero flicker). A arte tem margens vazias,
> então o wrap horizontal não mostra emenda. Velocidades em px da ARTE por
> segundo (bem lentas — céu noturno, não vendaval).

## L224-227 (em `drawClouds`, junto a `for _, L in ipairs({`)

> Offsets medidos da arte: conteúdo das nuvens vive em y 23..103 do canvas
> 256×128 → iy -16/-2 coloca as duas camadas na faixa do CÉU (as nuvens
> cruzam a lua de vez em quando — clássico de noite; borda inferior da
> camada 2 encosta de leve nos cumes a alpha baixo, lê como névoa).

## L247-248 (em `drawClouds`, junto a `local function drawChamberBG()`)

> Camada 1: a câmara pixel art (SEMPRE — é o background). Guarda o transform
> do cover em bg._tx/_ty/_s pras âncoras (sigilo/braseiros) colarem na arte.

## L269-272 (em `drawChamberBG`, junto a `local function drawStarTwinkle()`)

> Camada 1c: CINTILAÇÃO das estrelas (v11) — cada estrela pisca no próprio
> ritmo (shader boot_star_twinkle, aditivo sobre a própria arte). Lua e
> colinas excluídas no shader. Pergunta do dono ("dá pra animar os pontinhos?")
> respondida: dá, e é isto.

## L292-295 (em `drawStarTwinkle`, junto a `local function drawMoonVortex(t, strength)`)

> Camada 1d: REDEMOINHO NA LUA (v12) — os PRÓPRIOS pixels do disco giram
> (forte no miolo, zero na borda: emenda invisível com a arte parada).
> Justifica a sucção das cartas: a lua é um portal se agitando. t = tempo
> do splash (bounded); strength = carga + flare.

## L312-316 (em `drawMoonVortex`, junto a `local function drawSealCharge(strength)`)

> Camada 2: CARGA DO SELO (v9). O plasma derivado do Balatro FOI EMBORA
> ("o efeito que fica em cima ainda não tá bom"). No lugar: a PRÓPRIA ARTE
> redesenhada em blend aditivo com o shader boot_seal_glow — só os pixels
> claros (entalhes/inlay) dentro do disco do selo acendem. O glow É a arte:
> pixel-nativo, sem material estranho por cima.

## L334-336 (em `drawSealCharge`, junto a `function BootScene.init(callbacks)`)

> (v8: drawSigilGlow/drawChamberLife/embers REMOVIDOS — feedback do dono:
> "tire essas partículas de faísca e de luz, está ficando bem ridículo".
> v9: o plasma boot_splash.glsl também saiu — resposta visual = carga do selo.)

## L371-373 (em `shards`, junto a `local intro = callbacks.intro`)

> ABERTURA antes da sintonia: página + televisor pequeno (IntroTube).
> Quando ela mergulha no tubo, o CRT de tela cheia LIGA (onTubeOn:
> main.lua reabilita o shader e dispara powerOn) e o loading começa.

## L388-391 (em `shards`, junto a `function BootScene._tubeOn()`)

> A TV LIGANDO: som + warm-up do CRT (main.lua passa onTubeOn com o
> CRTShader.powerOn(1.8): ponto → linha → abre → assenta). Depois do
> mergulho da abertura a borda já é a do gabinete (a arte termina na
> abertura do CRT) e o vidro liga DENTRO dela — o efeito fica.

## L412-413 (em `startSplashSequence`, junto a `_G.EventManager.parallelEase(state, "sealCharge", 1.0, 2.0, "smooth", QUEUE)`)

> Energia arcana desperta DEVAGAR em volta do sigilo (2s de fade).
> O selo CARREGA devagar (entalhes acendendo ao longo de 2s).

## L420 (em `startSplashSequence`, junto a `state.titleLetters = {}`)

> Título letra-a-letra (pedido do dono): pré-quebra em codepoints UTF-8.

## L437-442 (em `state.titleLetters`, junto a `EM.parallel(1.50, function() Sfx.play("bootVortex") end, QUEUE)`)

> IMPORTANTE: tudo abaixo usa parallel/parallelEase porque queremos
> timeline ABSOLUTO (vários eventos simultâneos), não sequencial.
>
> v11 (feedback do dono): SEM carta central — a cena abre CONTEMPLATIVA
> (~1.8s só de noite: estrelas cintilando, nuvens andando, lua acordando)
> antes de qualquer carta. Nada "já começa dentro da lua".

## L447-453 (em `state.titleLetters`, junto a `EM.parallel(1.75, function() Sfx.play("bootCardWhoosh") end, QUEUE)`)

> 1.80s+: REDEMOINHO de cartas na lua, staggered 0.08s (janela ~1.7s).
> Coords em POLAR (angle, distFrom) a partir do centro da lua.
> Voa com ease_OUT (decelera ao chegar); TODAS orbitam no MESMO
> sentido e aceleram perto do centro → lê como furacão/redemoinho
> entrando na lua (não espirais aleatórias).
> Scale pop-in → collapse no centro (sucção). Computado em update.
> 1.75s: WHOOSH grave da massa de cartas convergindo.

## L456-471 (em `state.titleLetters`, junto a `local reduced = _G.gameSettings and _G.gameSettings.reducedMotion`)

> v13 REDEMOINHO DE VERDADE (feedback: "não está tão bom, precisa ser
> mais bem feito"). O voo antigo era um ease radial com ~1 rad de arco:
> lia como riscos retos convergindo. Agora a cinemática é de DRENO:
> • raio: r = R·(1 − u^1.7) — parte lenta e majestosa, ACELERA ao
> cair (matéria despencando no portal), não o contrário;
> • giro: θ = θ0 + swirl·u^2.2 — o enrolar APERTA perto da lua
> (quase todo o arco acontece no mergulho final);
> • braços de GALÁXIA: cartas em cadeia (θ0 = base + i·0.7), não
> ângulos aleatórios — o fluxo lê como correnteza entrando;
> • orientação: a carta SURFA a tangente da espiral (rot = θ+90°
> com wobble sutil), nada de tumble aleatório;
> • escala/alpha: pop-in no nascimento, encolhe com o raio, e o
> fade final acontece DENTRO do disco (some na luz, não no ar).
> v14: NASCIMENTO EM RAJADAS (intervalo exponencial, média 0.07 s, com
> pausa ocasional) — nada de metrônomo. Quiralidade da maioria sorteada
> por boot; cada carta recebe lançamento, giro e escala próprios.

## L485 (em `state.titleLetters`, junto a `local angle0 = rnd(0, math.pi * 2)`)

> sorteios FORA do callback: a ordem dos eventos não muda a semente

## L533-535 (em `trail`, junto a `local T_TITLE = tCascadeEnd + 0.25`)

> TÍTULO LETRA-A-LETRA (feedback do dono): cada letra "carimba" na tela
> com pop back_out + tick sonoro em pitch crescente. Começa DEPOIS da
> cascade assentar — nada de atropelar.

## L553-554 (em `trail`, junto a `local tFlash = tTitleEnd + 1.0`)

> RESPIRO: título completo pousado, energia girando — segura ~1s antes
> do clímax (feedback: "já muda direto pro menu, isso está errado").

## L592-594 (em `BootScene.update`, junto a `local sx, sy = chamberAnchor(SIGIL_IX, SIGIL_IY)`)

> v14 FÍSICA por carta (ver PHYS): atração da lua + arrasto +
> giro amortecido. Coords ABSOLUTAS (a âncora da lua é lida por
> frame — resize não quebra). Absorção = raio de captura ou teto.

## L605 (em `BootScene.update`, junto a `local a = PHYS.pullG * K * K / (rr ^ PHYS.pullPow)`)

> atração ∝ 1/r^pow (K² porque força é px/s²)

## L614-616 (em `BootScene.update`, junto a `local u = math.min(1, mc.age / mc.life)`)

> ENVELOPE de chegada: raio-teto cai com u^pw; se a física
> deixou a carta além dele, ela é puxada radialmente pro teto
> (o giro fica, a chegada é garantida)

## L655-656 (em `BootScene.update`, junto a `if r < capR or mc.age >= mc.life + 0.4 or mc.age >= PHYS.maxLife then`)

> ABSORVIDA: dentro do raio de captura (ou teto de voo — nenhuma
> carta fica orbitando a lua pra sempre)

## L672-674 (em `drawBackground`, junto a `drawChamberBG()`)

> CAMADAS: paisagem pixel (base) → estrelas cintilando → nuvens em
> parallax (passam NA FRENTE das estrelas) → CARGA da lua (halo
> respirando + pulso por carta absorvida).

## L696-697 (em `drawBackground`, junto a `function BootScene.previewBackground(t, charge, flare)`)

> Preview do fundo completo pro tool de validação (screenshot_bootfx):
> desenha todas as camadas num instante t, com flare forçado.

## L710-711 (em `drawLoadingBar`, junto a `local W, H = love.graphics.getWidth(), love.graphics.getHeight()`)

> v2: a "carga" é a TV SINTONIZANDO — label + barra de segmentos OSD
> verde-fósforo (mesma linguagem do volume de TV velha).

## L729-731 (em `drawLoadingBar`, junto a `local function drawCardShape(x, y, w, h, alpha, scale, rot, dissolveAmount)`)

> Wrapper sobre src/ui/CardBack. Aplica ambient breathing (mesma lógica do
> ambient tilt de Card.lua) — cada carta com fase única baseada em posição,
> evitando sincronia. Sem mouse hover (cartas voando rápido).

## L734 (em `drawCardShape`, junto a `local tiltX = math.sin(t * 1.4 + x * 0.07) * 0.04`)

> Tilts em TILT_RANGE units (radianos). 0.04 ≈ 30% de TILT_RANGE = sutil.

## L754-756 (em `drawSplash`)

> v7: o DESTINO das cartas é o SIGILO (não o centro vazio da tela) — elas
> são visivelmente absorvidas por ele, que responde com flare + anéis
> (o alvo é lido por quem move cada carta, via chamberAnchor).

## L758-761 (em `drawSplash`, junto a `for _, mc in ipairs(state.miniCards) do`)

> Mini-cartas primeiro (z-order: ficam atrás da central). Coords em polar
> (angle, distFrom) a partir do selo — âncora live, resize não quebra.
> Cada carta arrasta um rastro de FÓSFORO (ghosting CRT): fantasmas da
> pose recente com alpha decaindo — velho primeiro, carta por cima.

## L763-764 (em `drawSplash`, junto a `local ghostA = { 0.26, 0.17, 0.11, 0.06, 0.035 }`)

> 5 fantasmas com falloff acentuado: o velho quase some — o rastro
> lê como arco de luz na espiral, não como carta duplicada.

## L779-781 (em `ghostA`)

> (v11: a carta central FOI REMOVIDA — feedback do dono: "pode deixar
> direto já no ponto focal da lua". A cena abre contemplativa e o
> redemoinho entra sozinho.)

## L783-785 (em `ghostA`, junto a `if #state.titleLetters > 0 then`)

> TÍTULO LETRA-A-LETRA: cada letra carimba com pop próprio (alpha/scale
> individuais, animados pela timeline). Outline ink + face dourada com
> pulse dessincronizado por letra.

## L787-788 (em `ghostA`, junto a `love.graphics.setShader()`)

> CardBack pode deixar o DissolveShader ativo (carta central termina
> em dissolve=1) — sem reset as letras saem corroídas/escuras.

## L835 (em `drawSkipHint`, junto a `local pulse = 0.5 + math.sin(love.timer.getTime() * 2) * 0.2`)

> Pulse sutil pra atrair olhar mas não distrair.

## L896-898 (em `shards`, junto a `if _G.audioSystem and _G.audioSystem.stopGroup then`)

> SYNC (feedback): mata qualquer SFX de boot (raio/rumble/impacto) ANTES do
> menu + música entrarem — o barulho de raio vazava pro menu. stopGroup só
> corta o grupo "sfx"; a música (grupo "music") não é afetada.

## L905-906 (em `shards`, junto a `function BootScene.keypressed(_)`)

> Pular na abertura pula SÓ a abertura (cai na sintonia); pular de novo
> pula o boot inteiro.

