---
name: code_notes/tools/smoke_crt_mouse.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_crt_mouse.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_crt_mouse.lua`

Origem: `tools/smoke_crt_mouse.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local M = {}`)

> tools/smoke_crt_mouse.lua
> Regressão do MOUSE ATRAVÉS DO VIDRO (nasceu do bug "os filtros da
> Coleção clicam acima de onde aparecem" — o domo do CRT desloca a imagem
> perto do topo/base e o hit-test usava o mouse cru).
>
> Teste FIM-A-FIM pelo shader REAL (não contra uma cópia da matemática):
> 1. desenha um marcador branco em posição conhecida do canvas
> 2. renderiza pela lente do CRT (beginScene/endScene de verdade)
> 3. screenshot → acha onde o marcador foi parar na TELA (centróide)
> 4. CRTShader.screenToContent(tela) tem que devolver o canvas original
> Se a réplica Lua divergir do GLSL, o erro aparece em pixels aqui.
> love . smoke_crt_mouse

## L43-44 (em `check`, junto a `local _, topY = CRTShader.screenToContent(w / 2, 60)`)

> direção do bug: perto do TOPO a imagem desce → o conteúdo sob o
> mouse está ACIMA do pixel físico (mapped y < physical y)

## L50-52 (em `check`, junto a `local points = {`)

> ===== 2. fim-a-fim: marcador pelo shader real =====
> pontos nas zonas do bug: faixa de filtros da Coleção (topo), HintBar
> (base), laterais e centro

## L74-75 (em `points`, junto a `local sw, sh = imageData:getWidth(), imageData:getHeight()`)

> centróide do marcador no canal VERDE (o shader sampleia o
> verde sem offset de aberração cromática)

