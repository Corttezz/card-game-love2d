---
name: code_notes/tools/sfx_envelope.lua
description: Comentários com decisão/regra/histórico colhidos de tools/sfx_envelope.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/sfx_envelope.lua`

Origem: `tools/sfx_envelope.lua` em `7dbdb60d` (2 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local M = {}`)

> tools/sfx_envelope.lua
> Desenha a CURVA do envelope de um sfx em ASCII, janela a janela.
>
> Complementa o tools/check_sfx.lua: aquele dá os números-resumo (pico, t10),
> este mostra a FORMA. A diferença importa quando o número-resumo engana —
> caso real (Set/2026): `card-shelf-place` media "ataque em 0,41s" num arquivo
> de 0,60s, e só a curva responde a pergunta que decide o uso: os 0,41s antes
> do pico são SILÊNCIO (defeito de geração, o som chega atrasado) ou são som
> de verdade subindo (envelope legítimo, é só antecipar o disparo)?
>
> Isso é crítico pra som tocado em CASCATA: se o evento audível não coincide
> com o evento visual, o jogador ouve a carta 2 quando vê a carta 5.
>
> Uso:
> love . sfx_envelope card-shelf-place
> love . sfx_envelope shop-leave-whoosh 0.02   (janela de 20ms)

## L63-64 (em `M.run`, junto a `local onset`)

> Onset AUDÍVEL: primeira janela acima de 5% do pico. É esta — não o
> instante do pico — que define quando o jogador ouve o som começar.

