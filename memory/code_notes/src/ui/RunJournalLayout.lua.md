---
name: code_notes/src/ui/RunJournalLayout.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/RunJournalLayout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/RunJournalLayout.lua`

Origem: `src/ui/RunJournalLayout.lua` em `7dbdb60d` (9 de 26 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-37 (junto a `local RunJournalLayout = {}`)

> src/ui/RunJournalLayout.lua
> PLANO DE ZONAS do Roteiro da jornada (components/RunJournalScreen.lua),
> versão MAPA À MÃO (Out/2026).
>
> Pedido do dono: "literalmente um mapa, bem parecido com o mapa do Slay the
> Spire, que vai mostrando os trilhos que a gente vai seguindo e as decisões
> que a gente vai tomando. A gente consegue abrir e fechar o mapa para cada
> ato... como se tivesse sido escrito à mão, apenas com tinta preta e, no
> máximo, um círculo vermelho... com uma folha envelhecida."
>
> O layout é uma função PURA da janela + o que cada ato tem (quantas paradas,
> quantos ramos cada encruzilhada tinha, qual foi tomado, aberto/fechado). O
> draw só lê o resultado; `validate()` confere as zonas por construção
> (mesmo molde do src/ui/PackChoiceLayout.lua).
>
> ┌────────────────────────────────────────────────┐
> │ CABEÇALHO   título · progresso           [X]   │ altura fixa
> ├────────────────────────────────────────────────┤
> │ FOLHAS (rolável)                               │ flex
> │  ┌ [+] ATO 1 · CAMPOS ARRUINADOS   CONQUISTADO┐│ ato FECHADO = tira
> │  ┌ [-] ATO 2 · COLINAS DA TORRE      3/8      ┐│ ato ABERTO = folha
> │  │ nº │        mapa (sobe)        │ anotações ││   bandas: andar /
> │  │ 8  │          castelo          │           ││   mapa / margem
> │  │ 3  │   (x)   o                 │ +carta    ││   o = ramo não tomado
> │  │ 2  │      \  |                 │ vida -7   ││   (x) = círculo vermelho
> │  │ 1  │    o   #                  │ ouro +19  ││   # = parada tomada
> │  │ legenda: # luta  ? evento  ...             ││   rodapé da folha
> │  └────────────────────────────────────────────┘│
> └────────────────────────────────────────────────┘
>
> O mapa SOBE (andar 1 embaixo, castelo no topo), como no StS. Cada andar é
> uma linha; na linha, os ramos que a encruzilhada ofereceu ficam lado a
> lado, centrados no ponto de onde o jogador veio. O ramo tomado vira o
> centro da linha seguinte: o caminho serpenteia sozinho.
>
> Quando aperta, quem cede é a ESCALA (altura da linha, glifo 2x -> 1x,
> fonte da margem), nunca a posição das bandas.

## L66-69 (em `clamp`, junto a `local bit = require("bit")`)

> Jitter DETERMINÍSTICO (seed da run + ato + linha + ramo): a imperfeição
> "à mão" é sempre a mesma pra mesma run, então a captura é reproduzível.
> (xorshift de 32 bits por argumento, via `bit` do LuaJIT: um LCG simples
> deixava padrões visíveis no pontilhado das manchas do papel)

## L92-98 (em `noteSizeFor`, junto a `function RunJournalLayout.compute(sw, sh, acts, scroll, seed)`)

> acts: lista de {
> open = bool, isEndless = bool, legend = nº de itens da legenda,
> nodes = { { row = r, n = nº de ramos, pick = índice tomado }, ... } (ordem cronológica)
> pending = { row = r, n = nº de ramos } ou nil (encruzilhada em aberto)
> }
> scroll: deslocamento vertical pedido (clampado; devolvido em L.scroll).
> seed: inteiro (jitter); opcional.

## L165-166 (em `S`, junto a `local y = zone.y + R.TOP_SLACK - L.scroll`)

> 2ª passada: posições (scroll embutido: hit-test trivial). Ancorado no
> topo, como página de diário.

## L190-191 (em `S.rowY`, junto a `local half = glyph / 2`)

> caminho: cada parada ocupa a linha dela; os ramos ficam lado a
> lado centrados no ponto de onde o jogador veio.

## L193-194 (em `S.rowY`, junto a `local minX = S.map.x + half + 4`)

> (o glyphRect tem 3px de folga em volta do glifo e o jitter
> horizontal chega a 3px: a margem aqui tem que cobrir os dois)

## L247-248 (em `S.pending`, junto a `if not a.isEndless then`)

> O castelo do ato (topo do mapa). Se o chefe já foi visitado, o
> castelo fica onde o caminho chegou; senão, centrado e esmaecido.

## L272-274 (em `RunJournalLayout.glyphRect`, junto a `function RunJournalLayout.tipRect(L, S, p, w, h)`)

> Retângulo do detalhe (hover) de uma parada: ao LADO do glifo, dentro da
> folha ∩ zona visível. Prefere a direita (margem das anotações); vai pra
> esquerda quando não cabe.

## L313-314 (em `overlaps`, junto a `function RunJournalLayout.validate(L, tip)`)

> Confere as invariantes de zona. Devolve lista de problemas (vazia = ok).
> `tip` opcional: { rect = , sheet = índice, node = ponto } do detalhe aberto.

