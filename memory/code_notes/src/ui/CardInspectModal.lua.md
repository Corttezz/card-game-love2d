---
name: code_notes/src/ui/CardInspectModal.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardInspectModal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardInspectModal.lua`

Origem: `src/ui/CardInspectModal.lua` em `7dbdb60d` (3 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local CardInspectModal = {}`)

> src/ui/CardInspectModal.lua
> Modal de INSPEÇÃO de carta (carta grande com warp 3D + painel lateral com
> nome/tipo/classe/raridade/stats/descrição/efeitos), navegável por setas.
> Extraído do drawInspectModal da CollectionScreen (Jul/2026) pra ser
> COMPARTILHADO — o Deck Viewer da run abre a MESMA visão ao clicar numa carta,
> ficando idêntico à aba de Coleção do menu (pedido do Daniel).
>
> Uso:
> modal = CardInspectModal:new()
> modal:show(instance, list, index)   -- list/index opcionais (setas navegam)
> modal:update(dt); modal:draw()
> modal:mousepressed(x,y,b) / :keypressed(key)   -- consomem enquanto aberto
>
> Instância deve ter .image (canvas do CardFrame). Se vier com forja aplicada,
> os stats/gemas já refletem isso (o Deck Viewer passa instâncias upgradadas).

## L144-146 (em `CardInspectModal:draw`, junto a `local _prevImage = inst.image`)

> Ícone animado: a inspeção desenha o quadro vivo como toda carta visível
> (CardFrame.displayImage decide; reducedMotion = estática). Swap
> temporário de inst.image, restaurado logo após o bloco de desenho.

## L246 (em `CardInspectModal:draw`, junto a `local upgraded = (inst.upgrades or 0) > 0`)

> destaque VERDE se forjada (padrão StS de stat aumentado)

