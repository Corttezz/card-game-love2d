---
name: code_notes/src/ui/SceneBackground.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/SceneBackground.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/SceneBackground.lua`

Origem: `src/ui/SceneBackground.lua` em `7dbdb60d` (7 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/SceneBackground.lua
> Carrega e desenha backgrounds de tela cheia gerados via PixelLab.
> Arquivos esperados em assets/sprites/scenes/<scene>.png.
> Cena desenha o PNG escalado pra ocupar toda a tela (nearest) + overlay escuro
> suave pra não competir com conteúdo.
>
> Uso:
> if SceneBackground.draw("menu", width, height) then ... end
>
> Cenas conhecidas: menu, gameplay, collection, gameOver, victory, classSelection, cardReward.

## L66-69 (em `SceneBackground.draw`, junto a `function SceneBackground.drawParallax(scene, width, height, overlayAlpha, offX, offY, zoom)`)

> Desenha a cena com ZOOM extra + offset de parallax (o zoom cria a folga
> pra imagem deslocar sem mostrar borda). offX/offY em pixels de tela.
> Retorna (true, transform) se o PNG existe — transform = {scale, ox, oy}
> pra ancorar elementos na imagem (ex: brilho das velas do Menu v2.1).

## L80 (em `SceneBackground.drawParallax`, junto a `local slackX = (dw - width) / 2`)

> offset limitado à folga do zoom (nunca mostra borda)

## L98-102 (em `SceneBackground.drawParallax`, junto a `function SceneBackground.drawParallaxCrossfade(sceneA, sceneB, mix, width, height,`)

> Como drawParallax, mas faz CROSSFADE entre duas cenas (mesmo tamanho) —
> usado pela animação de vela do Menu (frames de flicker desenhados à mão).
> `mix` 0 = 100% sceneA, 1 = 100% sceneB. As duas usam o MESMO transform
> (calculado a partir de sceneA), e o overlay ink é aplicado UMA vez no fim.
> Retorna (true, transform) igual ao drawParallax.

## L123-124 (em `SceneBackground.drawParallaxCrossfade`, junto a `love.graphics.setColor(1, 1, 1, 1)`)

> base sempre opaca (evita "vazar" preto no meio do crossfade); o alvo
> entra por cima com alpha = mix.

## L143-144 (em `SceneBackground.has`, junto a `function SceneBackground.getSize(scene)`)

> Retorna (imgW, imgH) da scene. Útil pra computar o mesmo cover-fit que draw
> faz e converter coordenadas PNG → coordenadas de tela.

## L151-156 (em `SceneBackground.getSize`, junto a `function SceneBackground.getCoverTransform(scene, width, height)`)

> Retorna o transform cover-fit que `draw(scene, width, height)` aplica:
> { scale, dw, dh, ox, oy }
> onde a scene PNG é renderizada em (ox, oy) com dimensões (dw, dh).
> Use pra mapear (em.xr, em.yr) normalizado da PNG para coordenadas de tela:
> screenX = ox + em.xr * dw
> screenY = oy + em.yr * dh

