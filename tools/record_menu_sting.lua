local M = {}

function M.run(arg)
    local fps = tonumber(arg) or 30
    local W, H, SECS = 1920, 1080, 8.0
    require("tools.testkit").bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    UiScale.adoptDefaults()
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end

    local events, clock = {}, 0
    local fake = { sources = {} }
    setmetatable(fake.sources, { __index = function(t, code)
        local e = { baseVolume = 1, instGain = {} }
        rawset(t, code, e)
        return e
    end })
    function fake:play(code, opts)
        local src = { playing = true }
        function src:isPlaying() return self.playing end
        function src:stop() self.playing = false end
        self.sources[code].instGain[src] = opts and opts.gain
        events[#events + 1] = { t = clock, code = code, vol = (opts and opts.gain) or 1, pitch = opts and opts.pitch or 1 }
        return src
    end
    function fake:playSound(code) return self:play(code) ~= nil end
    function fake:playMusic(code, opts)
        events[#events + 1] = { t = clock, code = code, music = true, fade = opts and opts.fadeDuration or 0 }
    end
    function fake:stopMusic() end
    function fake:fadeOutMusic() end
    function fake:setInstanceGain(code, src, g) self.sources[code].instGain[src] = g end
    local realAudio = _G.audioSystem
    _G.audioSystem = fake

    local Menu = require("components.Menu")
    Menu._resetSting()
    local menu = Menu:new()
    menu:enterWithIntro()
    local canvas = love.graphics.newCanvas(W, H)
    local dir = "menu_sting_rec"
    love.filesystem.createDirectory(dir .. "/frames")
    local dt, n = 1 / fps, 0
    while clock < SECS - 1e-6 do
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        menu:draw()
        love.graphics.pop()
        canvas:newImageData():encode("png", string.format("%s/frames/%05d.png", dir, n))
        n = n + 1
        if _G.EventManager then _G.EventManager.update(dt) end
        menu:update(dt)
        clock = clock + dt
    end
    local parts = {}
    for _, e in ipairs(events) do
        parts[#parts + 1] = string.format('{"t":%.4f,"code":"%s","vol":%.5f,"pitch":%.3f,"music":%s,"fade":%.2f}',
            e.t, e.code, e.vol or 1, e.pitch or 1, tostring(e.music or false), e.fade or 0)
    end
    love.filesystem.write(dir .. "/events.json", string.format('{"fps":%d,"frames":%d,"duration":%.3f,"events":[%s]}',
        fps, n, n / fps, table.concat(parts, ",")))
    _G.audioSystem = realAudio
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    Menu._resetSting()
    print(string.format("[record_menu_sting] %d quadros, %d sons em %s/%s", n, #events,
        love.filesystem.getSaveDirectory(), dir))
    return true
end

return M
