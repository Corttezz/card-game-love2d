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

    if e.ease and e.ease.ref_table and e.ease.ref_value then
        if e.ease.start == nil then
            e.ease.start = e.ease.ref_table[e.ease.ref_value]
        end
        e.ease.type = e.ease.type or "smooth"
    end

    return e
end

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
