---
name: code_notes/tools/screenshot_enemy_scene.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_enemy_scene.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_enemy_scene.lua`

Origem: `tools/screenshot_enemy_scene.lua` em `7dbdb60d` (14 de 18 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local M = {}`)

> tools/screenshot_enemy_scene.lua
> Captura o CENÁRIO DE COMBATE real (GameplayScene.draw) pra um node
> específico: prova em que cena cada tipo de encontro acontece e onde o pé
> do inimigo pousa.
>
> love . screenshot_enemy_scene <ato>_<nodeType>
> love . screenshot_enemy_scene 2_elite      → elite do ato 2 (estrada)
> love . screenshot_enemy_scene 2_boss       → chefe do ato 2 (hall)
> love . screenshot_enemy_scene 1_boss
> love . screenshot_enemy_scene 6_battle     → dusk_shade (flutuante)
>
> ENEMY_SCENE_ID=<id> força o sprite (vale pra arte nova fora do roster).
> ENEMY_SCENE_INTENT="kind=multi,perHit=5,hits=3" força o intent do HUD.
> Sufixo "_hud" desenha a cena SEM o HUD/mão (default inclui tudo, que é o
> que o jogador vê). Saída: enemy_scene_<modo>.png no save dir.
>
> Por que existe: `screenshot_worldroad interior` só sabia desenhar o hall
> com um inimigo colado no meio da tela — não passava pelo `GameplayScene`
> e por isso não provava NADA sobre qual cena o jogo escolhe. Este tool
> roda o caminho real.

## L29-31 (em `M.run`, junto a `local vw, vh = (os.getenv("ENEMY_SCENE_VIRTUAL") or ""):match("^(%d+)x(%d+)$")`)

> ENEMY_SCENE_VIRTUAL=2560x1440: tela FALSIFICADA maior que o monitor
> (setMode acima do desktop trava — mesmo truque do boss_rooms). Desenha
> num canvas desse tamanho com getWidth/getHeight mentindo.

## L59 (em `love.graphics.getDimensions`, junto a `local run = game.runManager.currentRun`)

> Força o node/ato pedidos (o mapa normalmente decide isto).

## L72-76 (em `run.currentNode`, junto a `do`)

> KIT DO INIMIGO (Out/2026): monta o inimigo pelo roster (kit + stats do
> ato) e, com ENEMY_SCENE_MOVE=<id do golpe>, anuncia aquele golpe — é o
> que prova na tela o intent novo (multi-golpe, debuff, perfurante...).
> ENEMY_SCENE_DEBUFFS=weak,frail,poison põe debuffs no jogador (pills).
> ENEMY_SCENE_HOVER=1 posiciona o mouse no intent (tooltip do golpe).

## L93-99 (em `run.currentNode`, junto a `local vis = os.getenv("ENEMY_SCENE_VISIBILITY")`)

> ENEMY_SCENE_VISIBILITY=full|type_only|hidden[:veil]: NÉVOA DE
> INTENÇÃO (src/systems/IntentVisibility). Dá ao inimigo o contexto
> do bioma (como RunModifiers.decorateEnemy faria) e força o nível —
> a captura prova o box com "?", o véu correndo e a nevasca
> engrossando pelo hook do WeatherEngine (o loop de update abaixo
> deixa o clima perseguir o alvo). ":veil" marca a causa como véu
> da criatura (tooltip cita o nome dela).

## L124-125 (em `run.currentNode`, junto a `if nodeType == "boss" then GameplayScene._debugForceBossEntered() end`)

> BOSS: o jogo só mostra o interior DEPOIS da cutscene da porta. O tool
> pula a cerimônia (é o estado de combate que interessa aqui).

## L151-152 (em `EnemyHud.layout`, junto a `local intentSpec = os.getenv("ENEMY_SCENE_INTENT")`)

> ENEMY_SCENE_INTENT="kind=multi,perHit=5,hits=3,pierce=1,debuff=frail":
> força o intent mostrado no HUD (validação dos ícones de intent).

## L172-173 (em `it`, junto a `local pdeb = os.getenv("ENEMY_SCENE_PLAYER_DEBUFFS")`)

> ENEMY_SCENE_PLAYER_DEBUFFS="weak,frail,vulnerable": debuffs no jogador
> (pills do HUD dele) — validação dos ícones de status do lado do herói.

## L179-180 (em `it`, junto a `if os.getenv("ENEMY_SCENE_WORLD_ONLY") == "1" then`)

> ENEMY_SCENE_WORLD_ONLY=1: só mundo + inimigo, sem HUD (arte de loja).
> ENEMY_SCENE_TOD=0..1: hora do dia (0 = dia, 1 = anoitecer).

## L191-192 (em `it`, junto a `if os.getenv("ENEMY_SCENE_CLEAN") == "1" and game.messageSystem then`)

> ENEMY_SCENE_CLEAN=1: sem os toasts de início de run ("Jogo
> iniciado!", ouro inicial) — quadro limpo pra screenshot de loja.

## L201 (em `game.selectedCards`, junto a `require("src.ui.DamagePreviewPanel").update(game, nil, 1)`)

> a prévia só existe depois do update dela (o jogo roda isto todo quadro)

## L207-209 (em `game.selectedCards`, junto a `if os.getenv("TUT_TIP") then`)

> TUT_TIP=<conversa>[:<fala>]: o narrador do tutorial por cima (as
> âncoras acabaram de ser reportadas por este draw). TUT_LOCALE troca o
> idioma.

## L218-219 (em `game.selectedCards`, junto a `if os.getenv("ENEMY_SCENE_HOVER") == "1" then`)

> Tooltip do golpe: 2ª passada com o mouse em cima do intent (a 1ª
> passada calcula o layout real do cluster).

## L228-229 (em `love.mouse.getPosition`, junto a `local ST = require("src.ui.StatusTooltip")`)

> o tooltip é desenhado pelo main.lua no fim do frame
> (relógio adiantado: o pop-in do tooltip já assentou)

