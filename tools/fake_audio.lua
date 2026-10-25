local FakeAudio = {}

local real = nil
local sources = {}
local durations = {}

local Source = {}
Source.__index = function(self, k)
    local m = rawget(Source, k)
    if m ~= nil then return m end
    return function() return nil end
end

local function pathOf(what)
    if type(what) == "string" then return what end
    local ok, name = pcall(function() return what:getFilename() end)
    if ok and type(name) == "string" then return name end
    return tostring(what)
end

local function durationOf(path, kind)
    if durations[path] then return durations[path] end
    local d = nil
    if real and real.newDecoder and type(path) == "string" and love.filesystem.getInfo(path) then
        local ok, dec = pcall(real.newDecoder, path, 4096)
        if ok and dec then
            local okd, v = pcall(dec.getDuration, dec)
            if okd and type(v) == "number" and v > 0 then d = v end
            pcall(dec.release, dec)
        end
    end
    d = d or ((kind == "stream") and 120 or 3)
    durations[path] = d
    return d
end

local function newSource(what, kind)
    local path = pathOf(what)
    local s = setmetatable({
        path = path, kind = kind or "static", vol = 1, pitch = 1, looping = false,
        playing = false, pos = 0, dur = durationOf(path, kind), plays = 0, stops = 0,
    }, Source)
    sources[#sources + 1] = s
    return s
end

function Source:play() self.playing = true; self.plays = self.plays + 1; return true end
function Source:stop() if self.playing then self.stops = self.stops + 1 end; self.playing = false; self.pos = 0 end
function Source:pause() self.playing = false end
function Source:isPlaying() return self.playing end
function Source:setVolume(v) self.vol = v end
function Source:getVolume() return self.vol end
function Source:setPitch(p) self.pitch = p end
function Source:getPitch() return self.pitch end
function Source:setLooping(l) self.looping = l and true or false end
function Source:isLooping() return self.looping end
function Source:getDuration() return self.dur end
function Source:tell() return self.pos end
function Source:seek(p) self.pos = math.max(0, math.min(self.dur, p or 0)) end
function Source:getType() return self.kind end
function Source:setFilter(f) self.filter = f end
function Source:getFilter() return self.filter end
function Source:release() self.playing = false end
function Source:typeOf(n) return n == "Source" or n == "Object" end
function Source:clone()
    local c = newSource(self.path, self.kind)
    c.vol, c.pitch, c.looping, c.dur = self.vol, self.pitch, self.looping, self.dur
    return c
end

function FakeAudio.install()
    if real then return end
    real = {
        newSource = love.audio.newSource, setVolume = love.audio.setVolume,
        play = love.audio.play, stop = love.audio.stop, pause = love.audio.pause,
        newDecoder = love.sound and love.sound.newDecoder,
    }
    sources = {}
    love.audio.newSource = newSource
    love.audio.setVolume = function() end
    love.audio.play = function(s) if s and s.play then s:play() end end
    love.audio.stop = function(s)
        if s and s.stop then s:stop() return end
        for _, x in ipairs(sources) do x:stop() end
    end
    love.audio.pause = function() end
end

function FakeAudio.uninstall()
    if not real then return end
    love.audio.newSource = real.newSource
    love.audio.setVolume = real.setVolume
    love.audio.play = real.play
    love.audio.stop = real.stop
    love.audio.pause = real.pause
    real = nil
end

function FakeAudio.advance(dt)
    for _, s in ipairs(sources) do
        if s.playing then
            s.pos = s.pos + dt * (s.pitch or 1)
            if s.pos >= s.dur then
                if s.looping then s.pos = s.pos % s.dur
                else s.playing = false; s.pos = 0 end
            end
        end
    end
end

function FakeAudio.playing()
    local out = {}
    for _, s in ipairs(sources) do
        if s.playing then out[#out + 1] = s end
    end
    return out
end

function FakeAudio.all() return sources end

return FakeAudio
