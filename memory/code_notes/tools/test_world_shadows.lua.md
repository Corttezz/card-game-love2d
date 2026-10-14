---
name: code_notes/tools/test_world_shadows.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_world_shadows.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_world_shadows.lua`

Origem: `tools/test_world_shadows.lua` em `7dbdb60d` (12 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local TK = require("tools.testkit")`)

> tools/test_world_shadows.lua
> TRAVA das sombras do mundo (ShadowEngine v9 — pegada, Out/2026).
>
> Defeito do dono: "a fogueira é um círculo, e a sombra é o círculo inteiro
> depois dela" — a silhueta inteira do sprite virada a partir do pé punha uma
> cópia do objeto deitada à frente de tudo que é baixo e largo (fogueira,
> baú, pedra, cadáver). O perfil de pegada (baseK/riseK/lenK) corrige no
> MOTOR; este teste mede o resultado por classe, em canvas, sem janela:
>
> ALTO-FINO   (árvore, pinheiro, placa, poste, estandarte, loja, tenda,
> obelisco, totem): PIXEL A PIXEL igual ao v8.4 — o teste
> carrega uma reimplementação do caminho antigo e compara.
> BAIXO/LARGO (fogueiras dos 6 biomas, baú, pedras, toco, moita, flores,
> tufo): nasce DENTRO da pegada, ≥ 70% dos pixels dentro
> dela, só uma orla curta abaixo da linha de contato.
> CRIATURA    em pé (bípede) = igual ao v8.4; larga e baixa (ratos) =
> pegada; cadáver (death deitada) = orla; flutuante = sombra
> solta igual ao v8.4.
> DECALQUE    (fissura: riseK 0) não projeta nada.
>
> Rode: love . test_one test_world_shadows

## L30 (em `M`, junto a `local LEN, ALPHA = 0.55 + 0.45 * TOD, 0.15 + 0.15 * LUMA`)

> constantes do v8.4 (setFrame): len = 0.55 + 0.45·tod; alpha = 0.15 + 0.15·luma

## L46-49 (em `tipShift`, junto a `local function legacyBatch(body, alphaK)`)

> REIMPLEMENTAÇÃO do v8.4 (a referência "antes"): 3 passadas de smear no
> scratch ⅓ com lighten/premultiplied, composto UMA vez em preto.

## L108-110 (em `tint`, junto a `local function render(fn)`)

> Render em canvas (tamanho da janela — o scratch do motor é dela) + medida

## L123-124 (em `render`, junto a `local function measure(id, fx, fy, halfW, footTop, spanX, spanY)`)

> Varre uma janela em volta do objeto: n = pixels de sombra; inside = os
> que caem na pegada [x0..x1]×[footTop..feetY]; minY/maxY da sombra.

## L157 (em `M.run`, junto a `local TALL = {`)

> ===== 1) ALTO-FINO e BARRACA/LOJA: pixel a pixel iguais ao v8.4 =====

## L184-185 (em `TALL`, junto a `t:truthy(key .. ": nasce na linha de contato (topo " .. (minY - FY) .. "px)",`)

> (footPad > 0: as linhas da saliência — degrau, deck — viram pra
> cima do pé, como sempre fizeram; ficam atrás do sprite)

## L190-191 (em `TALL`, junto a `local LOW = {`)

> ===== 2) BAIXO/LARGO: dentro da pegada, orla curta =====
> { chave do PNG, escala, footPad, chave do perfil }

## L220 (em `opts`, junto a `local old = render(function() legacySprite(img, FX, FY, s, pad) end)`)

> a mesma peça no v8.4 (documenta o defeito: quase tudo FORA)

## L286 (em `drawer`, junto a `do`)

> 4a) bípede em pé: sem perfil → igual ao v8.4

## L298 (em `drawer`, junto a `do`)

> 4b) flutuante: sombra solta (widthK/lenK/alphaK da pose) igual ao v8.4

## L401 (em `gr`, junto a `for _, f in ipairs(love.filesystem.getDirectoryItems("assets/sprites/world")) do`)

> ===== 7) todo PNG de fogueira tem perfil (cheio ou da família) =====

