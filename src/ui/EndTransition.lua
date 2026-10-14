local EndTransition = {}

local pendingTo = nil

function EndTransition.start(name, fadeOut, apply)
    if pendingTo then return false end
    pendingTo = name
    fadeOut(0.9, function()
        pendingTo = nil
        apply(name)
    end)
    return true
end

function EndTransition.clear() pendingTo = nil end

function EndTransition.pending() return pendingTo end

return EndTransition
