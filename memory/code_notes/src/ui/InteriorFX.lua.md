---
name: code_notes/src/ui/InteriorFX.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/InteriorFX.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/InteriorFX.lua`

Origem: `src/ui/InteriorFX.lua` em `7dbdb60d` (30 de 60 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local SceneBackground = require("src.ui.SceneBackground")`)

> src/ui/InteriorFX.lua
> Atmosfera dos salões de chefe (castle_hall_1..6) — o CLÍMAX de cada ato.
>
> v2 (Out/2026, dono: "remove todas essas bolas de luz das salas de chefe").
> A v1 desenhava DISCOS translúcidos chapados em posições RELATIVAS À TELA:
> calibradas no corte 4:3, em 16:9 caíam fora das chamas (no hall 2 o disco
> pousava na parede escura ao lado do candelabro; no 4 ficava ao lado do
> braseiro). E o update rodava com `math.min(3, ato)` enquanto o draw usava
> o salão real: nos atos 4-6 as brasas nasciam nas posições da LAVA do
> hall 3 — as "veias esquisitas" saindo do nada.
>
> Regras da v2:
> * TUDO em coordenadas da ARTE (pixels da PNG 400×256), convertido pelo
> MESMO cover-fit do SceneBackground. Âncora vem do que está pintado e
> acompanha a pintura em qualquer aspecto de janela.
> * Nenhum disco. A luz da chama é a PRÓPRIA chama pintada redesenhada em
> modo aditivo com flicker (quad da arte): o brilho tem o formato exato
> do fogo e nunca vira bola.
> * Partícula = 1 pixel DA ARTE (posição truncada na grade da PNG, lado =
> escala do cover-fit). Lê como parte da pintura, não como overlay.
> * Profundidade: `draw` vem logo depois do fundo (névoa no chão, poeira
> ao fundo — ATRÁS do chefe); `drawFront` vem depois do chefe (neve,
> cinza e esporos mais próximos passam NA FRENTE dele).
> * Salão e partículas usam o mesmo índice: `InteriorFX.hallFor(ato)` é a
> fonte única (draw e update do GameplayScene perguntam aqui).

## L32-52 (em `InteriorFX`, junto a `local HALLS = {`)

> DADOS POR SALÃO (coordenadas em pixels da PNG 400×256)
> flames   {x, y, w, h}  retângulo da chama PINTADA (medido por cluster de
> luma na arte). O flicker redesenha esse pedaço em aditivo e as
> brasas nascem no topo dele.
> pulses   {x, y, w, h, speed, amp, th=, beat=}  luz grande pintada que
> RESPIRA devagar (vão iluminado, cascata de lava, feixe do
> eclipse). th = luma mínima que acende (default PULSE_LUMA);
> beat = pulso duplo de coração em vez de seno.
> ember    cor das brasas (nil = salão sem brasa)
> ambient  partículas de clima: style dust|ash|snow|spores|motes, rate
> (por segundo), color, region {x, y, w, h} de nascimento
> fog      névoa rente ao chão: y (topo da faixa), h, color, alpha
> vignette força do escurecimento das bordas (0..1)
> anim     movimento pintado no lugar (ver HallAnim): flameFrames, flows,
> shimmer
> smoke    {x, y} pontas de chama de onde sobe fumaça
> bubbles  {x, y, w, h} poças de lava que borbulham
> fireflies {n, region, color} vaga-lumes errantes (ciclo de piscar)
> emberRate brasas por chama por segundo (default 3)

## L54-55 (em `HALLS`, junto a `[1] = {`)

> ATO 1 — salão do rei-carniça: seis arandelas nas colunas e o vão
> âmbar atrás do trono (contraste pro corvo escuro).

## L94-95 (em `fog`, junto a `anim = {`)

> movimento pintado no lugar (HallAnim): chamas com quadros, lava
> descendo nas três cascatas, ar tremendo sobre os rios de lava

## L105-107 (em `bubbles`, junto a `chainAnchors = { pillarL = { 56, 92 }, pillarR = { 344, 92 },`)

> ÂNCORAS das correntes do tirano (BossCinematic `bonds`): as argolas
> pintadas nos pilares com caveiras e as pontas dos chifres do
> portão-caveira (px da arte). As correntes são do salão, não do céu.

