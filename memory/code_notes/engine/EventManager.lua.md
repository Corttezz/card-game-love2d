---
name: code_notes/engine/EventManager.lua
description: Comentários com decisão/regra/histórico colhidos de engine/EventManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/EventManager.lua`

Origem: `engine/EventManager.lua` em `7dbdb60d` (7 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local Event = require("engine.Event")`)

> engine/EventManager.lua
> Fila global de eventos temporais. Inspirado no E_MANAGER do Balatro.
> Substitui state machines hardcoded com sequências declarativas:
>
> EventManager.add(Event{trigger="after", delay=0.4, func=function()
> card:juice_up(); Sfx.play("sword"); return true
> end})
> EventManager.add(Event{trigger="after", delay=0.2, func=function()
> enemy:takeDamage(10); triggerShake(8, 0.2); return true
> end})
>
> Eventos blocking numa fila rodam em ordem: só o topo processa até completar.
> Eventos não-blocking (blocking=false) rodam em paralelo, em qualquer posição.
> Múltiplas filas (ex: "base", "ui", "tutorial") isolam contextos.

## L29-31 (em `ui`, junto a `function EventManager.add(event, queueName)`)

> Adiciona evento à fila. Retorna o próprio evento (útil pra inspecionar depois).
> @param event Event — instância criada via Event:new{...}
> @param queueName string|nil — default "base"

## L39-40 (em `EventManager.add`, junto a `function EventManager.addEvent(config, queueName)`)

> Açúcar sintático: EventManager.addEvent{trigger="after", delay=1, func=...}
> cria e adiciona em uma chamada.

## L54-55 (em `func`, junto a `function EventManager.ease(tbl, key, ease_to, duration, easingType, queueName)`)

> Conveniência: ease um campo de uma table até ease_to em duration segundos.
> Ex: EventManager.ease(card, "x", 400, 0.6, "smooth")

## L69-79 (em `ease`, junto a `function EventManager.parallel(delay, fn, queueName)`)

> Versões NÃO-BLOQUEANTES dos helpers acima. Use quando várias animações
> devem rodar em PARALELO (tempos absolutos a partir de agora) em vez de
> sequencial (tempos relativos ao evento anterior).
>
> Ex: para uma sequência de splash onde várias coisas acontecem em momentos
> absolutos diferentes (t=0.10, t=0.50, t=1.20):
> EventManager.parallel(0.10, fn1, "splash")
> EventManager.parallel(0.50, fn2, "splash")
> EventManager.parallel(1.20, fn3, "splash")
> Todas começam a contar tempo agora; cada uma dispara quando seu delay
> absoluto vence, sem esperar a anterior completar.

## L103 (em `ease`, junto a `function EventManager.clear(queueName)`)

> Limpa todos os eventos de uma queue (ou todas se nil).

## L124-126 (em `EventManager.pendingCount`, junto a `function EventManager.update(dt)`)

> Update chamado uma vez por frame pelo main.lua. dt em segundos.
> Lógica: em cada fila, itera do início. Eventos não-blocking rodam sempre;
> eventos blocking travam a fila até completarem. Remove completos.

