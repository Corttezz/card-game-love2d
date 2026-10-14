---
name: code_notes/src/ui/PackChoiceLayout.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PackChoiceLayout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PackChoiceLayout.lua`

Origem: `src/ui/PackChoiceLayout.lua` em `7dbdb60d` (8 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-33 (junto a `local PackChoiceLayout = {}`)

> src/ui/PackChoiceLayout.lua
> PLANO DE ZONAS da tela de escolha do booster pack.
>
> POR QUE ESTE MÓDULO EXISTE
> A tela foi crescendo por acumulação: a etiqueta de raridade foi colocada
> "embaixo da carta", os botões de confirmar/cancelar também ancoraram
> "embaixo da carta", e a faixa de info foi parar no topo da tela. Cada
> elemento foi posicionado sozinho, sem um plano de onde cada coisa mora — e
> por isso colidiram: etiqueta e botões nasciam no MESMO Y (`ry + imgH + 8`),
> com o botão tapando a raridade sempre que uma carta era selecionada.
>
> A correção não é empurrar o botão alguns pixels. É dar a cada elemento uma
> ZONA própria, reservada, e nenhuma zona encostar na outra em nenhum estado:
>
> ┌──────────────────────────────────────────────┐
> │ C — CONTEXTO DO PACOTE                       │ nome do pacote, "Escolha N", Pular
> ├──────────────────────────────────────────────┤
> │ A — CARTAS (a protagonista)                  │ a fileira
> │ A' — etiquetas de raridade                   │ metadado colado na carta
> ├──────────────────────────────────────────────┤
> │ B — DETALHE DA CARTA EM FOCO                 │ tudo que se sabe da carta
> ├──────────────────────────────────────────────┤
> │ D — AÇÃO                                     │ Escolher / Cancelar / instrução
> └──────────────────────────────────────────────┘
>
> Como as alturas são ALOCADAS (e não chutadas), a ausência de sobreposição é
> garantida por construção, não por inspeção visual: as bandas são fatiadas em
> sequência a partir da altura da janela, e a escala da carta é o que cede
> quando o espaço aperta.
>
> As zonas B e D têm altura FIXA e existem sempre, mesmo vazias. Isso é
> deliberado: se elas aparecessem só quando há hover/seleção, o resto da tela
> pularia a cada movimento do mouse. Zona vazia mostra instrução.

## L46-50 (em `PackChoiceLayout`, junto a `PackChoiceLayout.CARD_SCALE_BASE = 1.90   -- ~1.43x a escala da mão`)

> Escala da carta.
> Teto da escala a 768px de altura. Em telas MAIORES ele sobe proporcional:
> travado em 1.90, um monitor 1080p deixava as cartas do mesmo tamanho de uma
> janela 768 e sobravam ~250px mortos em cima E embaixo. A carta e a
> recompensa; se ha tela, ela ocupa.

## L62-66 (em `fixedHeight`, junto a `function PackChoiceLayout.cardScale(n, imgW, imgH, sw, sh)`)

> Escala da carta: o maior valor que respeita AS DUAS restrições.
> • largura — a fileira inteira cabe (pacotes de 5 cartas existem);
> • altura  — sobra espaço para todas as outras bandas.
> A altura é a que costuma ser esquecida. Sem ela, em janela baixa a fileira
> crescia até não sobrar espaço e as bandas se atropelavam.

## L80-85 (em `PackChoiceLayout.cardScale`, junto a `function PackChoiceLayout.compute(n, imgW, imgH, sw, sh)`)

> Retorna as zonas já resolvidas para a janela atual.
> { header, cards, tags, detail, action }  -- cada um { x, y, w, h }
> + cardScale, cardW, cardH, spacing, rowStartX
>
> `n` é a quantidade de cartas do pacote; imgW/imgH são as dimensões do canvas
> da carta (antes da escala).

## L94-96 (em `PackChoiceLayout.compute`, junto a `local leftover = sh - 2 * L.MARGIN - fixedHeight() - cardH`)

> O que sobra depois das bandas fixas e das cartas vira respiro, dividido
> igualmente entre os 4 vãos; o excedente sobra como margem em cima/embaixo
> para a pilha ficar centrada em vez de grudada no topo.

## L104-108 (em `PackChoiceLayout.compute`, junto a `local gapI  = math.floor(gap)`)

> Alocação em INTEIROS, acumulando o valor já arredondado. Fatiar em float
> e arredondar cada banda no fim deixa o resto do arredondamento entre uma
> banda e a seguinte, e a de cima invade a de baixo em 1px — invisível na
> tela, mas a validação geométrica (que é o ponto deste módulo) acusa. A
> altura da carta sobe com ceil pelo mesmo motivo.

## L145-147 (em `PackChoiceLayout.cardPos`, junto a `function PackChoiceLayout.validate(zones, sw, sh)`)

> Verificação de invariante: nenhuma banda encosta na seguinte, e nada sai da
> tela. Usada pelo tool de captura de estados — é o que transforma "parece que
> não bate" em prova. Retorna (ok, lista de problemas).

## L176 (em `order`, junto a `if zones.rowStartX < 0 then`)

> A fileira de cartas também não pode sangrar pelos lados.

