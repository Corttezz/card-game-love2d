---
name: code_notes/src/ui/card/CardAnimationLayer.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/CardAnimationLayer.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/CardAnimationLayer.lua`

Origem: `src/ui/card/CardAnimationLayer.lua` em `7dbdb60d` (6 de 37 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/card/CardAnimationLayer.lua
> Overlay animado drawn DEPOIS do canvas estático da carta.
> Não invalida cache (canvas continua sendo reutilizado); anima pintando em cima.
>
> Catálogo de overlays (por trigger):
> legendary             → halo dourado pulsante
> bgPattern=fire/rage   → embers subindo
> bgPattern=blood       → gota de sangue escorrendo
> bgPattern=poison      → bolhas musgo subindo
> bgPattern=arcane      → glyphs flutuando (add blend)
> bgPattern=shadow      → wisps subindo
> bgPattern=abyss       → olhos piscando + ripple + tendril
> bgPattern=void        → estrelas + estrela cadente + poeira
>
> API:
> CardAnimationLayer.draw(card, art, x, y, scaleX, scaleY, t)
> onde x,y = canto superior esquerdo da carta no screen, scaleX/Y = escala aplicada,
> e t = love.timer.getTime() (passado pra evitar custo repetido).

## L76 (em `embers`, junto a `local function bloodDrip(x, y, sx, sy, t)`)

> Gota de sangue escorrendo (blood bg). Restaurado a pedido (Jul/2026).

## L89-91 (em `bloodDrip`, junto a `local function poisonBubbles(x, y, sx, sy, t)`)

> ===== Tier A animated overlays (2026-04-20) =====
> Padrão das funções: recebem (x, y, sx, sy, t) e desenham dentro da art slot.
> Art slot: (x + 4*sx, y + 17*sy) com (88*sx × 107*sy).

## L316-318 (em `CardAnimationLayer.draw`, junto a `if _G.gameSettings and _G.gameSettings.reducedMotion then return end`)

> reducedMotion REMOVE MOVIMENTO (CLAUDE.md): brasas, gotas, halo e
> glifos sao movimento puro — somem junto com o icone animado
> (CardFrame.liveEnabled). Nenhuma informacao mora aqui.

## L335-338 (em `CardAnimationLayer.draw`, junto a `local bg = art and art.bgPattern`)

> bgPattern-based overlays.
> (storm/ice removidos Jul/2026: flash/shimmer liam como flicker/bug.
> jokerRing removido: orbitava atrás do ícone e virava pixel perdido.
> bloodDrip mantido a pedido.)

## L356-359 (em `CardAnimationLayer.draw`, junto a `if art and art.iconName and not IconFramesLoader.has(art.iconName) then`)

> ICON animations procedurais sutis (shine/drip/sparkle/deity_glow) —
> SÓ pra ícones sem frames PixelLab. Ícones com icons_anim/ já vivem
> dentro do canvas da carta (CardFrame pré-renderiza um canvas por frame
> e Card:draw troca self.image no tempo — warp/holo pegam de graça).

