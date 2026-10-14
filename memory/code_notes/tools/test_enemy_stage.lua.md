---
name: code_notes/tools/test_enemy_stage.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemy_stage.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemy_stage.lua`

Origem: `tools/test_enemy_stage.lua` em `7dbdb60d` (12 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemy_stage.lua
> Regressões do PALCO da batalha (pedidos do dono, Out/2026):
>
> 1. "quando ele fica o corpo inteiro pra fora, ainda fica meio que
> flutuando alguns milímetros do chão" — todo inimigo APOIADO, em TODO
> quadro da idle, tem o pé entre 0 e 3px DENTRO do chão (gap ∈ [-3, 0];
> gap = linha do chão − base do pé). Quem flutua por design continua no
> ar. A margem do pé é medida AQUI, de forma independente do renderer.
> 2. "os inimigos param muito na frente da tela; a carta em hover e a
> descrição ficam à frente do inimigo" — na estrada, inimigo + HUD não
> encostam na carta levantada NEM no tooltip dela, em 1024x768, 1280x720
> e 1920x1080 (janela falsificada; caminho REAL da cena com mouse falso).
> No salão do chefe o recuo é limitado pela borda do piso: cobra-se que
> ele recue sem sair da laje e continue MAIOR que o inimigo comum.
>
> love . test_one test_enemy_stage

## L22-24 (em `M`, junto a `local SIZES = { { 1024, 768 }, { 1280, 720 }, { 1920, 1080 },`)

> { W, H, escalada? } — as escaladas rodam com a ESCALA DE UI ligada
> (src/ui/UiScale): mão/HUD crescem k vezes, o mundo não. A régua é a mesma,
> tudo convertido pra pixels da tela (Out/2026, a mão cresceu em 1440p/4K).

## L40-44 (em `files`, junto a `local function groundRow(data)`)

> REGRA DO APOIO (Out/2026, "os ratos parecem flutuar"), reimplementada
> AQUI de forma independente do renderer: o chão é a linha mais baixa
> com >= M pixels "sólidos" (coluna opaca contínua de >= 5px terminando
> ali). Ponta de rabo/lâmina/farrapo fina não conta. Override
> `groundRow` da pose desloca todos os quadros pela diferença do 1º.

## L119-121 (em `M.run`, junto a `local ids = {}`)

> ===================================================================
> 1. PÉ NO CHÃO — todo inimigo, todo quadro da idle
> ===================================================================

## L152-153 (em `ids`, junto a `local before = (pads[i] - pads[1]) * lf.scale + 1`)

> antes (Set/2026): margem só do 1º quadro, truncada, e o
> respiro {-1,0} — o pior quadro descolava isto:

## L185-187 (em `ids`, junto a `local TopBar = require("components.TopBar")`)

> ===================================================================
> 2. DISTÂNCIA DE PARADA — caminho real da cena, 3 tamanhos
> ===================================================================

## L229-231 (em `run.currentNode`, junto a `EnemyRenderer.resetRun()`)

> estado de animação do inimigo (quicada de chegada, golpe, morte)
> vem limpo: herdado de outra suíte do test_all ele mudava a altura
> medida em alguns px e a comparação chefe×comum virava sorte

## L243-245 (em `love.mouse.getPosition`, junto a `for _ = 1, 20 do GameplayScene.update(1 / 30) end`)

> o hover da carta mede o retângulo do ÚLTIMO desenho: quando a escala
> de UI muda entre um tamanho e outro, um quadro de aquecimento
> (só depois de a mão assentar no layout do tamanho atual)

## L289 (em `love.mouse.getPosition`, junto a `t:truthy(string.format("%s: inimigo ainda grande (%.0fpx >= 140)",`)

> legível: nunca menor que a própria carta da mão

## L313-317 (em `love.mouse.getPosition`, junto a `local _, _, cardY = GameplayScene.handLayout()`)

> O TETO DA MÃO (pé nunca abaixo do topo da mão em repouso,
> GameplayScene ENEMY_HAND_CLEARANCE=12) pode erguer o pé
> acima da borda nos salões de laje baixa (2 e 5) — é a
> limitação de enquadramento já registrada em
> memory/enemy_pose_and_scene_anchor.md, não recuo do palco.

## L334 (em `love.mouse.getPosition`, junto a `local x, y, w, h = 0, 60, 1280, 660`)

> a inversão pura da geometria: o pé cai EXATAMENTE no limite pedido

## L344-345 (em `love.mouse.getPosition`, junto a `t:eq("1024x768: escala de tela 1", WorldRoad.enemyScreenK(768 - 52), 1)`)

> tela grande (v2, Out/2026): o inimigo cresce mais que a área — com a
> mão escalada ele precisa ser a estrela; o 4:3 fica exatamente igual