## L121-122 (em `fog`, junto a `[5] = {`)

> ATO 5 — coração pútrido: fogos-fátuos verdes entre as raízes e o
> coração de raízes pairando no fundo do túnel, acima da cabeça do chefe.

## L128-129 (em `pulses`, junto a `flameGlow = 0.28,`)

> chamas repintadas em degraus verde -> amarelo; luz aditiva fraca
> (a 0.75 o núcleo estourava em branco) e quadros como no hall 3

## L136-138 (em `flamePalette`, junto a `ember = { 0.55, 0.85, 0.42 }, emberRate = 0.6,`)

> round 2 (dono: "partículas não naturais"): poucas, lentas, com
> profundidade; vaga-lumes com caminho errante e ciclo de piscar;
> névoa lenta. Nada de ponto saturado estourando.

## L145-147 (em `fog`, junto a `rootMouths = { { 160, 2 }, { 240, 2 }, { 100, 62 }, { 300, 62 },`)

> BOCAS das raízes da entrada do colosso (BossCinematic `roots
> from="walls"`): de onde elas descem — as gotejantes do teto do
> túnel e a face interna das duas árvores-parede (px da arte).

## L151-152 (em `rootMouths`, junto a `[6] = {`)

> ATO 6 — corte do eclipse: sem fogo pintado (a luz é o vão do fundo);
> poeira só DENTRO do feixe.

## L172-176 (em `particles`, junto a `InteriorFX.fogHook = nil`)

> NÉVOA DE INTENÇÃO no salão (Out/2026, frente "intenção oculta"): o HUD
> esconde o intent com "?" e o mundo tem que MOSTRAR o porquê — mesmo
> contrato do WeatherEngine.fogHook. `fogHook` (função 0..1) é instalada
> por src/systems/IntentVisibility; `veilCur` persegue o alvo a 4/s e
> engrossa a névoa do chão + uma camada na FRENTE do chefe (drawFront).

## L179-184 (em `particles`, junto a `local eclipseLvl, eclipseDawn = 0, 0`)

> ECLIPSE DA RAINHA (Out/2026, frente rainha-eclipse; só o salão 6):
> `level` 0..1 = o eclipse FECHOU (2ª fase do kit: a luz do vão morre em
> degraus, o chão/névoa viram violeta, as poeiras do feixe ficam magenta);
> `dawn` 0..1 = ALVORADA (rainha morta: o vão e o mármore acendem em luz
> morna). Quem decide é BossCinematic (observa a fase do kit); aqui só se
> desenha. Em coordenadas da ARTE, como tudo neste módulo.

## L187-188 (em `particles`, junto a `local fogImg, vignetteImg`)

> Recursos gerados uma vez (ImageData → Image, nearest): textura de névoa
> pontilhada e vinheta pontilhada, ambas na resolução da arte.

## L227-228 (em `buildFog`, junto a `local lvl = math.max(0, math.min(3, math.floor(dens * 4)))`)

> posterizado em 3 níveis (manchas de pixel art, não gradiente
> liso nem tela pontilhada)

## L248-249 (em `buildVignette`, junto a `data:setPixel(x, y, 1, 1, 1, math.floor(d * 8 + 0.5) / 8)`)

> degraus de 1/8 na grade da arte (pontilhado aqui virava
> "tela de mosquiteiro" por cima da pintura)

## L257-260 (em `buildVignette`, junto a `local FLAME_LUMA, PULSE_LUMA = 0.50, 0.32`)

> Máscara EMISSIVA do salão: só os pixels claros de dentro dos retângulos
> de chama/pulso, com alpha pela luma. Desenhada em aditivo, ilumina o fogo
> PINTADO e nada em volta — redesenhar o retângulo cru clareava o fundo
> escuro junto e aparecia uma caixa em volta do braseiro.

## L309-310 (em `quadFor`, junto a `local hallMemo = {}`)

> Salão que o ato usa — fonte ÚNICA pra draw e update. Ato sem PNG cai no
> salão 3 e AVISA (fallback silencioso é proibido).

## L425-427 (em `spawnEmber`, junto a `local function enterHall(hall)`)

