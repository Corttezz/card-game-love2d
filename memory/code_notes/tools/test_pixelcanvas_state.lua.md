---
name: code_notes/tools/test_pixelcanvas_state.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_pixelcanvas_state.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_pixelcanvas_state.lua`

Origem: `tools/test_pixelcanvas_state.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local TK = require("tools.testkit")`)

> tools/test_pixelcanvas_state.lua
> Regressão do bug "carta piscando no hover" (Jul/2026): PixelCanvas.beginDraw
> não isolava transform/scissor do chamador — um render LAZY de frames de
> animação no meio de um draw transformado (slide-in do CardRewardScreen,
> scroll com scissor da Coleção) compunha o conteúdo deslocado/clipado pra
> fora do canvas e CACHEAVA frames em branco: a carta só aparecia no frame 0.
> love . test_one test_pixelcanvas_state

## L31-32 (em `M.run`, junto a `love.graphics.push()`)

> 1) beginDraw sob transform+scissor hostis: o desenho tem que cair
> no canvas em coordenadas locais, sem clip do chamador.

## L59-61 (em `M.run`, junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> 2) Integração: animação de carta construída LAZY sob transform ativa
> (cenário exato do CardRewardScreen em slide-in) — NENHUM frame pode
> sair em branco, e o resultado tem que casar com a construção limpa.

