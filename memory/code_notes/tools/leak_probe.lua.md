---
name: code_notes/tools/leak_probe.lua
description: Comentários com decisão/regra/histórico colhidos de tools/leak_probe.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/leak_probe.lua`

Origem: `tools/leak_probe.lua` em `7dbdb60d` (2 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/leak_probe.lua
> SONDA DE VAZAMENTO (Out/2026): roda runs do piloto em sequencia no MESMO
> processo (como a bateria de balanceamento) e, depois de cada run, mede:
> • heap Lua apos collect completo;
> • memoria de textura + contagem de canvases/imagens (love.graphics.getStats);
> • filas do EventManager;
> • um CENSO do grafo alcancavel a partir de package.loaded/_G/registry
> (atravessando upvalues de funcoes e metatables), com o caminho de cada
> tabela grande — a diferenca entre dois censos aponta QUEM cresce.
>
> love . leak_probe [runs] [classe] [seedBase] [politica]
>
> Saida em tempo real (flush por linha) em <save dir>/leak_probe.log — o stdout
> do lovec redirecionado e bufferizado em blocos.

## L25-26 (em `out`, junto a `function M.census(minSize)`)

> Censo: BFS do grafo alcancavel. Devolve { total = n, paths = {path = size} }
> onde paths guarda o numero de entradas diretas de cada tabela com >= minSize.

