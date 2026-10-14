---
name: code_notes/tools/grade_locais.lua
description: Comentários com decisão/regra/histórico colhidos de tools/grade_locais.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/grade_locais.lua`

Origem: `tools/grade_locais.lua` em `7dbdb60d` (2 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local M = {}`)

> tools/grade_locais.lua
> GRADE DE CONFERÊNCIA dos lugares da encruzilhada: 5 locais × 6 atos numa
> imagem só. Roda via: love . grade_locais
>
> Cada célula é um recorte da encruzilhada RENDERIZADA naquele ato — chão,
> luz e céu do bioma de verdade, não sprite colado em fundo inventado. É o
> único jeito honesto de julgar o que o dono pediu ("se atente ao chão"),
> porque o defeito que ele apontou (grama verde sobre gelo) só aparece
> quando o pé do lugar encosta no piso da cena.
>
> Como showFork trava em 3 braços (regra do jogo), a grade usa DUAS
> encruzilhadas por ato: batalha/descanso/loja e elite/evento. Os pills de
> UI ficam de fora — aqui o rótulo é da grade, não do jogo.

## L65 (em `M.run`, junto a `local BRACO = { TW * 0.5 - 0.157 * TW, TW * 0.5, TW * 0.5 + 0.157 * TW }`)

> x do centro de cada braço na cena (medido: o fork abre 0.15w por lado)

