local Debug = require("src.core.Debug")

local Rng = {}
Rng.__index = Rng

Rng.STREAMS = { "card", "shop", "map", "event", "enemy", "misc" }

local active = nil

local STREAM_SEED_STEP = 7919

function Rng.generateSeed()
    local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
    local base = (love and love.math and love.math.random(1, 2147483646)) or math.random(1, 2147483646)
    local seed = (base + math.floor(t * 1000)) % 2147483647
    if seed < 1 then seed = 1 end
    return seed
end

function Rng.new(seed)
    local self = setmetatable({}, Rng)
    self.seed = seed or Rng.generateSeed()
    self.streams = {}
    self.counters = {}
    self.meta = {}
    for i, name in ipairs(Rng.STREAMS) do
        self.streams[name] = love.math.newRandomGenerator(self.seed + i * STREAM_SEED_STEP)
        self.counters[name] = 0
    end
    return self
end

function Rng.fromState(state)
    if type(state) ~= "table" or not state.seed then
        return Rng.new()
    end
    local self = Rng.new(state.seed)
    for name, gen in pairs(self.streams) do
        local s = state.states and state.states[name]
        if s then
            local ok = pcall(function() gen:setState(s) end)
            if not ok then
                Debug.warn("[Rng] setState falhou pro stream '" .. name .. "' — stream re-seedado")
            end
        end
        self.counters[name] = (state.counters and state.counters[name]) or 0
    end
    if type(state.meta) == "table" then
        self.meta = state.meta
    end
    return self
end

function Rng:getState()
    local states = {}
    for name, gen in pairs(self.streams) do
        states[name] = gen:getState()
    end
    local counters = {}
    for name, c in pairs(self.counters) do counters[name] = c end
    return {
        seed = self.seed,
        states = states,
        counters = counters,
        meta = self.meta,
    }
end

function Rng:_gen(stream)
    local gen = self.streams[stream]
    if not gen then
        Rng._warnedStream = Rng._warnedStream or {}
        if not Rng._warnedStream[stream] then
            Rng._warnedStream[stream] = true
            Debug.warn("[Rng] AVISO: stream desconhecido: " .. tostring(stream) .. " (usando 'misc')")
        end
        gen = self.streams.misc
        stream = "misc"
    end
    self.counters[stream] = (self.counters[stream] or 0) + 1
    return gen
end

function Rng:random(stream, m, n)
    local gen = self:_gen(stream)
    if m == nil then
        return gen:random()
    elseif n == nil then
        return gen:random(m)
    end
    return gen:random(m, n)
end

function Rng:pick(stream, list)
    if not list or #list == 0 then return nil end
    return list[self:random(stream, #list)]
end

function Rng:weighted(stream, entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + (e.weight or 1) end
    if total <= 0 then return entries[1] and entries[1].item end
    local r = self:random(stream) * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e.item end
    end
    return entries[#entries].item
end

function Rng:getStreamState(stream)
    local gen = self.streams[stream]
    if not gen then return nil end
    return { state = gen:getState(), counter = self.counters[stream] or 0 }
end

function Rng:setStreamState(stream, st)
    local gen = self.streams[stream]
    if not (gen and type(st) == "table" and st.state) then return false end
    local ok = pcall(function() gen:setState(st.state) end)
    if ok then self.counters[stream] = st.counter or 0 end
    return ok
end

function Rng.setActive(rng)
    active = rng
    return active
end

function Rng.get()
    if not active then
        active = Rng.new()
    end
    return active
end

function Rng.clearActive()
    active = nil
end

function Rng.hasActive()
    return active ~= nil
end

return Rng
