---
name: code_notes/src/ui/BossCinematic.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/BossCinematic.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/BossCinematic.lua`

Origem: `src/ui/BossCinematic.lua` em `7dbdb60d` (84 de 262 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-38 (junto a `local Data            = require("src.data.boss_cinematics")`)

> src/ui/BossCinematic.lua
> CINEMÁTICA DE CHEFE: entrada no salão e morte — runner dos roteiros de
> src/data/boss_cinematics.lua.
>
> Pedido do dono (Out/2026): a porta do castelo abre (cerimônia já existente,
> WorldRoad.enterCastle) → o salão abre VAZIO (sem chefe, sem HUD) → a entrada
> toca dentro do salão com o cenário do próprio salão → nome do chefe → HUD →
> luta. Na morte: colapso em câmera lenta, luz saindo dos olhos, rajada de
> penas e corvos, dessaturação breve, o corpo fica no salão e SÓ DEPOIS os
> espólios entram.
>
> COMO SE ENCAIXA (ver GameplayScene):
> * `startIntro(game)` é chamado pelo onComplete da porta (bossEntered=true).
> O Continuar (ResumeFlow → _debugForceBossEntered) NÃO passa por aqui:
> retomar dentro da luta é retomar na luta, sem repetir a entrada.
> * A cena pergunta `hidesBoss()` (chefe ainda não pousou → o EnemyRenderer
> desenha num canvas descartado só pra MEDIR onde ele vai ficar) e
> `hidesHud()` (HUD do inimigo, painel do herói, mão e botões esperam).
> * `drawBack()` roda no espaço do MUNDO logo depois do salão + InteriorFX
> (escuridão, olhos, rasantes, vento, penas); `drawFront()` depois do chefe
> (poeira do pouso, corvos espantados, penas da morte); `drawUI()` no
> espaço da UI (cartão de nome, dica de pular).
> * `beginWorldPass()/endWorldPass()` embrulham o mundo num canvas quando a
> dessaturação da morte está ativa (shaders/desat.glsl).
> * `holdsEnd()` segura espólios/vitória enquanto a morte toca.
> * `overlay` é registrado no InputFocus (main.lua, PRIMEIRO da lista = menor
> prioridade: pausa e companhia continuam ganhando). Com ele visível o
> clique/tecla/A vêm pra cá (pular depois de SKIP_AFTER), o NavCursor não
> reclama o Enter (ownsNavigation) e o combate NÃO congela (exceção em
> main.lua: a cinemática é a única captora que deixa o relógio correr).
>
> Tempo: a sequência é uma LINHA DO TEMPO própria (dt acumulado), não uma fila
> do EventManager — pular é saltar pro estado final, e o teste roda sem
> EventManager. Efeitos com envelope (gust das luminárias, slowmo, desat)
> continuam vivos depois que o passo que os disparou passou.
>
> reducedMotion: usa `introReduced`/`deathReduced` do dado (mesma linguagem,
> sem varrer a tela); informação (nome do chefe) fica.

## L52 (em `BossCinematic`, junto a `BossCinematic.SKIP_AFTER = 1.0`)

> Depois de quanto tempo clique/A/Enter PULA (segundos).

## L55-56 (em `BossCinematic`, junto a `BossCinematic.INTRO_KINDS = { dark = true, eyes = true, flyby = true, land = true,`)

> Passos conhecidos por fase. Kind desconhecido AVISA e é pulado (fallback
> silencioso é proibido — CLAUDE.md §9).

## L107 (em `bossEclipseBreak`, junto a `bossEclipseOmen    = { "audio/sfx/boss/boss_eclipse_omen.mp3",    0.75 },`)

> rainha do eclipse v2 (frente rainha-eclipse, Out/2026)

## L114-115 (em `bossEclipseFade`, junto a `colossusAssemble   = { "audio/sfx/boss/colossus_assemble.mp3",     0.80 },`)

> colosso v2 (Out/2026): madeira rangendo + ossos se juntando, chão
> rachando, corpo desabando em pedaços

## L119 (em `colossusCrumble`, junto a `monarchStrike      = { "audio/sfx/boss/monarch_strike.mp3",        0.85 },`)

> monarca v2 (Out/2026): o cajado bate no gelo ainda em silhueta

## L121 (em `monarchStrike`, junto a `tyrantChainDrag    = { "audio/sfx/boss/tyrant_chain_drag.mp3",     0.70 },`)

> tirano v2 (Out/2026): correntes do salão arrastadas, esticando, arrebentando

## L128 (em `tyrantUnchained`, junto a `BossCinematic.SOUNDS = SOUNDS`)

> teste confere que todo arquivo existe

## L152-153 (em `sfxQueue`, junto a `local DEFAULT_PALETTE = {`)

> PALETA do chefe (cor da névoa, do brilho, do flash, das partículas) — vem
> de `palette` no dado; sem ela, a do rei-carniça (violeta/brasa).

## L165-168 (em `ownAnims`, junto a `local T3 = { bond = nil, triedFor = nil }   -- (ver seção TIRANO)`)

> TIRANO: correntes do salão presas ao chefe — fora de `fx`, vivem a luta
> inteira (bond) + inimigo pra quem ensureBond já tentou (triedFor). Numa
> TABELA, não em locais soltos: LuaJIT aceita 200 locais por função e este
> arquivo passou de 200 no escopo de arquivo (boot quebra na compilação).

## L170-171 (em `T3`, junto a `local eclipse = nil    -- { level, cur, dawn, t, gaze, lastPhase, active }`)

> RAINHA DO ECLIPSE v2 (seção própria mais abaixo): estado do eclipse que
> SOBREVIVE ao fim da entrada (luta + cash out) e o cartão da coroação

## L262-263 (em `BossCinematic.duration`, junto a `function BossCinematic.validate(id)`)

> Valida um roteiro: kinds conhecidos pra fase, dur numérico >= 0.
> Devolve lista de problemas (vazia = ok). Usada pelo teste e no start.

## L292-293 (em `clearFx`, junto a `local function finish()`)

> Estado final (tudo visível, nada pendente). Partículas em voo podem
> terminar sozinhas.

## L348-351 (em `flakes`, junto a `BossCinematic.GENERIC = {`)

> ENTRADA GENÉRICA — chefe SEM roteiro próprio (chefe novo que ainda não
> ganhou o dele). O salão abre VAZIO, um compasso de escuro, o chefe aparece
> no palco com impacto, cartão com o nome. Nunca mais "luta como antes" com
> a mão já na tela (bug do dono, Out/2026). Paleta neutra (pedra/âmbar).

## L372-373 (em `particle`, junto a `function BossCinematic.startIntro(game)`)

> ENTRADA. Chefe com roteiro usa o dele; chefe sem roteiro usa o GENÉRICO.
> Quem não é chefe não tem entrada (devolve false).

## L405-406 (em `BossCinematic.startIntro`, junto a `function BossCinematic.startDeath(game)`)

> MORTE. Chamada pelo update ao detectar `_deathHandled` do chefe no salão
> (ou direto por teste/ferramenta).

## L422-424 (em `BossCinematic.startDeath`, junto a `function BossCinematic.markDeathSeen(game)`)

> Continuar no cash out/espólios de um chefe: o inimigo é montado JÁ morto
> (`_deathHandled`) — a morte NÃO se reencena (retomar é retomar onde
> estava). Marca o inimigo como "morte já vista".

## L434-435 (em `BossCinematic.hidesHud`, junto a `function BossCinematic.hidesHand() return seq ~= nil end`)

> mão, botões, coringas e prévia somem em QUALQUER fase (na morte o HUD de
> vida/TopBar fica, mas não há o que jogar)

## L455-456 (em `BossCinematic._debug`, junto a `function BossCinematic.skip()`)

> PULAR: salta pro estado final. Antes de SKIP_AFTER é ignorado (evita o
> clique de aproximação da porta engolir a entrada).

## L467 (em `BossCinematic.skip`, junto a `function BossCinematic.setStage(st) stage = st end`)

> Posição/medidas do palco, vindas da cena a cada frame (espaço do mundo).

## L479 (em `EYE_HALO`, junto a `local function px()`)

> bloco = pixel da ARTE (escala do sprite ou do salão), nunca 1px de tela

## L575-586 (em `updateFx`, junto a `local BAYER4 = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }`)

> NÉVOA COLORIDA (revisão do dono: "algo nebuloso, com cor, mais drama").
> Puffs = texturas de névoa GERADAS (value noise + 3 degraus de alpha com
> dither Bayer 4×4, borda esfarelada — nada de retângulo, nada de gradiente
> liso), desenhadas na GRADE DA ARTE do salão (posição truncada em px da
> PNG, escala = cover-fit × tamanho do puff), em 3 camadas com paralaxe:
> duas atrás do chefe (fundas/rentes) e uma na frente, fina. Cada puff
> desenha o CORPO (alpha, violeta escuro) e um BRILHO aditivo (violeta ou
> brasa) — é esse brilho que "sangra" cor na pedra. A rajada do rasante
> empurra a névoa (InteriorFX.gustLevel × direção do voo). reducedMotion:
> névoa parada.

## L683-688 (em `updateMist`, junto a `local mistCanvas, posterShader, posterTried = nil, nil, false`)

> POSTERIZAÇÃO da névoa (revisão do lead, Out/2026): a soma de dezenas de
> puffs translúcidos dava um gradiente LISO ("forma vetorial suave" = cara
> de IA em pixel art). As camadas vão pra um canvas e voltam pela
> shaders/posterize.glsl: 4 degraus por canal + dither Bayer na grade da
> arte. Sem canvas/shader (headless, falha de compilação) desenha direto e
> AVISA uma vez.

## L759-760 (em `drawMistRaw`, junto a `local function glowBlob(cx, cy, w, h, color, a, idx)`)

> Blob de brilho (névoa aditiva) centrado em (cx, cy), largura w, altura h —
> substitui qualquer "retângulo de luz": a borda é a da textura esfarelada.

## L769-777 (em `glowBlob`, junto a `local RING_STYLES = {`)

> EFEITO DE TELA DO POUSO: flash na cor do chefe (3 degraus no tempo, sem
> gradiente), onda de choque em anel pontilhado (blocos na grade, dither
> Bayer no esvaecer), pulso de vinheta em bandas, solavanco no CRT e soco
> de zoom no MUNDO (1.0 → 1.06 → 1.0, translação inteira). reducedMotion:
> só o pulso de vinheta, suave.
>
> Cores dos dois anéis da onda de choque por ESTILO (`land.ring` no dado):
> sem estilo, a paleta do chefe (brasa + flash).

## L806-807 (em `BossCinematic.worldZoom`, junto a `local function ensureHeartVignette()`)

> vinheta do coração: alpha elíptico quantizado em 4 degraus com dither
> Bayer no limiar (borda esfarelada, sem aresta reta)

## L829-831 (em `drawScreenFx`, junto a `local w, h = love.graphics.getWidth(), love.graphics.getHeight()`)

> vinheta ELÍPTICA em 4 degraus com dither (textura gerada uma vez,
> nearest, esticada na tela): nada de moldura retangular (lia como
> borda de debug — revisão do lead)

## L890-896 (em `drawScreenFx`, junto a `local function ownAnim(clip, dur)`)

> OS OUTROS CHEFES — kinds por ELEMENTO. Todos desenham o chefe "fora do
> lugar" com um clip PRÓPRIO (ownAnim: clip PixelLab do chefe se instalado,
> senão o idle) e terminam exatamente onde o EnemyRenderer vai desenhá-lo
> (stage.foot, medido pelo passe no canvas descartado). Tudo na grade:
> blobs pontilhados, blocos, níveis em degraus.

## L953-956 (em `RUNE_GLYPHS`, junto a `local function drawRunes()`)

> Runas no chão em volta do palco: bloco = ~1.6 px da ARTE do salão (3×5
> blocos por glifo, legível a 1080p), halo em blob, e o círculo pontilhado
> que as liga fecha quando todas acenderam — e FICA aceso durante a subida
> (o passo seguinte é que o apaga, ver `land`).

## L1059-1065 (em `drawDescend`, junto a `local function enterSilhouette(st)`)

> SILHUETA v2 (monarca; dono: "poderia durar mais tempo, mais marcada"):
> vulto preto SÓLIDO com borda fria de 1 px da arte, que aparece LONGE e
> pequeno no branco (`far` × escala, na borda de trás do piso) e cresce
> andando (clip `clip` em loop, mesma geometria do walk_in) até o palco; em
> `strike` o cajado bate AINDA em silhueta (clip `strikeClip`: flash frio,
> onda de geada, tremor, lascas no pé) e só o `settle` deixa a neve
> assentar e a cor entrar. Nada de transparência que lave o vulto.

## L1167-1180 (em `drawFirewall`, junto a `local frame0Cache = {}`)

> COLOSSO PÚTRIDO v2 (Out/2026, veredito do dono: "do nada surgindo, não
> fez sentido"). O salão É ele: o coração acelera, raízes descem das
> PAREDES e do teto (bocas pintadas em InteriorFX.HALLS[5].rootMouths, em
> px da arte) até o palco e AGARRAM; ossos e entulho do chão são puxados e
> se juntam formando a silhueta DE BAIXO PRA CIMA (`assemble`: blocos do
> próprio quadro 0 do idle voando de pontos do piso até o lugar EXATO onde
> o EnemyRenderer vai desenhá-lo). As raízes se RETRAEM, ele ergue a
> cabeça (clip `roar` no `land`) e o chão racha em volta (`land.cracks`).
> Morte = o processo ao contrário (`crumble`): as raízes agarram, soltam, e
> o corpo desaba em pedaços com gravidade, vira monte e esporos, e o monte
> esvaece sobre o cadáver real. Tudo na grade do sprite (blocos de `block`
> px da arte), nada de gradiente.

## L1207-1208 (em `spriteFrame0`, junto a `local function spritePieces(id, B)`)

> Blocos B×B do quadro 0 com pixel: { qx, qy, w, h, quad, row } — `row` =
> 0 no topo do CORPO, 1 no pé (ordem de montagem/queda).

## L1239-1242 (em `pieces`, junto a `local function startRoots(st)`)

> Raízes: `from="walls"` nascem nas bocas pintadas do salão (InteriorFX.
> HALLS[hall].rootMouths) e vão AGARRAR o corpo (`grasp`: alvo dentro do
> bbox do palco, em px da arte); sem isso, do ponto (u,v) pra pontos do
> chão (v1). Retração por `retractT` (crescimento ao contrário, 0.7 s).

## L1278-1279 (em `fx.roots`, junto a `local pts = { { ox, oy } }`)

> caminho em SEGMENTOS de 12-20 px da arte com cotovelos (±25°),
> nó em cada junta e raminho curto em algumas: raiz, não vetor

## L1306-1310 (em `twigs`, junto a `local ROOT_A, ROOT_B, ROOT_EDGE = { 0.09, 0.14, 0.08 }, { 0.13, 0.20, 0.11 }, { 0.25, 0.39, 0.18 }`)

> Raízes rastejando: segmentos de 3 blocos com nós claros; crescem em
> `dur` e, quando `retractT` liga, encolhem de volta pra boca (0,7 s).
> cores das raízes: as do próprio castle_hall_5 (marrom-esverdeado escuro),
> tom de dither um degrau acima, aresta clara só do lado da luz (o centro do
> salão, onde o coração bate); o verde do elemento fica SÓ na ponta que agarra

## L1313-1314 (em `twigs`, junto a `local function rootBrush(tr, x, y, nx, ny, wcells, lightSide, tipK)`)

> um PINCEL de `wcells` células (px da arte) perpendicular ao caminho:
> dither em xadrez entre dois tons, aresta clara na célula do lado da luz

## L1340-1342 (em `col`, junto a `local function drawRoots()`)

> Raízes GROSSAS v3: largura 5 → 2 células da arte da boca à ponta (+1 nos
> nós), caminho com cotovelos, raminhos nas juntas, textura por dither, sem
> brilho aditivo. Crescem em `dur` e, com `retractT`, encolhem de volta.

## L1389-1392 (em `drawRoots`, junto a `local function enterAssemble(st)`)

> MONTAGEM (colosso): cada bloco do quadro 0 sai de um ponto do piso
> (px da arte, faixa do chão do salão) e voa até o seu lugar no sprite;
> pés primeiro, cabeça por último. Em voo é escuro como osso velho e ganha
> a cor ao encaixar; um brilho do elemento cresce atrás do corpo montado.

## L1458-1461 (em `drawAssemble`, junto a `local function startCracks(gx, gy, wdt)`)

> RACHADURAS no chão em volta do pé (land.cracks): 7 fendas em blocos
> escuros na grade, crescendo em 0,45 s (achatadas em y: chão visto de
> frente), ponta recém-aberta com um bloco de brilho. Ficam até o cartão e
> esmaecem com ele.

## L1501-1502 (em `drawCracks`, junto a `love.graphics.setColor(0.02, 0.03, 0.02, 0.95 * fade)`)

> fenda escura com a luz do coração vazando por baixo
> (chão do salão 5 é escuro: só o escuro não se lia)

## L1521-1525 (em `drawCracks`, junto a `local function enterCrumble(st)`)

> DESABAMENTO (morte do colosso): o chefe real some, o corpo em pé fica como
> blocos; as raízes das paredes agarram e, no `delay`, soltam — os blocos
> caem (cabeça primeiro) com gravidade, quicam uma vez, viram um monte na
> linha do chão e soltam esporos; ao fim o monte esvaece sobre o cadáver
> que o EnemyRenderer já desenha.

## L1614-1630 (em `drawCrumble`, junto a `T3.CHAIN_DARK, T3.CHAIN_LIT, T3.CHAIN_DIM = { 0.30, 0.28, 0.32 }, { 0.66, 0.62, 0.66 }, { 0.48, 0.46, 0.50 }`)

> TIRANO DO ABISMO v2 — CORRENTES DO SALÃO (Out/2026; dono: "as correntes
> saem do céu; poderiam se manter dentro da fase com esse boneco, ser parte
> de alguma mecânica ligando ele"). As correntes pertencem ao castle_hall_3
> E a ele: ancoradas nas argolas pintadas dos pilares e nas pontas dos
> chifres do portão-caveira (InteriorFX.HALLS[3].chainAnchors, px da arte)
> e presas aos PULSOS e ao PESCOÇO (`bonds` no dado: grip = fração do canvas
> do sprite). Na entrada ele chega ARRASTANDO as correntes (frouxas,
> balançando) e elas se ESTICAM com um tranco quando ele para no palco. Na
> luta, a cada limiar de vida (`breakAt`: 0.72 / 0.52 / 0.38 e o ENFURECIDO
> de 30%, estado que o jogo já tem) uma corrente ARREBENTA (faísca, som,
> tremor) e fica pendurada da argola, com o toco na algema; com todas
> rompidas ele está SOLTO (aura maior, brasas subindo do chão). Nada disso
> muda dano ou vida: é leitura. O estado (`T3.bond`) mora fora de `fx`:
> sobrevive ao fim da cinemática e nasce pronto no Continuar (T3.ensureBond:
> correntes já rompidas pela vida atual, sem faísca).

## L1670-1671 (em `T3.chainShouldBreak`, junto a `function T3.bondGrip(ch)`)

> ponto do punho/pescoço na tela: segue o walker da entrada; depois o
> EnemyRenderer (último quadro); antes de ele entrar, espera no fundo

## L1716 (em `T3.ensureBond`, junto a `if not (stage and stage.hall) then return end`)

> sem palco medido ainda: tenta no próximo quadro

## L1778-1779 (em `T3.updateBond`, junto a `function T3.drawChainLinks(x0, y0, x1, y1, sag, P, swayK, phase)`)

> elos ao longo de uma bezier quadrática (controle no meio, caído `sag`):
> elo = 2×3 blocos, claro/escuro alternando (1 bloco lia como fio)

## L1885-1887 (em `drawWhiteout`, junto a `local q = math.min(0.72, math.floor(level * 5) / 5)`)

> 5 degraus (sem gradiente), teto 0.8: o salão nunca some de todo — a
> nevasca é TEXTURA (rajadas de névoa correndo), não uma chapa branca
> (teto 0,72: a 0,82 as colunas do salão já não se liam a 1:1 — revisão do lead)

## L1891-1893 (em `drawWhiteout`, junto a `local imgs = ensureFog()`)

> RAJADAS: as texturas de névoa (3 degraus de alpha com dither) correndo
> da direita pra esquerda em duas camadas, azul-gelo sobre o branco e
> branco aditivo por cima — é o vento que se vê

## L1938-1943 (em `BossCinematic.heartFlash`, junto a `local function flyPos(f, k, w, h)`)

> GEOMETRIA DO RASANTE
>
> Canto superior esquerdo do sprite do rasante no parâmetro k (0..1).
> `land=true`: termina EXATAMENTE onde o EnemyRenderer vai desenhar o chefe
> (medido pelo passe no canvas descartado: stage.foot.drawX/drawY).

## L1978-1979 (em `ensureFlyAnim`, junto a `if SpriteAnimation.exists(id, "dive", "south") then`)

> clip de MERGULHO (PixelLab, tools/pixellab_boss_cine.py) quando existe;
> senão o idle com as asas batendo bem mais rápido

## L1989 (em `ensureFlyAnim`, junto a `local function bossClip(name, fps)`)

> clip one-shot do chefe JÁ no palco (pouso, rugido) — só se instalado

## L2000-2029 (em `bossClip`, junto a `local QUEEN_ID = "eclipse_queen"`)

> RAINHA DO ECLIPSE v2 (Out/2026, frente rainha-eclipse) — o chefe FINAL.
> Pedido do dono: "algo mais macabro, mais estiloso, entradas mais marcantes,
> música tipo Radagon/Besta Prístina". Três atos próprios na entrada:
> 1. PRESSENTIMENTO (`omen`): o salão muda antes de ela existir — a luz do
> vão morre em DEGRAUS (um tique por degrau, silêncio entre eles), o
> eclipse pintado vira uma ÍRIS que olha o jogador (pupila em fenda que
> acompanha), a coroa SANGRA (gotas magenta caem em blocos), pétalas
> pretas (cinzas) começam a cair, a névoa magenta sobe.
> 2. MANIFESTAÇÃO (`unveil` + `descend`): ela não entra, se REVELA — olhos
> demais acendem no escuro do vão (pares que não são dela), a silhueta
> aparece em casulo de asas (clip `unveil`) e se abre em contraluz, com a
> SOMBRA no mármore maior que ela e um halo QUEBRADO sobre a cabeça; o
> `descend` existente a traz ao palco.
> 3. COROAÇÃO (`coronation`): cartão ÚNICO — as letras chegam uma a uma com
> um tique de sino por letra (pitch subindo), halos quebrados ladeando,
> stinger coral na última letra, flash magenta, o eclipse pulsa.
> Durante a LUTA (sem seq) o módulo OBSERVA a fase do kit (`_phaseIdx`,
> dado em src/data/enemies.lua, nunca alterado aqui) e muda SÓ o visual:
> `InteriorFX.setEclipse(level, dawn)` fecha o vão do salão 6, a íris olha
> de vez em quando, o halo quebrado fica sobre a cabeça dela na 2ª fase, e a
> virada de fase tem um instante próprio (`phaseShift`). Na MORTE o `dawn`
> v2 abre o eclipse em degraus pelo vão, as pétalas viram CINZAS que sobem e
> a voz dela se apaga (`bossEclipseFade`); o estado de alvorada persiste no
> cash out/espólios (e no Continuar, via markDeathSeen).
> reducedMotion = roteiro curto com TODA a informação (dados em
> src/data/boss_cinematics.lua, introReduced/deathReduced).
>
> (`eclipse` e `crownCard` são declarados no bloco de ESTADO do topo: o
> finish()/_debug() ficam acima desta seção e precisam enxergá-los)

## L2059-2060 (em `eclipseCenter`, junto a `local function drawBrokenHalo(cx, cy, r, ry, P, col, a, t, seed)`)

> Halo QUEBRADO: anel pontilhado com falhas (hash estável por dente), gira
> devagar, e "sangra": alguns dentes escorrem pra baixo. Blocos na grade.

## L2083-2084 (em `drawBrokenHalo`, junto a `local function drawIris(cx, cy, r, P, open, t)`)

> A ÍRIS: pupila em fenda magenta dentro do disco negro, acompanha
> (deriva lenta + sacadas). `open` 0..1 = quanto a fenda está aberta.

## L2102-2103 (em `drawIris`, junto a `local function drawEclipseClosing(k, t, irisOpen)`)

> Disco do eclipse FECHANDO com coroa que sangra (omen/fase 2): `k` = quanto
> cobre (0 = só a pintura, 1 = disco cheio + coroa larga).

## L2121-2125 (em `drawEclipseClosing`, junto a `local function drawBigShadow(anim, bodyCx, floorY, s, a)`)

> Sombra MAIOR que ela no mármore: o eclipse atrás projeta a silhueta no
> chão em direção à câmera — o quadro atual espelhado a partir da linha do
> chão, 1,6× mais largo e ACHATADO (0,55×: cabe entre o pé e a borda da
> tela), corpo violeta escuro + cópia aditiva magenta (no salão a 0,8 de
> escuro só o aditivo se lê).

## L2142-2144 (em `drawBigShadow`, junto a `local STRAY_EYES = {`)

> Pares de olhos QUE NÃO SÃO DELA no escuro do vão (unveil): posição em
> fração da arte em volta da silhueta, cada par acende num instante e some
> quando ela se ilumina. Olho = 3×2 blocos magenta com fenda escura.

## L2153-2158 (em `STRAY_EYES`, junto a `local function spawnHallEyes(omenDur)`)

> OLHOS DEMAIS v2 (lead): 20-40 pares de 4-8 px EM VOLTA do salão (colunas,
> atrás das estátuas, teto), gerados no omen; cada par abre num instante
> próprio, TODOS viram pro jogador no mesmo instante (`turnAt`, pouco antes
> da manifestação — um acontecimento por instante) e fecham quando ela se
> revela. Olho = 2×1 blocos (B = pixel da arte) com pupila de 1 bloco.
> (`hallEyes` é declarado no bloco de ESTADO do topo, pro _debug/finish)

## L2181 (em `drawHallEyes`, junto a `local flash = (he.flash or 0) > 0`)

> brilho de UM quadro no instante em que todos viram (he.flash > 0)

## L2260-2261 (em `drawOmen`, junto a `local tr = stage.tr`)

> a luz do vão morre em DEGRAUS: faixa escura sobre o feixe pintado
> (x 160..240 da arte: as bordas caem na parede escura, nunca no branco)

## L2295-2296 (em `drawUnveil`, junto a `glowBlob(bodyCx, y + sh * 0.5, sw * 2.0, sh * 1.4, PAL.glow, 0.28 * appear, 1)`)

> brilho magenta atrás do casulo; CONTRALUZ = a silhueta deslocada em
> 4 direções em aditivo (borda de luz) e o corpo quase preto por cima

## L2305 (em `drawUnveil`, junto a `local halo = smooth(clamp01((k - 0.7) / 0.3))`)

> halo quebrado sobre a cabeça (chega no fim)

## L2355 (em `drawCrownCard`, junto a `local hr = c.size * 1.25`)

> halos quebrados ladeando o nome (giram em sentidos opostos)

## L2457 (em `fx.omen`, junto a `queueSfx(math.max(0.1, fx.omen.dur - 0.35), "bossBlinkClick", nil, 0.6)`)

> o instante em que TODOS os olhos viram pro jogador

## L2533-2534 (em `fx.phaseShift`, junto a `local function queenUpdate(dt, game, ctx)`)

> Observador da LUTA: fase do kit → visual do salão (só visual; o kit e os
> números são de src/data/enemies.lua e não se mexe neles aqui).

## L2654-2655 (em `queenDrawBack`, junto a `if crownCard and crownCard.flashT and stage.bbox then`)

> COROAÇÃO: no instante do nome o eclipse FLAREIA e o halo sobre a
> cabeça dela sangra (compensa o clip `crown` modesto com LUZ)

## L2674 (em `queenDrawFront`, junto a `if e.cur > 0.05 and e.dawn <= 0 and not bossHidden and landed then`)

> halo quebrado sobre a cabeça dela na 2ª fase (viva, no palco)

## L2754-2755 (em `darkEase`, junto a `if st.hit ~= false then startHit(gx, body, st.ring) end`)

> `hit=false`: o impacto de tela já aconteceu antes (monarca: o
> golpe do cajado ainda em silhueta)

## L2757-2758 (em `darkEase`, junto a `for _ = 1, (st.burst or 12) do`)

> lascas do impacto: pena (rei-carniça), lasca de gelo, brasa,
> esporo, pétala — `particle` do passo

## L2871-2872 (em `fx.fire`, junto a `T3.bond = (stage and stage.hall) and T3.makeBond(seq.bossId, nil, "drag") or nil`)

> as correntes do salão: ele entra ARRASTANDO (frouxas) e elas esticam no pouso
> (sem palco medido — ferramenta sem draw — o T3.ensureBond cria depois, já esticadas)

## L2939-2943 (em `exitStep`, junto a `function BossCinematic.update(dt, game, ctx)`)

> UPDATE
>
> ctx.inHall: a cena de combate É o salão do chefe (só aí a morte do chefe
> vira cinemática — o mini-boss também tem isBoss, mas luta na estrada).

## L2951-2952 (em `BossCinematic.update`, junto a `if game and game.enemy and game.enemy.isBoss and game._deathHandled`)

> MORTE do chefe no salão: detecta o acontecimento (Game._onEnemyDeath
> já encenou clip/som/shake; aqui entra a câmera lenta e o resto).

## L3068-3070 (em `BossCinematic.update`, junto a `if stage and stage.bbox and not reducedMotion() then`)

> a tempestade em volta do corpo que sobe: fagulhas do elemento
> (kind "ember" FLUTUA e usa PAL.ember — geada branca no lich) saindo
> da linha do chão, mais densas no começo da subida

## L3197-3200 (em `BossCinematic.desatAmount`, junto a `function BossCinematic.measure(drawFn)`)

> MEDIÇÃO: desenha o chefe num canvas descartado (nada chega à tela) e
> devolve o que a função devolver (o bbox do EnemyRenderer.draw).

## L3230-3231 (em `ensureDesatShader`, junto a `function BossCinematic.beginWorldPass()`)

> Chamado DENTRO do UiScale.outside (transform identidade da janela real).
> Devolve true quando o mundo está sendo capturado.

## L3259-3268 (em `BossCinematic.endWorldPass`, junto a `local EYE_ROWS = {`)

> DRAW — mundo (atrás do chefe)
>
> Olho = amêndoa de 8×5 blocos (pixel da arte do salão), pupila em fenda,
> halo aditivo. Abre do meio (fenda → cheio), pisca fechando as fileiras.
> OLHOS v3 (dono: "mais detalhe, aterrorizante"): amêndoa 12×7 com aro de
> brasa escura, íris laranja, núcleo claro; pupila em FENDA que ACOMPANHA
> (deriva lenta + sacadas), halo em blob pontilhado, calor subindo em
> blobs finos tremendo, rumor grave enquanto estão abertos (loop) e clique
> a cada piscada. Abrem DEVAGAR do meio (fenda → cheio).

## L3357-3359 (em `drawFly`, junto a `for i = 1, #tr, 2 do`)

> RASTRO: blobs de névoa aditiva (violeta, uma brasa de vez em quando)
> deixados ao longo do caminho — a trilha do voo é nebulosa, sem
> retângulo nem quadro visível (revisão do dono: "efeito de túnel")

## L3367-3368 (em `drawFly`, junto a `local lag = fly.near and 1 or 2`)

> fantasmas: cópias ATRÁS no tempo, claras (violeta de corvo em aditivo).
> Perto da câmera o atraso é de 1 quadro: o vulto fica "borrado".

## L3383-3384 (em `drawFly`, junto a `flyAnim:draw(x, y, s, { 1, 0.98, 1.04, 1 })`)

> o chefe em si, AUTO-ILUMINADO (não escurece com o salão) + brilho
> próprio aditivo (a silhueta, de novo, em violeta-branco fraco)

## L3400-3401 (em `drawFly`, junto a `local function drawEdge(w, h)`)

> WHOOSH DE BORDA: blobs de névoa empilhados na borda por onde o vulto
> entra (e, no fim, por onde sai) — a tela "sente" a passagem.

## L3415-3416 (em `drawEdge`, junto a `local function drawWind()`)

> RISCOS DE VELOCIDADE: linhas na grade da arte, claras, que esmaecem em
> 3 degraus (a ponta de trás some primeiro — lê como rastro, não régua)

## L3455-3456 (em `drawFeathers`, junto a `local q = 1 - clamp01(f.life / f.max)`)

> CINZA (rainha): pétala que vira cinza — 2×2 que esmaece de
> magenta pra cinza conforme vive, com um bloco mais claro

## L3526-3527 (em `drawCrows`, junto a `local function drawDawn(w, h)`)

> O eclipse ABRE (morte da rainha): luz morna crescendo na abertura do
> fundo, em blobs, com um feixe fraco descendo sobre o corpo.

## L3582-3585 (em `BossCinematic.drawBack`, junto a `local function drawLavaPool()`)

> Na frente do chefe: poeira do pouso, corvos espantados, penas da morte.
> Poça de lava engolindo o corpo (morte do tirano): blobs de brasa na
> linha do chão, crescendo com o tempo, núcleo mais claro tremendo —
> na FRENTE do corpo, pra cobrir a base dele.

## L3667 (em `BossCinematic.drawUI`, junto a `if BossCinematic.canSkip() then`)

> dica de pular: pequena, canto inferior direito, só depois de SKIP_AFTER

