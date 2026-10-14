---
name: code_notes/components/JokerManagerScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/JokerManagerScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/JokerManagerScreen.lua`

Origem: `components/JokerManagerScreen.lua` em `7dbdb60d` (5 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local JokerManagerScreen = {}`)

> components/JokerManagerScreen.lua
> GERENCIADOR DE CORINGAS — tela cheia (Jul/2026). Mostra TODOS os coringas
> possuídos na run (coleção + bancada) e deixa o jogador escolher quais 3
> ficam ATIVOS. Nasceu do feedback: "posso comprar vários jokers e eles
> somem; queria acessar todos e escolher os ativos, trocando ao longo da run".
>
> Regras:
> • Coleção ilimitada; até MAX_JOKER_SLOTS ativos (o resto na bancada).
> • Clique num coringa alterna ativo/bancada (respeitando o teto).
> • Ativos: moldura dourada + selo "ATIVO N". Bancada: esmaecido + "BANCADA".
> • Hover mostra o tooltip completo. ESC / J / X fecha.
>
> Abrir: clique no painel de coringas (topo-esquerdo do combate) OU tecla J.

## L26-29 (em `JokerManagerScreen`, junto a `local CARD_W, CARD_H = 128, 192`)

> MESMAS métricas do DeckViewer/Coleção (feedback Jul/2026: "o gerenciador
> não está parecido com o deck e a coleção") — carta, gaps e header iguais;
> a única diferença de layout é a LINHA DE ESTADO sob cada carta (ATIVO n /
> BANCADA), que é a informação própria desta tela.

## L77-79 (em `JokerManagerScreen:isVisible`, junto a `function JokerManagerScreen:resize()`)

> Resize NÃO zera a rolagem: o draw recalcula maxScroll e reclampa a cada
> frame, então a posição de leitura sobrevive a fullscreen/arrasto de borda
> (antes voltava pro topo — mesmo padrão do RunJournalScreen).

## L233-236 (em `JokerManagerScreen:draw`, junto a `local cols, gx0, gridTop, gridH = self:_gridMetrics()`)

> ===== Grid — render IDÊNTICO ao DeckViewer/Coleção (CardGridRender:
> warp 3D no hover + sombra direcional + ícone vivo + interpolação
> suave). A identidade DESTA tela fica nos rótulos ATIVO n / BANCADA
> e no alpha da bancada — sem molduras que a Coleção não usa. =====

## L368-369 (em `drawStateLabel`, junto a `if hovered then`)

> Tooltip completo — ABAIXO da carta (coringas moram nas fileiras de
> cima; acima, o clamp cobria o topo da carta — feedback Jul/2026)

