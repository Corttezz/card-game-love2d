local Event = require("engine.Event")

local EventManager = {}

EventManager.queues = {
    base = {},
    ui = {},
}

EventManager.paused = false

function EventManager.add(event, queueName)
    queueName = queueName or "base"
    EventManager.queues[queueName] = EventManager.queues[queueName] or {}
    table.insert(EventManager.queues[queueName], event)
    return event
end

function EventManager.addEvent(config, queueName)
    return EventManager.add(Event:new(config), queueName)
end

function EventManager.after(delay, fn, queueName)
    return EventManager.add(Event:new({
        trigger = "after",
        delay = delay,
        func = function() fn(); return true end,
    }), queueName)
end

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

function EventManager.clear(queueName)
    if queueName then
        EventManager.queues[queueName] = {}
    else
        for k, _ in pairs(EventManager.queues) do
            EventManager.queues[k] = {}
        end
    end
end

function EventManager.pendingCount(queueName)
    local total = 0
    if queueName then
        return #(EventManager.queues[queueName] or {})
    end
    for _, q in pairs(EventManager.queues) do total = total + #q end
    return total
end

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
