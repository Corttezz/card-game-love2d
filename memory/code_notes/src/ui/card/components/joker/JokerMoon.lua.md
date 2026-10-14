---
name: code_notes/src/ui/card/components/joker/JokerMoon.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/joker/JokerMoon.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/joker/JokerMoon.lua`

Origem: `src/ui/card/components/joker/JokerMoon.lua` em `7dbdb60d` (3 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/joker/JokerMoon.lua
> Ornamento do canto superior ESQUERDO do joker: lua crescente dourada com
> estrela na concavidade — contrapeso tarot do JokerSeal (estrela 6 pontas,
> canto direito). Ocupa o lugar onde ficava o badge de custo de mana
> (removido Jul/2026: joker é passivo, não tem mana — o custo era dado
> vestigial exibido à toa).
>
> Pixel colocado à mão (13×13): outline INK via carimbo 4-direções da
> própria silhueta (idioma dos componentes de carta).
>
> API: JokerMoon.draw()

## L20-21 (em `JokerMoon`, junto a `local MOON = {`)

> Spans {xa, xb} por linha (13 linhas): crescente em "C" (abre pra direita),
> pontas afiladas que avançam sobre a concavidade.

## L67-68 (em `JokerMoon.draw`, junto a `local sx, sy = ox + 9, oy + 6`)

> Estrela 5px na concavidade (cruz), cream com centro claro — ecoa a gema
> central do JokerSeal do canto oposto.

