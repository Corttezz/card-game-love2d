local MusicCues = {}
MusicCues.__index = MusicCues

MusicCues.LATE_MAX = 0.15
MusicCues.WRAP_EPS = 0.5

function MusicCues.new(data)
    local self = setmetatable({}, MusicCues)
    self.cues = (data and data.cues) or {}
    self.duration = (data and data.duration) or 0
    self.i = 1
    self.last = nil
    return self
end

local function firstAfter(cues, pos)
    local lo, hi = 1, #cues + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if cues[mid].t <= pos then lo = mid + 1 else hi = mid end
    end
    return lo
end

function MusicCues:reset()
    self.last = nil
end

function MusicCues:position()
    return self.last
end

local function fireUpTo(self, pos, fire)
    local cues = self.cues
    local n = 0
    while self.i <= #cues and cues[self.i].t <= pos do
        local c = cues[self.i]
        local late = pos - c.t
        if late <= MusicCues.LATE_MAX and fire then
            fire(c, late)
            n = n + 1
        end
        self.i = self.i + 1
    end
    return n
end

function MusicCues:update(pos, fire)
    if pos == nil then
        self.last = nil
        return 0
    end
    local last = self.last
    if last == nil then
        self.i = firstAfter(self.cues, pos)
        self.last = pos
        return 0
    end
    local n = 0
    if pos < last - MusicCues.WRAP_EPS then
        if fire then
            local cues = self.cues
            for k = firstAfter(cues, last), #cues do
                local c = cues[k]
                local late = (self.duration - c.t) + pos
                if c.t > last and late <= MusicCues.LATE_MAX then
                    fire(c, late)
                    n = n + 1
                end
            end
        end
        self.i = firstAfter(self.cues, math.max(0, pos - MusicCues.LATE_MAX) - 1e-9)
        self.last = pos
        n = n + fireUpTo(self, pos, fire)
        return n
    end
    if pos < last then
        return 0
    end
    n = n + fireUpTo(self, pos, fire)
    self.last = pos
    return n
end

return MusicCues
