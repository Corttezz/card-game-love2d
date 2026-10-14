---
name: code_notes/src/ui/CardGridRender.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardGridRender.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardGridRender.lua`

Origem: `src/ui/CardGridRender.lua` em `7dbdb60d` (2 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local Config             = require("src.core.Config")`)

> src/ui/CardGridRender.lua
> Render de carta "mini" num grid, com warp 3D (mesh+shader), sombra direcional
> e camada de animacao de icone. PARIDADE com o drawCardMini da
> CollectionScreen (o hover anima o icone nas duas) — garantida por
> `tools/test_card_live_hover.lua`, NAO por este comentario: ele afirmava a
> paridade desde sempre e a troca pela imagem viva nunca tinha sido extraida
> pra ca, entao o Deck Viewer ficou sem animacao no hover ate Set/2026.
> Extraído pra ser COMPARTILHADO: o Deck Viewer da run usa exatamente o mesmo
> caminho de render que a aba de Coleção, então o hover (profundidade/tilt/
> sombra/ícone vivo) fica igualzinho (pedido do Daniel: "tudo idêntico").
>
> draw(instance, x, y, cardW, cardH, hoverScale, alpha, mouseUV, hoverStrength)
> mouseUV: vec2 [-1,1] relativo ao centro da carta (0,0 = sem press)
> hoverStrength: 0..1 (usa pro warp + pro offset tilt da sombra)

## L31-43 (em `M.draw`, junto a `local _prevImage = instance.image`)

> ICONE VIVO — em TODA carta visivel (dono, 13/Out/2026), nao so no hover.
>
> Historico: em Set/2026 este modulo (renderizador do Deck Viewer e do
> Gerenciador de Coringas) nao animava nem no hover, porque a troca pela
> imagem viva morava inline na CollectionScreen e nunca fora extraida —
> embora o cabecalho AFIRMASSE paridade. Comentario que promete paridade
> nao a garante; so o codigo garante. Por isso a regra mora num lugar so:
> CardFrame.displayImage (inclusive reducedMotion = estatica).
>
> Swap TEMPORARIO de `instance.image` (mesmo idioma da Colecao), restaurado
> no fim: assim as ~8 leituras de `instance.image` abaixo — inclusive a
> malha do warp e as uniforms do shader — enxergam o frame vivo sem que
> nenhuma delas precise saber que ele existe.

