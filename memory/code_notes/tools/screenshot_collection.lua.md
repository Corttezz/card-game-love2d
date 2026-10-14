---
name: code_notes/tools/screenshot_collection.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_collection.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_collection.lua`

Origem: `tools/screenshot_collection.lua` em `7dbdb60d` (7 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/screenshot_collection.lua
> Captura a tela de coleção: grid (rolada até a carta alvo) + modal de
> inspeção da carta alvo. Validação visual das cartas animadas em TODAS
> as renderizações.
> Roda: love . screenshot_collection [card_id]   (default warrior_standard_bearer)
> Saída: ~/.local/share/love/card-game/collection_grid.png + collection_inspect.png

## L11-12 (em `M.run`, junto a `cardId = cardId or "warrior_iron_wave"`)

> Default: carta que existe na coleção (warrior_standard_bearer é joker —
> jokers não aparecem no grid da coleção; default antigo pendurava o tool).

## L21-22 (em `M.run`, junto a `if os.getenv("STORE_REVEAL") == "1" then`)

> STORE_REVEAL=1: catálogo inteiro DESCOBERTO (o sandbox de tool não
> tem perfil — sem isso a grade sai toda "?"; screenshots da loja)

## L28-31 (em `M.run`, junto a `for _ = 1, 200 do`)

> COLLECTION_FILTER=joker|attack|...: aba da coleção (coringa só aparece
> na aba de coringas)
> a coleção monta as instâncias em ONDAS (orçamento por frame); a carta
> alvo pode estar no fim da lista (coringas) — termina a montagem antes

## L47 (em `M.run`, junto a `if not target and os.getenv("STORE_REVEAL") == "1" and screen.filtered`)

> loja: qualquer carta serve de âncora (a ordem do grid muda com o idioma)

## L60-61 (em `M.run`, junto a `love.event.quit(1)`)

> Fix Jul/2026: sem o quit, o tool ficava PENDURADO com a janela
> aberta pra sempre (timeout de quem chama) em vez de falhar rapido.

## L78-79 (em `simulate`, junto a `local row = math.floor((targetIdx - 1) / 5)`)

> Rola o grid pra linha da carta alvo ficar visível
> (CARD_H=192, GAP_Y=24, COLS=5 — constantes locais do CollectionScreen)

