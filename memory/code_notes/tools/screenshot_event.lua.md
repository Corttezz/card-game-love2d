---
name: code_notes/tools/screenshot_event.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_event.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_event.lua`

Origem: `tools/screenshot_event.lua` em `7dbdb60d` (6 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/screenshot_event.lua
> Captura a EventScreen em todos os locales — a tela não tinha cobertura
> visual nenhuma.
>
> POR QUE POR LOCALE: chave de i18n errada não quebra nada. `I18n.t` cai no
> fallback, que é justamente o texto PT, então em português a tela fica
> PERFEITA e só quebra em inglês/alemão — onde ninguém olha. Renderizar nos 5
> é o único jeito de provar que a chave resolve, e é mais barato que descobrir
> em produção (foi assim que duas telas saíram bilíngues, ver
> tools/test_no_hardcoded_pt.lua).
>
> Roda: love . screenshot_event [locale]
> sem argumento  → um PNG por locale (pt_BR, en, es, fr, de)
> com argumento  → só aquele
> Saída: event_<locale>.png no diretório de save do LÖVE.

## L28-29 (em `M.run`, junto a `local fw, fh = (os.getenv("EVENT_SIZE") or ""):match("^(%d+)x(%d+)$")`)

> EVENT_SIZE=1920x1080: tela FALSIFICADA (mesmo truque do
> screenshot_enemy_scene — setMode acima do desktop trava o tool).

## L41 (em `love.graphics.getDimensions`, junto a `Rng.setActive(Rng.new(20260912))`)

> Seed fixa: o MESMO evento nos 5 idiomas, senão a comparação não vale.

## L48 (em `love.graphics.getDimensions`, junto a `local ev = os.getenv("EVENT_ID") and Events.get(os.getenv("EVENT_ID")) or Events.roll(1, {})`)

> EVENT_ID=<id> captura um evento específico (eventos de bioma, Out/2026).

## L66-70 (em `love.graphics.getDimensions`, junto a `local EM = require("engine.EventManager")`)

> ASSENTA a entrada antes de capturar. O tool é anterior à animação
> (Set/2026) e capturava em t≈0 — quando a cortina do fade ainda está
> fechada, ou seja, PNG preto nos 5 idiomas. Um tool que não avança o
> relógio da tela mede o frame errado e não avisa; foi só olhar a
> imagem que apareceu. Pump do EventManager + update, como no jogo.

## L77-80 (em `love.graphics.getDimensions`, junto a `local W, H = love.graphics.getWidth(), love.graphics.getHeight()`)

> Canvas em vez de love.graphics.captureScreenshot: o capture é
> ASSÍNCRONO (resolve no fim do frame), então num laço de 5 as
> capturas se atropelam e saem todas iguais — ou nenhuma. O canvas
> resolve na hora e o laço fica determinístico.

