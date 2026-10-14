local Debug = require("src.core.Debug")

local CombatBeats = {}

CombatBeats.QUEUE = "beats"

CombatBeats.HOLD = {
    MICRO        = 0.10,

    CARD_IMPACT  = 0.35,

    JOKER_PROC   = 0.16,

    SIDE_EFFECT  = 0.28,

    CARD_GAP     = 0.30,

    ORB          = 0.40,

    STATUS       = 0.55,

    TELEGRAPH    = 0.45,

    ENEMY_ACT    = 0.35,

    HIT_SETTLE   = 0.40,

    REFLECT      = 0.45,

    DOT          = 0.45,

    DECAY        = 0.25,

    HANDOFF      = 0.35,
}

CombatBeats.speed = 1.0

local warnedHold = {}
function CombatBeats.hold(h)
    if h == nil then return 0 end
    if type(h) == "number" then return h * CombatBeats.speed end
    local v = CombatBeats.HOLD[h]
    if not v then
        if not warnedHold[h] then
            warnedHold[h] = true
            Debug.warn("[CombatBeats] AVISO: hold desconhecido: '" .. tostring(h) .. "' (usando MICRO)")
        end
        v = CombatBeats.HOLD.MICRO
    end
    return v * CombatBeats.speed
end

CombatBeats.tracing = false
CombatBeats.log = {}

local function record(label)
    if CombatBeats.tracing then
        CombatBeats.log[#CombatBeats.log + 1] = label
    end
end

function CombatBeats.startTrace()
    CombatBeats.tracing = true
    CombatBeats.log = {}
end

function CombatBeats.stopTrace()
    CombatBeats.tracing = false
end

function CombatBeats.indexOf(label, from)
    for i = (from or 1), #CombatBeats.log do
        if CombatBeats.log[i] == label then return i end
    end
    return nil
end

function CombatBeats.mark(label)
    record(label)
end

function CombatBeats.traceString()
    return table.concat(CombatBeats.log, " > ")
end

local function em()
    local EM, Ev = _G.EventManager, _G.Event
    if EM and Ev then return EM, Ev end
    return nil
end

function CombatBeats.push(label, fn, hold)
    local EM, Ev = em()
    if not EM then
        record(label)
        if fn then fn() end
        return nil
    end
    local ev
    ev = Ev:new({
        trigger = "before",
        delay = CombatBeats.hold(hold),
        func = function()
            record(label)
            CombatBeats._current = ev
            if fn then fn() end
            CombatBeats._current = nil
            return true
        end,
    })
    return EM.add(ev, CombatBeats.QUEUE)
end

function CombatBeats.extendCurrent(hold)
    local ev = CombatBeats._current
    if not ev then return false end
    ev.delay = math.max(ev.delay or 0, CombatBeats.hold(hold))
    return true
end

function CombatBeats.pushUntil(label, startFn, isDone, timeout, hold)
    local EM, Ev = em()
    timeout = timeout or 2.0
    if not EM then
        record(label)
        if startFn then startFn() end
        return nil
    end
    local started = false
    local ev
    ev = Ev:new({
        trigger = "condition",
        func = function()
            if not started then
                started = true
                record(label)
                if startFn then startFn() end
            end
            if isDone and isDone() then return true end
            if ev.timer >= timeout then
                Debug.warn("[CombatBeats] timeout esperando '" .. tostring(label) .. "'")
                return true
            end
            return false
        end,
    })
    EM.add(ev, CombatBeats.QUEUE)
    if hold then CombatBeats.push(label .. ".settle", nil, hold) end
    return ev
end

function CombatBeats.pushAll(steps)
    for _, s in ipairs(steps or {}) do
        CombatBeats.push(s.label, s.fn, s.hold)
    end
end

function CombatBeats.step(sink, label, fn, hold)
    if sink then
        sink[#sink + 1] = { label = label, fn = fn, hold = hold }
    else
        fn()
    end
end

function CombatBeats.pending()
    local EM = _G.EventManager
    if not EM then return 0 end
    return EM.pendingCount(CombatBeats.QUEUE)
end

function CombatBeats.isBusy()
    return CombatBeats.pending() > 0
end

function CombatBeats.clear()
    local EM = _G.EventManager
    if EM then EM.clear(CombatBeats.QUEUE) end
end

return CombatBeats
