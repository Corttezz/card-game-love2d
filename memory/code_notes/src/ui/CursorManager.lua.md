---
name: code_notes/src/ui/CursorManager.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CursorManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CursorManager.lua`

Origem: `src/ui/CursorManager.lua` em `7dbdb60d` (9 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/CursorManager.lua
> Cursor CUSTOMIZADO pixel-art (estilo grimório — ouro envelhecido + tinta).
> O cursor do SO é escondido (love.mouse.setVisible(false) no load) e o
> sprite desenha por software no FIM do love.draw, DENTRO da cena CRT —
> assim ele sofre o warp/scanline do tubo junto com o mundo (Balatro).
>
> Estados:
> "arrow" (default) — seta dourada com outline ink
> "hand"            — mão apontando (hover em qualquer clicável)
> Quem sabe do hover PEDE o estado por frame: CursorManager.request("hand")
> (Button/Card/fork chamam no update). draw() consome e reseta pro default.
> Pressionado (mouse down): desloca 1px e escurece de leve — feedback tátil.

## L19 (em `images`, junto a `local want = "arrow"`)

> estado pedido neste frame

## L22-23 (em `images`, junto a `local COLORS = {`)

> Paleta de células das matrizes (24×26):
> . transparente | I ink | B osso (corpo) | L luz quente | D sombra | G ouro

## L32-35 (em `D`, junto a `local ARROW = {`)

> Seta clássica RASTERIZADA POR POLÍGONO (arestas matematicamente retas —
> a v1 era desenhada à mão e saía torta). Hipotenusa 45° exata, borda
> esquerda vertical, rabo simétrico. Outline ink 1 célula + anel de trim:
> luz no topo/esquerda, sombra na base/direita (leitura de volume Balatro).

## L65-67 (em `ARROW`, junto a `local HAND = {`)

> Mão apontando (hover): indicador vertical reto, nós dos dedos dobrados,
> vinco do polegar, e PUNHO DE MANOPLA dourado com rebites (sabor Slay the
> Spire, paleta grimório).

## L116-118 (em `buildImage`, junto a `local function loadPng(path)`)

> Carrega cursor de PNG (arte PixelLab) com hotspot por CONTEÚDO: a ponta
> do dedo/seta = centro da primeira linha com pixel opaco. Retorna nil se
> o arquivo não existe (caller cai na matriz).

## L147-151 (em `images.arrow`, junto a `love.mouse.setVisible(false)`)

> Estado "hand" DESATIVADO a pedido (Jul/2026: "deixa só o cursor
> normal"). Os request("hand") dos clicáveis viram no-op (o guard de
> request ignora estado não registrado). Pra reativar, descomente:
> images.hand = loadPng("assets/sprites/ui/cursor_hand.png")
> or { img = buildImage(HAND), hx = 9, hy = 0 }

## L173 (em `CursorManager.draw`, junto a `want = "arrow"`)

> consome o pedido; próximo frame re-pede

## L174-176 (em `CursorManager.draw`, junto a `local s = math.max(1, math.floor(love.graphics.getHeight() / 256 + 0.5) / 2)`)

> escala responsiva (janela 768 de altura → 1.5×; 1080p → 2×), em meios
> passos — feedback "diminuir um pouco": 2× cheio ficava grande demais.
> O warp do CRT suaviza o meio-pixel do 1.5×.

