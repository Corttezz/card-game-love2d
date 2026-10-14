---
name: code_notes/tools/test_forge_resize.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_forge_resize.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_forge_resize.lua`

Origem: `tools/test_forge_resize.lua` em `7dbdb60d` (15 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_forge_resize.lua
> Auditoria de RESIZE da tela de forja (components/RestScreen.lua, modo picker).
>
> POR QUE ESTE TESTE EXISTE
> memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". Criar a tela já
> no tamanho final não exercita o bug — ele mora em "layout calculado num
> tamanho, janela muda, layout reaproveitado". A mesma memória registra que
> `love.window.setMode` repetido dentro de um tool TRAVA, então aqui a janela
> é FALSIFICADA: monkey-patch em love.graphics.getWidth/getHeight. Isso
> exercita exatamente o caminho do defeito (todo o layout desta tela deriva
> dessas duas funções) sem tocar na janela de verdade.
>
> A validação VISUAL continua sendo manual, pelo roteiro da memória.
>
> love . test_one test_forge_resize
> love . test_all               (registrado em tools/run_all_tests.lua)

## L37-39 (em `restoreWindow`, junto a `local function resizeTo(screen, w, h)`)

> Simula o que love.resize faz de verdade (main.lua:1479): limpa o cache de
> fontes ANTES de avisar as telas. Sem isso o teste seria mais leniente que o
> jogo — larguras medidas ficariam cacheadas do tamanho anterior.

## L75-76 (em `makeScreen`, junto a `local function stockDeck(game, want)`)

> Enche o deck com cartas forjáveis do catálogo (determinístico: ordenado por
> id). `want` = quantas cartas distintas queremos na bigorna.

## L85 (em `pool`, junto a `if cd and cd.type ~= "joker" and game.runManager:canUpgrade(id) then`)

> Joker nunca entra em currentDeck (invariante do projeto).

## L102-105 (em `M.run`, junto a `fakeW, fakeH = 800, 600`)

> ================================================================
> 1. GRADE: nasce pequena, cresce. A escala e as posições têm que
> acompanhar — este é o caminho do defeito.
> ================================================================

## L139-141 (em `M.run`, junto a `fakeW, fakeH = 640, 480`)

> ================================================================
> 2. PAGINAÇÃO: a página atual continua válida e ancorada.
> ================================================================

## L153 (em `M.run`, junto a `local stillThere = false`)

> A âncora garante que a carta que abria a página continua na tela.

## L166-170 (em `M.run`, junto a `fakeW, fakeH = 800, 600`)

> ================================================================
> 3. CERIMÔNIA: resize NO MEIO da subida pra pose herói.
> Armadilha do PackOpenScreen: resize que "reposiciona do zero"
> teleporta a animação. Aqui tem que RECALCULAR O DESTINO.
> ================================================================

## L175-176 (em `M.run`, junto a `cer:_onPickCard(target)`)

> _onPickCard recebe a ENTRY (a copia), nao o id: duas copias do
> mesmo id sao escolhas diferentes (RunManager, "Forja POR COPIA").

## L200 (em `M.run`, junto a `local lo = math.min(f.startX, f.heroX)`)

> cx tem que estar ENTRE berço e palco, coerente com a pose.

## L208 (em `M.run`, junto a `pump(cer, 1.2)`)

> Termina a cerimônia na janela nova: tem que virar o valor e fechar.

## L214-216 (em `M.run`, junto a `local plateXBefore = cer.forge.plate.x`)

> ================================================================
> 4. CERIMÔNIA: resize DEPOIS da virada preserva o estado animado.
> ================================================================

## L224-226 (em `M.run`, junto a `t:eq("largura da placa estável p/ o mesmo conteúdo",`)

> A LARGURA da placa depende só do conteúdo e das fontes (tamanhos
> fixos, como no resto desta tela) — ela deve ser ESTÁVEL. O que tem
> que acompanhar a janela é a POSIÇÃO: re-centrada na grade nova.

## L237-239 (em `M.run`, junto a `fakeW, fakeH = 1280, 720`)

> ================================================================
> 5. Painel de hover: ancorado na carta, com flip/clamp na tela nova.
> ================================================================

## L251-253 (em `M.run`, junto a `fakeW, fakeH = 800, 600`)

> ================================================================
> 6. Modo "choose" (fogueira) também tem que acompanhar.
> ================================================================

