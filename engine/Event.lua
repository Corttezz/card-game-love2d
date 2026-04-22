-- engine/Event.lua
-- Evento da fila do EventManager. Inspirado em engine/event.lua do Balatro.
--
-- Configs:
--   trigger   = "after" | "immediate" | "condition" | "before"
--   delay     = segundos (usado por after/before). Default 0.
--   func      = function() return done end
--               Retornar true (ou nil) marca o evento completo.
--               Retornar false mantém o evento vivo (polling).
--   blocking  = true por padrão. Enquanto não completa, eventos seguintes
--               da MESMA fila não rodam. Use false para efeitos paralelos.
--   blockable = true por padrão. Se false, ignora bloqueio de eventos anteriores
--               (roda imediato mesmo com fila travada).
--   ease      = { ref_table, ref_value, start, ease_to, type="lerp"|"smooth" }
--               Se presente, em cada handle interpola ref_table[ref_value].
--               Auto-completa quando delay segundos passam.
--   no_delete = true mantém o evento na fila após completar (raro; usado p/ debug).
--
-- Gatilhos:
--   immediate → roda no primeiro handle.
--   after     → espera delay segundos, aí roda func.
--   before    → roda func imediato, mas BLOQUEIA queue por delay segundos depois.
--                Útil quando você quer "disparar som agora, mas não liberar
--                próximo evento ainda".
--   condition → chama func(); se retornar true, completa (polling cada frame).

local Easing = require("engine.Easing")

local Event = {}
Event.__index = Event

function Event:new(config)
    local e = setmetatable({}, Event)
    e.trigger   = config.trigger or "immediate"
    e.delay     = config.delay or 0
    e.func      = config.func or function() return true end
    e.blocking  = (config.blocking ~= false)
    e.blockable = (config.blockable ~= false)
    e.ease      = config.ease
    e.no_delete = config.no_delete or false
    e.timer     = 0
    e.completed = false
    e.started   = false

    -- Normaliza ease: captura start se não fornecido
    if e.ease and e.ease.ref_table and e.ease.ref_value then
        if e.ease.start == nil then
            e.ease.start = e.ease.ref_table[e.ease.ref_value]
        end
        e.ease.type = e.ease.type or "smooth"
    end

    return e
end

-- Chamado pelo EventManager. dt em segundos. Retorna true se completou neste tick.
function Event:handle(dt)
    if self.completed then return true end
    self.timer = self.timer + dt

    if self.trigger == "immediate" then
        local done = self.func()
        if done ~= false then self.completed = true end

    elseif self.trigger == "after" then
        if self.timer >= self.delay then
            local done = self.func()
            if done ~= false then self.completed = true end
        end

    elseif self.trigger == "before" then
        if not self.started then
            local done = self.func()
            self.started = true
            -- "before" sempre conta como executado; só bloqueia queue pelo delay
            if done == false then self.completed = false end
        end
        if self.timer >= self.delay then
            self.completed = true
        end

    elseif self.trigger == "condition" then
        if self.func() then self.completed = true end

    elseif self.trigger == "ease" and self.ease then
        local t = math.min(1, self.delay > 0 and (self.timer / self.delay) or 1)
        local eased = Easing.apply(self.ease.type, t)
        local from, to = self.ease.start, self.ease.ease_to
        self.ease.ref_table[self.ease.ref_value] = from + (to - from) * eased
        if t >= 1 then
            self.completed = true
        end
    end

    return self.completed
end

return Event
