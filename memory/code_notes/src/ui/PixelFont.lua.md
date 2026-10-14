---
name: code_notes/src/ui/PixelFont.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PixelFont.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PixelFont.lua`

Origem: `src/ui/PixelFont.lua` em `7dbdb60d` (1 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local PixelFont = {}`)

> src/ui/PixelFont.lua
> Fonte pixel-friendly usada EXCLUSIVAMENTE pelos componentes da carta
> (`src/ui/card/`) — CardHeader (título), CardStatsFooter (ATTACK/DEFESA/ACTION),
> CardCostBadge, CardRaritySeal, JokerHeader.
>
> Usa a fonte default do LÖVE com `setFilter("nearest", "nearest")`. A chrome
> de UI (botões, menus, settings, topbar) usa `FontManager` com a Press Start 2P
> em `assets/fonts/pixel.ttf` — proposital: as duas famílias têm proporções
> diferentes e ficam melhores em contextos diferentes.
>
> Se quiser mudar a fonte das cartas, edite aqui. NÃO delegue para FontManager.

