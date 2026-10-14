---
name: code_notes/engine/Event.lua
description: Comentários com decisão/regra/histórico colhidos de engine/Event.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/Event.lua`

Origem: `engine/Event.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local Easing = require("engine.Easing")`)

> engine/Event.lua
> Evento da fila do EventManager. Inspirado em engine/event.lua do Balatro.
>
> Configs:
> trigger   = "after" | "immediate" | "condition" | "before"
> delay     = segundos (usado por after/before). Default 0.
> func      = function() return done end
> Retornar true (ou nil) marca o evento completo.
> Retornar false mantém o evento vivo (polling).
> blocking  = true por padrão. Enquanto não completa, eventos seguintes
> da MESMA fila não rodam. Use false para efeitos paralelos.
> blockable = true por padrão. Se false, ignora bloqueio de eventos anteriores
> (roda imediato mesmo com fila travada).
> ease      = { ref_table, ref_value, start, ease_to, type="lerp"|"smooth" }
> Se presente, em cada handle interpola ref_table[ref_value].
> Auto-completa quando delay segundos passam.
> no_delete = true mantém o evento na fila após completar (raro; usado p/ debug).
>
> Gatilhos:
> immediate → roda no primeiro handle.
> after     → espera delay segundos, aí roda func.
> before    → roda func imediato, mas BLOQUEIA queue por delay segundos depois.
> Útil quando você quer "disparar som agora, mas não liberar
> próximo evento ainda".
> condition → chama func(); se retornar true, completa (polling cada frame).

## L75 (em `Event:handle`, junto a `if done == false then self.completed = false end`)

> "before" sempre conta como executado; só bloqueia queue pelo delay

