---
name: code_notes/src/ui/BossAura.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/BossAura.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/BossAura.lua`

Origem: `src/ui/BossAura.lua` em `7dbdb60d` (18 de 48 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local AURAS = require("src.data.boss_auras")`)

> src/ui/BossAura.lua
> Aura ASSINATURA dos chefes (Out/2026): corvos, almas, fagulhas, neve,
> moscas, eclipse — o tema de cada chefe em volta dele. Dados em
> src/data/boss_auras.lua; chamado SÓ pelo EnemyRenderer e SÓ com
> enemy.isBoss.
>
> Regras:
> * PIXEL DA ARTE: tudo é desenhado em múltiplos inteiros do pixel do
> sprite na tela (`scale`) e alinhado à grade dele — partícula de 1px de
> tela ao lado de um chefe de pixel 2.6x lê como outro dialeto.
> * PROFUNDIDADE: drawBack antes do sprite, drawFront depois. Órbita usa o
> seno do ângulo (metade de baixo = mais perto = na frente).
> * reducedMotion tira MOVIMENTO (órbita congela, emissor para, coroa e
> círculo não giram) e mantém INFORMAÇÃO (brilhos, círculo, coroa).
> * Chefe sem entrada nos dados AVISA uma vez (sem fallback mudo).
> * Barato: só retângulos + um sprite de brilho 16x16 posterizado.

## L45-46 (em `BossAura.get`, junto a `local function getGlow()`)

> Brilho posterizado (4 degraus), filtro nearest: luz em pixel art é
> anel, não degradê liso — mesma linguagem do light_dither.

## L83-84 (em `s`, junto a `local function edges(id)`)

> Borda externa da silhueta por linha (quadro 0 do idle), pro brilho que
> corre pelas asas. Pixels da arte.

## L117-123 (em `state`, junto a `local function pickTarget(w, f, iw, ih)`)

> ENXAME (moscas): cada mosca é um agente que persegue um alvo sorteado em
> volta do corpo e troca de alvo em intervalos irregulares. Aceleração
> limitada + amortecimento = trajeto ERRÁTICO mas CONTÍNUO (zigue-zague que
> faz curva), velocidade própria por mosca. A órbita em elipse de antes era
> um carrossel — "não natural" (dono, Out/2026). Posições em px da arte.

## L167-170 (em `f`, junto a `function BossAura.update(dt, id, dying)`)

> UPDATE: emissores + vida das partículas. `id` = chefe na tela (ou nil).
> dying = clip de death tocando: para de emitir e esvai em 0.6s.

## L209-211 (em `BossAura.update`, junto a `s.acc[i] = (s.acc[i] or (-math.log(1 - love.math.random()) / (em.rate or 1))) - dt`)

> chegada de POISSON: intervalo exponencial entre partículas.
> O acumulador antigo soltava uma a cada 1/rate segundos
> exatos — cadência de esteira (revisão do dono, Out/2026).

## L262-263 (em `BossAura.update`, junto a `p.st = p.st + dt`)

> gota: FORMA pendurada no ponto (cresce e estica), SOLTA
> e cai com gravidade, ESPIRRA uma vez no chão e some

## L301-304 (em `BossAura.update`, junto a `local KX, KY, K = 0, 0, 1`)

> BLOCO: a partícula/corpo corrente desenha com pixels de K x K pixels da
> arte, ampliada em torno da âncora (KX, KY). Um chefe a 2x na tela tem
> pixel da arte de ~2px — corvo de 7 pixels da arte virava cisco. K=2 dobra
> o desenho e continua na grade da arte (múltiplo inteiro, mesmo dialeto).

## L353-357 (em `drawGlows`, junto a `local function parseShape(rows)`)

> Corvo: silhueta de pássaro de FRENTE (o "m" clássico de pássaro ao
> longe), 9x5 pixels da arte, 3 quadros de batida. CORPO de 3 pixels no
> meio e asa de 2 pixels de espessura — a versão anterior tinha asa de 1
> pixel com ponta clara e lia como risquinhos soltos (revisão Out/2026).
> '#' = pena escura, 'o' = único pixel de brilho (dorso).

## L409-412 (em `orbitOne`, junto a `local h1, h2, h3 = 0.5, 0.5, 0`)

> cada corpo com raio, velocidade, fase e oscilação PRÓPRIOS (hash
> do índice: estável entre quadros). Espaçamento igual + velocidade
> igual = carrossel; o dono lê como mecânico. `o.regular = true`
> mantém a geometria exata (runas: são feitiço, não bicho).

## L494-495 (em `orbitOne`, junto a `local wing = (floor(s.t * 30 + i) % 2 == 0) and -1 or 1`)

> asinhas claras piscando: sem elas a mosca preta some
> em cima do corpo escuro do colosso

## L549-550 (em `drawParticles`, junto a `local dir = (math.sin(p.ph + (p.max - p.life) * 3) > 0) and 1 or -1`)

> pena: 3 pixels em DIAGONAL que tomba de "/" pra "\" conforme
> balança; risco horizontal/vertical lia como pixel solto

## L558-559 (em `drawParticles`, junto a `local f = floor(p.ph + (p.max - p.life) * 2.5) % 4`)

> pétala: gota 2x2 com um pixel claro que gira em volta — o
> traço de 3 pixels de antes lia como risco, não como pétala

## L596 (em `drawParticles`, junto a `local base, hi = em.color, em.color2 or em.color`)

> cor FOSCA da gosma (sem pop saturado), brilho só na ponta

## L664-665 (em `drawFloor`, junto a `local function drawCorona(r, spec, s)`)

> Eclipse: coroa de raios que gira atrás da cabeça (+ disco escuro e anel,
> a menos que `disc = false`).

## L674-676 (em `drawCorona`, junto a `local rot = still and 0 or t * c.speed`)

> raios: 24 setores, comprimento oscilando, girando devagar. Mistura
> NORMAL, não aditiva: a sala 6 é um feixe de luz BRANCA — luz somada
> em branco some; cor pintada por cima lê.

## L691-693 (em `drawCorona`, junto a `if c.disc == false then return end`)

> Sem disco nem anel (`disc = false`): a sala 6 já tem o eclipse
> pintado na abertura do fundo; dois eclipses empilhados liam como
> cópia. Fica só a coroa de raios em volta da cabeça.

## L701-702 (em `drawCorona`, junto a `love.graphics.setColor(c.dark[1], c.dark[2], c.dark[3], fade)`)

> disco (lua cobrindo o sol): uma linha por pixel da arte, OPACA —
> linhas translúcidas se sobrepõem no arredondamento e listram o disco

