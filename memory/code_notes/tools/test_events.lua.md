---
name: code_notes/tools/test_events.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_events.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_events.lua`

Origem: `tools/test_events.lua` em `7dbdb60d` (8 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/test_events.lua
> Eventos narrativos (src/data/events.lua): Events.roll (determinismo + no-repeat
> por ato via stream "event"), integridade do catálogo, e um PROPERTY TEST que
> aplica TODA opção de TODO evento sem crashar. + efeito numérico do Altar.
> love . test_events

## L58 (em `M.run`, junto a `local biomeEvents, biomeByAct, leaks = 0, {}, 0`)

> ===== Eventos de BIOMA (Out/2026): só aparecem no cenário deles =====

## L78-79 (em `M.run`, junto a `TK.seedRng(77)`)

> endless: ato 9 desenhando o bioma 4 -> eventos do gelo podem sair, os do
> campo (bioma 1) nao

## L92 (em `M.run`, junto a `local I18n = require("src.i18n.I18n")`)

> Todo evento tem ilustração e texto nos 5 idiomas.

## L117-119 (em `out`, junto a `local pickerCalls = 0`)

> ===== PROPERTY: toda opção de todo evento aplica sem crashar =====
> Stub do card picker: no jogo real é a UI (RestScreen); headless não tem
> UI, então stubamos para exercitar a delegação (escriba/espelho/forja).

## L152 (em `_G.openCardPicker`, junto a `local altar = findEvent("altar_proibido")`)

> ===== Efeito numérico: Altar Proibido (sacrifício = -8 HP) =====

## L165-175 (em `_G.openCardPicker`, junto a `local EventScreen = require("components.EventScreen")`)

> ===== Os FloatingText de ganho/custo (regressao Set/2026) =====
> `gains`/`costs` sao DESCRITORES { k, n, fb }, nao strings. A migracao de
> i18n atualizou o rotulo do botao e esqueceu o `_spawnDeltas`, que
> concatenava a tabela: "attempt to concatenate upvalue 'txt' (a table
> value)" ao escolher qualquer opcao com ganho ou custo. Chegou como crash
> na cara do dono porque a trava existente (check_event_i18n) mede o
> ROTULO, e este caminho nao tinha cobertura nenhuma.
>
> O crash mora DENTRO do callback agendado, entao nao basta chamar: e
> preciso BOMBEAR a fila. Um teste que so chamasse passaria em verde com o
> bug presente.

## L203 (em `FloatingText.spawn`, junto a `for _ = 1, 40 do`)

> Aqui o bug aparece: os callbacks so rodam no update.

