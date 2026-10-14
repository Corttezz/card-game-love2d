---
name: code_notes/tools/shot_boss_cinematic.lua
description: Comentários com decisão/regra/histórico colhidos de tools/shot_boss_cinematic.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/shot_boss_cinematic.lua`

Origem: `tools/shot_boss_cinematic.lua` em `7dbdb60d` (10 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local M = {}`)

> tools/shot_boss_cinematic.lua
> PROVA VISUAL da cinemática do chefe (src/ui/BossCinematic) pelo caminho
> REAL da cena: GameplayScene.update/draw com o salão do ato 1, o rei-carniça
> e a sequência de entrada + morte tocando, quadro a quadro, num canvas
> falsificado (nada precisa aparecer na janela — roda com CARDGAME_HEADLESS=1).
>
> love . test_one shot_boss_cinematic [intro|death|both|arrival|phases]
> phases = a LUTA por fases do chefe (rainha do eclipse): fase 1, íris
> olhando, virada pelo funil real de dano, eclipse fechado + halo
> (pelo test_one: não há entrada própria no dispatcher do main.lua —
> `love . shot_boss_cinematic` abre o JOGO normal e fica esperando)
> arrival = o caminho REAL do andar do chefe: a cena caminha até o
> castelo, a PORTA abre, a entrada toca e as cartas são DADAS (HandDeal)
> — grava da porta ao fim da distribuição (prova do bug "mão/HUD no
> meio da cutscene")
> BOSS_CINE_ACT=3            ato/chefe (default 1 = rei-carniça)
> BOSS_CINE_SIZE=1920x1080   tamanho do canvas (default 1920x1080)
> BOSS_CINE_FPS=15           quadros gravados por segundo simulado
> BOSS_CINE_REDUCED=1        versão reducedMotion
> BOSS_CINE_LOCALE=de        idioma do cartão de nome
> BOSS_CINE_SKIP=2.0         pula a entrada em t=2.0s (prova do pular)
>
> Saída: boss_cine_<fase>_NNN.png no save dir (impresso no fim) + um
> boss_cine_<fase>_timeline.txt com o instante de cada quadro. A prancha e o
> GIF saem de tools/boss_cinematic_sheet.py.

## L61-64 (em `love.graphics.getDimensions`, junto a `local DT = 1 / 30`)

> relógio SIMULADO: bob, flicker e DynaText leem love.timer.getTime —
> quadros reproduzíveis independem da velocidade da máquina. DENTRO de um
> quadro o relógio ainda anda em tempo real: laços com orçamento de tempo
> (prewarm do WorldRoad) travariam pra sempre com um relógio parado.

## L195-197 (em `lines`, junto a `log("arrival: ancora o andar")`)

> caminho REAL: andar 7 → 8 dispara a caminhada; a câmera chega, a
> porta abre (WorldRoad.enterCastle), a entrada toca e as cartas
> são dadas. A caminhada (6.5 s) não é gravada; da porta em diante é.

## L223-226 (em `lines`, junto a `GameplayScene._debugForceBossEntered()`)

> LUTA por fases (rainha do eclipse, ato 6): salão direto, luta
> QUIETA (fase 1), a íris olhando, a VIRADA de fase pelo funil real
> de dano (Enemy:_checkPhase marca, BossCinematic observa) e o
> eclipse fechado — boss_cine_phases_NNN.png + timeline.

## L268-270 (em `run`, junto a `GameplayScene._debugStartBossIntro()`)

> LUTA do tirano (ato 3): correntes do salão inteiras, arrebentando
> nos limiares de vida (0.72 / 0.52 / 0.38) e SOLTO no ENFURECIDO —
> boss_cine_fight_NNN.png + timeline. Entrada tocada inteira antes.

## L275 (em `run`, junto a `love.graphics.setCanvas(vcanvas); GameplayScene.draw(); love.graphics.setCanvas()`)

> desenha (sem gravar): o palco medido é o que ancora as correntes

## L325-326 (em `shot`, junto a `for _ = 1, 20 do step() end`)

> 1 turno de respiro pra HUD/mão assentarem, depois o golpe fatal pelo
> pipeline (marcação _pendingDeath → beat enemy.death → _onEnemyDeath)

## L335-336 (em `shot`, junto a `love.graphics.setCanvas(vcanvas)`)

> o fundo do cash out/espólios do chefe: só o mundo = o SALÃO com o
> cadáver (GameplayScene.worldOnlyMode == "hall"), nunca a estrada

## L344-346 (em `shot`, junto a `local UiScale = require("src.ui.UiScale")`)

> as DUAS telas pós-chefe DENTRO do salão, como o main.lua as desenha
> (roundEval: GameplayScene.draw + painel; cardReward: drawWorldOnly +
> espólios), com a TopBar por cima — boss_cine_{cashout,rewards}_hall.png

## L363-364 (em `shotUI`, junto a `local guardRE = 0`)

> captura com a CONTAGEM FECHADA (linha a linha + voo das moedas):
> a linha do tempo roda na fila do EventManager, que o step() tica