> Troca de salão: zera e PRÉ-AQUECE o clima, senão a sala abre vazia e a
> neve/cinza leva ~20s pra cobrir a tela (e partículas do salão anterior,
> com a cor dele, ficariam no novo).

## L449-450 (em `step`, junto a `do`)

> névoa de intenção: persegue o alvo do hook a 4/s (mesma cadência do
> WeatherEngine); sem hook, zero

## L493-494 (em `step`, junto a `p.vx = math.cos(time * p.freq + p.phase) * p.amp * p.freq * 2`)

> deriva senoidal própria (velocidade, não aceleração: sem
> acumular e sem todos balançando juntos)

## L578-579 (em `drawParticles`, junto a `love.graphics.setColor(c[1], c[2], c[3], al * 0.35)`)

> esporo próximo: halo em cruz mais fraco (bloco 2x2 lia
> como "pixel quadrado" e não como poeira viva)

## L604-609 (em `c`, junto a `function InteriorFX.pulseBoost(k, dur)`)

> RAJADA (BossCinematic): o chefe passando em rasante faz as chamas
> pintadas BAIXAREM e tremerem — envelope rápido na subida, decaimento até
> `dur`. Só mexe no brilho aditivo das chamas (a pintura fica). O estado
> (`gust`) mora no topo do arquivo: `step` tica o relógio dele.
> PULSO ACELERADO (BossCinematic, colosso): os `pulses` do salão batem mais
> rápido e mais forte por `dur` s (o coração de raízes do hall 5).

## L635-636 (em `InteriorFX.eclipseState`, junto a `local function eclipseFogColor(fc)`)

> O que o eclipse faz com a cor da névoa do chão do salão 6: violeta no
> fechamento, morna na alvorada (fonte única pra draw e drawFront).

## L648-652 (em `eclipseFogColor`, junto a `local function drawEclipseOnHall(hall, img, tr)`)

> Fechamento/alvorada sobre a PINTURA do salão 6: a luz do vão morre em 4
> DEGRAUS (faixa escura sobre o feixe, x 160..240 da arte — as bordas caem
> na parede escura, nunca no branco — e sobre o reflexo no mármore); na
> alvorada o feixe pintado e o reflexo são redesenhados em aditivo morno
> (a própria arte, não um disco).

## L680-681 (em `flicker`, junto a `local g = InteriorFX.gustLevel()`)

> rajada: a chama FLAREIA (sobe até +85%) e treme forte enquanto o
> chefe passa, depois assenta

## L689-691 (em `flicker`, junto a `function InteriorFX.draw(hall)`)

> Fundo do salão: luz respirando nas chamas/vãos PINTADOS, névoa no chão,
> vinheta e partículas de trás. Chamado logo após o SceneBackground (antes
> do chefe).

## L702-703 (em `InteriorFX.draw`, junto a `local img = hallImage(hall)`)

> 0) movimento pintado no lugar (chamas com quadros, lava descendo, calor)
> 1) a própria arte, aditiva, nas fontes de luz (formato exato do fogo)

## L759-762 (em `InteriorFX.draw`, junto a `function InteriorFX.drawFront(hall, clipTop)`)

> Clima que passa NA FRENTE do chefe (neve/cinza/esporos próximos).
> Chamado logo depois do EnemyRenderer.draw no salão — e isso é DEPOIS da
> TopBar, então recorta na janela da cena (abaixo de `clipTop`): sem o
> recorte a neve pintava pontos brancos por cima da barra superior.

## L772-775 (em `InteriorFX.drawFront`, junto a `if veilCur > 0.01 and fogImg then`)

> NÉVOA DE INTENÇÃO na frente do chefe: uma 3ª camada da névoa do
> chão, mais alta (do piso até o meio do corpo), na cor do `fog` do
> salão, com alpha 0.35 × véu — lê "névoa ENTRE mim e ele", não "chão
> enevoado". reducedMotion: parada, nunca ausente.

## L794-795 (em `InteriorFX.drawFront`, junto a `function InteriorFX.renderedFog()`)

> Véu de névoa de intenção efetivamente desenhado (0..1), pra trava do
> test_intent_visibility (limiar IntentVisibility.FOG_THRESHOLD).

