---
name: code_notes/tools/preview_card_anim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_card_anim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_card_anim.lua`

Origem: `tools/preview_card_anim.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local M = {}`)

> tools/preview_card_anim.lua
> Contact sheet de carta com ícone ANIMADO (icons_anim/): renderiza a carta
> em N instantes do loop (canvas estático do CardFrame + CardAnimationLayer
> com t fixo) pra validar geometria (cover-fit/crop) e vida do movimento
> sem abrir o jogo.
>
> Uso:  love . preview_card_anim [card_id]     (default: warrior_standard_bearer)
> Saída: ~/.local/share/love/card-game/preview_card_anim.png

## L84-87 (em `M.run`, junto a `if anim then`)

> Verificação do QUADRO VIVO (o que as telas desenham via
> CardFrame.displayImage): espera 1.5 frames de animação e confere que
> liveImage devolve outro canvas. Pega regressão do tipo "anima no
> preview mas não no jogo".

