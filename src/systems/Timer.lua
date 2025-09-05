-- src/Timer.lua
-- Sistema de Timer simples para agendar eventos

local Timer = {}

-- Lista de timers ativos
local activeTimers = {}

-- Adiciona um timer
function Timer.after(delay, callback)
    local timer = {
        delay = delay,
        callback = callback,
        elapsed = 0
    }
    
    table.insert(activeTimers, timer)
    return timer
end

-- Atualiza todos os timers
function Timer.update(dt)
    for i = #activeTimers, 1, -1 do
        local timer = activeTimers[i]
        timer.elapsed = timer.elapsed + dt
        
        if timer.elapsed >= timer.delay then
            -- Timer expirou, executa callback
            if timer.callback then
                timer.callback()
            end
            
            -- Remove timer da lista
            table.remove(activeTimers, i)
        end
    end
end

-- Remove todos os timers
function Timer.clear()
    activeTimers = {}
end

-- Retorna número de timers ativos
function Timer.getCount()
    return #activeTimers
end

return Timer


