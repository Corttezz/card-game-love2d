local M = {}

function M.run(arg)
    local act, fps, stills = 1, 30, nil
    if arg and arg ~= "" then
        local a, f, s = tostring(arg):match("^(%d+):?(%d*):?(.*)$")
        act = tonumber(a) or 1
        fps = tonumber(f) or 30
        if s and s ~= "" then
            stills = {}
            for v in s:gmatch("[^,]+") do stills[#stills + 1] = tonumber(v) end
        end
    end
    local ActIntro = require("src.scenes.ActIntroScene")
    local I18n = require("src.i18n.I18n")
    I18n.init(); I18n.setLocale(os.getenv("TOOL_LOCALE") or "pt_BR", true)
    _G.gameSettings = _G.gameSettings or {}
    _G.ACT_INTRO_FORCE = true
    local events, clock = {}, 0
    local fake = { sources = {}, groups = { ambient = 1, sfx = 1, music = 1 } }
    function fake:loadSound(code, path, opts) self.sources[code] = { path = path, opts = opts } end
    function fake:play(code, opts)
        local s = self.sources[code]
        events[#events + 1] = { t = clock, code = code, path = s and s.path, loop = opts and opts.loop or false }
        return { stop = function() end }
    end
    function fake:setInstanceGain() end
    local realAudio = _G.audioSystem
    _G.audioSystem = fake
    local done = false
    if not ActIntro.start(act, function() done = true end) then
        print("[record_act_intro] cena indisponível para o ato " .. act)
        _G.audioSystem = realAudio
        return false
    end
    local W, H = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(W, H)
    local dir = "act_intro_rec/act" .. act
    love.filesystem.createDirectory(dir .. "/frames")
    local dt = 1 / fps
    local n = 0
    local function shot(path)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        ActIntro.draw()
        love.graphics.setCanvas()
        canvas:newImageData():encode("png", path)
    end
    if stills then
        table.sort(stills)
        local i = 1
        while not done and i <= #stills do
            if clock + 1e-6 >= stills[i] then
                shot(string.format("%s/still_%05.2f.png", dir, stills[i]))
                i = i + 1
            else
                ActIntro.update(dt); clock = clock + dt
            end
        end
    else
        while not done do
            shot(string.format("%s/frames/%05d.png", dir, n))
            n = n + 1
            ActIntro.update(dt); clock = clock + dt
            if n > fps * 30 then break end
        end
        local parts = {}
        for _, e in ipairs(events) do
            parts[#parts + 1] = string.format('{"t":%.3f,"code":"%s","path":"%s","loop":%s}',
                e.t, e.code, e.path or "", tostring(e.loop))
        end
        love.filesystem.write(dir .. "/events.json", string.format('{"fps":%d,"frames":%d,"duration":%.3f,"events":[%s]}',
            fps, n, n / fps, table.concat(parts, ",")))
    end
    _G.audioSystem = realAudio
    _G.ACT_INTRO_FORCE = nil
    print(string.format("[record_act_intro] ato %d: %s em %s/%s", act,
        stills and (#stills .. " stills") or (n .. " quadros"), love.filesystem.getSaveDirectory(), dir))
    return true
end

return M
