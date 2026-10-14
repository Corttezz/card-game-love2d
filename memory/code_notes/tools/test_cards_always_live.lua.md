---
name: code_notes/tools/test_cards_always_live.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_cards_always_live.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_cards_always_live.lua`

Origem: `tools/test_cards_always_live.lua` em `7dbdb60d` (14 de 31 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local TK = require("tools.testkit")`)

> tools/test_cards_always_live.lua
> CARTA VISIVEL = CARTA VIVA (regra do dono, 13/Out/2026):
> "a todo momento as cartas que estao sendo exibidas na tela eu quero que
> elas fiquem com a animacao sendo mostrada. Elas nao podem estar
> estaticas em NENHUM tipo de visualizacao em nenhum local."
> Revoga o "idle = estatico, interacao = vivo" de Jul/2026.
>
> O que esta suite trava:
> 1. A REGRA mora num lugar so (CardFrame.displayImage) e nenhuma tela
> chama o mecanismo (liveImage) direto — assim o reducedMotion vale em
> todo lugar de uma vez.
> 2. SEM hover, uma carta com icone animado desenha o quadro VIVO em
> Card:draw (mao, espolios, loja, pacote, classe, voo do combate), no
> CardGridRender (Deck Viewer, Gerenciador de Coringas) e na grade da
> Colecao — e o quadro AVANCA com o relogio simulado.
> 3. reducedMotion REMOVE MOVIMENTO: com a opcao ligada a carta fica no
> frame 0 (a arte estatica), com ou sem hover.
> 4. PARIDADE DAS CAMADAS: a animacao e composta como base + icone + chrome
> (3 draws por frame em vez da carta inteira); o frame 0 composto assim
> tem que ser pixel a pixel o render direto — senao a carta "pisca" a
> cada volta do loop.
> 5. ORCAMENTO: dezenas de cartas pedindo vida no mesmo quadro ganham vida
> em ondas (orcamento global por quadro), nunca todas num quadro so.
>
> love . test_one test_cards_always_live

## L39-40 (em `textureOf`, junto a `local function spyDraw(fn)`)

> Executa fn com love.graphics.draw espiao; devolve o conjunto de texturas
> desenhadas ({ [tex] = true }).

## L55-56 (em `love.graphics.draw`, junto a `local function canvasDiff(a, b, tol)`)

> Diferenca entre dois canvases: maior desvio de canal (0..255) e quantos
> pixels divergem por mais de `tol` niveis em algum canal.

## L85-87 (em `M.run`, junto a `local function fonte(caminho)`)

> ===================================================================
> 1. A REGRA num lugar so — travada no FONTE
> ===================================================================

## L128-130 (em `hits`, junto a `local byType, animated = {}, {}`)

> ===================================================================
> Fixture: cartas animadas de cada tipo
> ===================================================================

## L147-149 (em `hits`, junto a `local realGetTime = love.timer.getTime`)

> Relogio SIMULADO: o indice do frame e o orcamento por quadro dependem
> dele; sob carga o relogio de parede mudaria o resultado de rodada pra
> rodada (licao do test_class_select).

## L171-173 (em `warm`, junto a `local amostras = {}`)

> ===============================================================
> 4. PARIDADE DAS CAMADAS (frame 0 composto == render direto)
> ===============================================================

## L194-196 (em `amostras`, junto a `local cd = animated[1]`)

> ===============================================================
> 2. SEM HOVER a carta e VIVA — e o quadro avanca com o relogio
> ===============================================================

## L261-263 (em `gotoFrame`, junto a `_G.gameSettings.reducedMotion = true`)

> ===============================================================
> 3. reducedMotion REMOVE MOVIMENTO: frame 0, com ou sem hover
> ===============================================================

## L285-287 (em `gotoFrame`, junto a `CardFrame.clearCache()`)

> ===============================================================
> 5. ORCAMENTO: muitas cartas no mesmo quadro ganham vida em ondas
> ===============================================================

## L309-311 (em `liveAfter`, junto a `local teto = math.ceil(N * 2 * n / CardFrame.BUILD_PER_FRAME) + N + 2`)

> por carta: n PNGs decodificados + (n-1) composicoes (+ camadas quando
> nao estao em cache), BUILD_PER_FRAME unidades por quadro; sob relogio
> simulado o teto de tempo nao morde (spent = 0), so a contagem

## L315 (em `liveAfter`, junto a `t:truthy("todas continuam vivas no quadro seguinte", (function()`)

> em uso no mesmo quadro: nenhuma e expulsa

## L322-324 (em `liveAfter`, junto a `local UnlockSystem = require("src.systems.UnlockSystem")`)

> ===============================================================
> 2b. COLECAO: a grade inteira viva sem hover (desenho real da tela)
> ===============================================================

## L355-357 (em `love.mouse.getPosition`, junto a `local desenhadas, vivas, estaticas = 0, 0, 0`)

> cartas animadas DESENHADAS neste quadro (algum canvas do set
> apareceu no draw): TODAS desenharam o frame corrente, NENHUMA
> a estatica

