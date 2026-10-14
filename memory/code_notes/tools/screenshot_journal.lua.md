---
name: code_notes/tools/screenshot_journal.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_journal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_journal.lua`

Origem: `tools/screenshot_journal.lua` em `7dbdb60d` (7 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local M = {}`)

> tools/screenshot_journal.lua
> Capturas do ROTEIRO DA JORNADA (components/RunJournalScreen.lua), versão
> MAPA À MÃO (Out/2026).
>
> love . screenshot_journal               → run curta (2 atos), pt_BR e de, 1920x1080 e 1024x768
> love . screenshot_journal long          → run longa: 6 atos + endless
> love . screenshot_journal - de          → só o idioma do 3º arg
> JOURNAL_SIZES=1280x720,640x480          → outros tamanhos
>
> Sem love.window.setMode: a janela é FALSIFICADA (getWidth/getHeight) e o
> quadro vai pra um canvas do tamanho pedido (mesmo molde do
> tools/screenshot_uiscale.lua) — nenhuma janela aparece, e vários tamanhos
> saem do mesmo processo. A escala de UI é a REAL (k=1.5 em 1080p).
>
> Saída: tools/preview_out/journal_map/run_journal_<modo>_<WxH>_<loc>[_hover|_closed].png
>
> Run CURTA: ato 1 fechado (CONQUISTADO) + ato 2 em andamento, com
> encruzilhadas de 2 e 3 ramos, dois nós só no mapHistory (backfill, sem
> ramos) e a encruzilhada seguinte em aberto (pendingNodes).
> Run LONGA: os 6 atos + endless com 11 paradas; exercita a rolagem.

## L36-37 (em `love.graphics.getDimensions`, junto a `local fakeMX, fakeMY = -100, -100`)

> Mouse FALSO (nunca love.mouse.setPosition: a janela escondida fica fora do
> monitor e o cursor REAL do dono, que está jogando, iria junto).

## L62-63 (em `savePng`, junto a `local function visit(rm, act, floor, options, pick, snapIn, snapOut, notes, ev)`)

> Visita um nó como o jogo visitaria: mapHistory + journalBegin(options, pick)
> + Note/End. Sem snapOut a entrada fica ABERTA (o círculo vermelho).

## L79-80 (em `opts`, junto a `local function pickIds()`)

> Ids reais do catálogo (carta inventada faria o tooltip avisar e a captura
> mentir).

## L138-139 (em `run.pendingNodes`, junto a `function M.seedLong(rm, cards, jokers)`)

> 6 atos completos + endless. Tipos variam por ato pra o mapa não virar
> papel de parede; ganhos ciclam pelo catálogo; nº de ramos alterna 3/2.

## L197 (em `notes`, junto a `local types = { "battle", "elite", "shop", "battle", "rest", "event", "elite", "boss",`)

> Endless: o ato trava em totalActs+1 e o andar cicla 1..8.

## L284 (em `shot`, junto a `for i = 1, #screen.acts do if not screen:isActOpen(i) then screen:toggleAct(i) end end`)

> todos os atos abertos (acordeão)

