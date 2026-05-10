-- engine/EventManager.lua
-- Fila global de eventos temporais. Inspirado no E_MANAGER do Balatro.
-- Substitui state machines hardcoded com sequências declarativas:
--
--   EventManager.add(Event{trigger="after", delay=0.4, func=function()
--       card:juice_up(); Sfx.play("sword"); return true
--   end})
--   EventManager.add(Event{trigger="after", delay=0.2, func=function()
--       enemy:takeDamage(10); triggerShake(8, 0.2); return true
--   end})
--
-- Eventos blocking numa fila rodam em ordem: só o topo processa até completar.
-- Eventos não-blocking (blocking=false) rodam em paralelo, em qualquer posição.
-- Múltiplas filas (ex: "base", "ui", "tutorial") isolam contextos.

local Event = require("engine.Event")

local EventManager = {}

-- Filas nomeadas. "base" é a default; outras são criadas sob demanda.
EventManager.queues = {
    base = {},
    ui = {},
}

-- Paused bloqueia TODAS as filas (ex: menu de settings sobre batalha).
EventManager.paused = false

-- Adiciona evento à fila. Retorna o próprio evento (útil pra inspecionar depois).
-- @param event Event — instância criada via Event:new{...}
-- @param queueName string|nil — default "base"
function EventManager.add(event, queueName)
    queueName = queueName or "base"
    EventManager.queues[queueName] = EventManager.queues[queueName] or {}
    table.insert(EventManager.queues[queueName], event)
    return event
end

-- Açúcar sintático: EventManager.addEvent{trigger="after", delay=1, func=...}
-- cria e adiciona em uma chamada.
function EventManager.addEvent(config, queueName)
    return EventManager.add(Event:new(config), queueName)
end

-- Conveniência: executa fn após delay segundos. Blocking por padrão.
function EventManager.after(delay, fn, queueName)
    return EventManager.add(Event:new({
        trigger = "after",
        delay = delay,
        func = function() fn(); return true end,
    }), queueName)
end

-- Conveniência: ease um campo de uma table até ease_to em duration segundos.
-- Ex: EventManager.ease(card, "x", 400, 0.6, "smooth")
function EventManager.ease(tbl, key, ease_to, duration, easingType, queueName)
    return EventManager.add(Event:new({
        trigger = "ease",
        delay = duration,
        ease = {
            ref_table = tbl,
            ref_value = key,
            ease_to = ease_to,
            type = easingType or "smooth",
        },
    }), queueName)
end

-- Versões NÃO-BLOQUEANTES dos helpers acima. Use quando várias animações
-- devem rodar em PARALELO (tempos absolutos a partir de agora) em vez de
-- sequencial (tempos relativos ao evento anterior).
--
-- Ex: para uma sequência de splash onde várias coisas acontecem em momentos
-- absolutos diferentes (t=0.10, t=0.50, t=1.20):
--   EventManager.parallel(0.10, fn1, "splash")
--   EventManager.parallel(0.50, fn2, "splash")
--   EventManager.parallel(1.20, fn3, "splash")
-- Todas começam a contar tempo agora; cada uma dispara quando seu delay
-- absoluto vence, sem esperar a anterior completar.
function EventManager.parallel(delay, fn, queueName)
    return EventManager.add(Event:new({
        trigger = "after",
        delay = delay,
        func = function() fn(); return true end,
        blocking = false,
    }), queueName)
end

function EventManager.parallelEase(tbl, key, ease_to, duration, easingType, queueName)
    return EventManager.add(Event:new({
        trigger = "ease",
        delay = duration,
        ease = {
            ref_table = tbl,
            ref_value = key,
            ease_to = ease_to,
            type = easingType or "smooth",
        },
        blocking = false,
    }), queueName)
end

-- Limpa todos os eventos de uma queue (ou todas se nil).
function EventManager.clear(queueName)
    if queueName then
        EventManager.queues[queueName] = {}
    else
        for k, _ in pairs(EventManager.queues) do
            EventManager.queues[k] = {}
        end
    end
end

-- Conta eventos pendentes (diagnóstico).
function EventManager.pendingCount(queueName)
    local total = 0
    if queueName then
        return #(EventManager.queues[queueName] or {})
    end
    for _, q in pairs(EventManager.queues) do total = total + #q end
    return total
end

-- Update chamado uma vez por frame pelo main.lua. dt em segundos.
-- Lógica: em cada fila, itera do início. Eventos não-blocking rodam sempre;
-- eventos blocking travam a fila até completarem. Remove completos.
function EventManager.update(dt)
    if EventManager.paused then return end

    for _, queue in pairs(EventManager.queues) do
        local blocked = false
        local i = 1
        while i <= #queue do
            local ev = queue[i]
            local canRun = true
            if blocked and ev.blockable then canRun = false end

            if canRun then
                local done = ev:handle(dt)
                if done and not ev.no_delete then
                    table.remove(queue, i)
                else
                    if ev.blocking then blocked = true end
                    i = i + 1
                end
            else
                if ev.blocking then blocked = true end
                i = i + 1
            end
        end
    end
end

return EventManager
