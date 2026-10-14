---
name: code_notes/src/ui/HoloShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HoloShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HoloShader.lua`

Origem: `src/ui/HoloShader.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local HoloShader = {}`)

> src/ui/HoloShader.lua
> Wrapper do shader holográfico para cartas (rare/legendary).
> Aplicado seletivamente: ao desenhar uma carta com effect="holo" ou "glow" raro,
> chama HoloShader.draw(image, x, y, strength).

## L26-31 (em `HoloShader.isAvailable`, junto a `function HoloShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy, opts)`)

> Desenha uma imagem aplicando o reflexo com a intensidade dada.
> Uso: HoloShader.draw(cardCanvas, x, y, 0.5, 0, 1, 1, 0, 0, { kind = 1, anim = hover })
> opts.kind: 0 = rara (prata-azulado), 1 = lendária (dourado prismático)
> opts.anim: 0..1 — a faixa de varredura só existe/move com anim > 0
> (hover/selecionada); em repouso a carta é ESTÁTICA.
> strength < 0.005 desenha a carta crua (sem shader): pixel-a-pixel igual.

## L49-50 (em `HoloShader.draw`, junto a `HoloShader.REST = { glow = 0, holo = 0.08 }`)

> Força do reflexo por raridade/gate (fonte ÚNICA pra Card:draw e testes):
> rara 0 → 0.25 no hover; lendária 0.08 em repouso → 0.5 no hover.

