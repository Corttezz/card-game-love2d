local M = {}

local KINDS = { "Standard", "Buffoon", "Arcana", "Celestial", "Spectral" }
local PACK_ID = {
    Standard = "pack_standard", Buffoon = "pack_buffoon", Arcana = "pack_arcana",
    Celestial = "pack_celestial", Spectral = "pack_spectral",
}

local STEP = 1 / 60
local SHOT_EVERY = 4
local GIF_W = 960
local MAX_T = 10

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local rm = love.mouse.getPosition
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    local mouse = { x = -100, y = -100 }
    love.mouse.getPosition = function() return mouse.x, mouse.y end
    return mouse, function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
        love.mouse.getPosition = rm
    end
end

local function parseArg(raw)
    raw = tostring(raw or "1920x1080:depois")
    local w, h, tag, rest = raw:match("^(%d+)x(%d+):([%w_]+):?(.*)$")
    local only = (rest ~= "" and rest) or nil
    return tonumber(w) or 1920, tonumber(h) or 1080, tag or "depois", only
end

local function cardCenter(screen, i, k)
    local c = screen.pack.instances[i]
    if not (c and c.image) then return -100, -100 end
    local s = c.currentScale or 1
    local x = (c.layoutX or c.renderX or c.x or 0) + c.image:getWidth() * s * 0.5
    local y = (c.layoutY or c.renderY or c.y or 0) + c.image:getHeight() * s * 0.6
    return x * k, y * k
end

local function runKind(kind, W, H, tag, mouse, opts)
    local EventManager = require("engine.EventManager")
    local FlashShader = require("src.ui.FlashShader")
    local ScreenShake = require("src.systems.ScreenShake")
    local CardParticles = require("src.systems.CardParticles")
    local FloatingText = require("src.ui.FloatingText")
    local BoosterPackSystem = require("src.systems.BoosterPackSystem")
    local PackOpenScreen = require("components.PackOpenScreen")
    local UiScale = require("src.ui.UiScale")
    local Rng = require("src.systems.Rng")

    mouse.x, mouse.y = -100, -100
    EventManager.clear()
    CardParticles.clear()
    FloatingText.clear()
    Rng.setActive(Rng.new(777))
    math.randomseed(777)

    local pack = BoosterPackSystem.expandPackRecord({
        id = PACK_ID[kind], kind = kind, size = opts.size or 3, choose = 1,
    }, "warrior")
    if pack.instances[2] then pack.instances[2].edition = "holo" end

    local screen = PackOpenScreen:new()
    screen:show(pack, function() end)

    local k = UiScale.k(W, H)
    local full = love.graphics.newCanvas(W, H)
    local gh = math.floor(H * GIF_W / W + 0.5)
    local small = love.graphics.newCanvas(GIF_W, gh)
    full:setFilter("linear", "linear")

    local prefix = ("pv2_%s_%dx%d_%s%s"):format(tag, W, H, kind:lower(), opts.suffix or "")
    local timeline = {}
    local keyShots = {}
    local readyAt, explodedAt
    local script = nil
    local step, t, frame = 0, 0, 0
    local doneAt

    local function shoot(fullName)
        love.graphics.setCanvas(full)
        love.graphics.clear(0.12, 0.09, 0.07, 1)
        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
        FlashShader.draw()
        love.graphics.setCanvas(small)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(full, 0, 0, 0, GIF_W / W, GIF_W / W)
        love.graphics.setCanvas()
        if fullName then
            local id = full:newImageData()
            id:encode("png", fullName)
            id:release()
        end
        local sid = small:newImageData()
        sid:encode("png", ("%s_%03d.png"):format(prefix, frame))
        sid:release()
        love.graphics.present()
    end

    local pendingKey = {}
    local function keyAt(name, at) pendingKey[#pendingKey + 1] = { name = name, at = at } end

    while t < MAX_T do
        if not explodedAt and screen._sleeveExploded then
            explodedAt = t
            keyAt("2_estouro", t + 0.08)
        end
        if not readyAt and screen._cardsReady then
            readyAt = t
            keyAt("3_cartas", t + 0.15)
            script = {
                { at = t + 0.35, fn = function() mouse.x, mouse.y = cardCenter(screen, 1, k) end },
                { at = t + 0.85, fn = function() mouse.x, mouse.y = cardCenter(screen, 2, k) end, key = "4_hover" },
                { at = t + 1.45, fn = function()
                    local x, y = cardCenter(screen, 2, k)
                    screen:mousepressed(x, y, 1); screen:mousereleased(x, y, 1)
                end, key = "5_selecionada" },
                { at = t + 2.25, fn = function()
                    if opts.skip and screen.skip then screen:skip()
                    elseif opts.skip then screen:close()
                    else
                        local x, y = cardCenter(screen, 2, k)
                        screen:mousepressed(x, y, 1); screen:mousereleased(x, y, 1)
                    end
                end, key = "6_confirmou" },
            }
        end
        local chargeKeyAt = (PackOpenScreen.TIMING and not _G.gameSettings.reducedMotion)
            and (PackOpenScreen.TIMING.chargeEnd - 0.08) or 0.6
        if not readyAt and t > chargeKeyAt and not pendingKey.charge then
            pendingKey.charge = true
            keyAt("1_carga", t)
        end
        if script then
            for _, s in ipairs(script) do
                if not s.done and t >= s.at then
                    s.done = true
                    s.fn()
                    if s.key then keyAt(s.key, t + (s.key == "6_confirmou" and 0.2 or 0.3)) end
                end
            end
        end

        EventManager.update(STEP)
        FlashShader.update(STEP)
        ScreenShake.update(STEP)
        CardParticles.update(STEP)
        FloatingText.update(STEP)
        screen:update(STEP)
        t = t + STEP
        step = step + 1

        local keyName
        for i = #pendingKey, 1, -1 do
            local kk = pendingKey[i]
            if t >= kk.at then
                keyName = kk.name
                table.remove(pendingKey, i)
            end
        end
        if step % SHOT_EVERY == 0 or keyName then
            local fn = keyName and ("%s_key_%s.png"):format(prefix, keyName) or nil
            shoot(fn)
            timeline[#timeline + 1] = ("%03d t=%.3f%s"):format(frame, t, keyName and (" key=" .. keyName) or "")
            if keyName then keyShots[#keyShots + 1] = keyName end
            frame = frame + 1
        end
        if not screen.visible then
            doneAt = doneAt or t
            if t - doneAt > 0.3 then break end
        end
    end
    love.filesystem.write(prefix .. "_timeline.txt", table.concat(timeline, "\n") .. "\n")
    full:release(); small:release()
    print(("[pacotes_v2] %s frames=%d explode=%.2f prontas=%s fim=%s chaves=%s"):format(
        prefix, frame, explodedAt or -1, readyAt and ("%.2f"):format(readyAt) or "nunca",
        doneAt and ("%.2f"):format(doneAt) or "nunca", table.concat(keyShots, ",")))
    return readyAt ~= nil and doneAt ~= nil
end

local function runResize(mouse, setSize)
    local EventManager = require("engine.EventManager")
    local BoosterPackSystem = require("src.systems.BoosterPackSystem")
    local PackOpenScreen = require("components.PackOpenScreen")
    local Layout = require("src.ui.PackChoiceLayout")
    local UiScale = require("src.ui.UiScale")
    EventManager.clear()
    mouse.x, mouse.y = -100, -100
    local pack = BoosterPackSystem.expandPackRecord({
        id = "pack_buffoon", kind = "Buffoon", size = 3, choose = 1 }, "warrior")
    local screen = PackOpenScreen:new()
    local steps = {
        { w = 1280, h = 720, t = 1.55, name = "1_meio_da_abertura_1280x720" },
        { w = 1920, h = 1080, t = 0.45, name = "2_cresceu_no_meio_1920x1080" },
        { w = 1920, h = 1080, t = 1.2, name = "3_pronta_1920x1080" },
        { w = 1024, h = 600, t = 0.5, name = "4_encolheu_com_destaque_1024x600", select = true },
        { w = 800, h = 600, t = 0.5, name = "5_minima_800x600" },
    }
    local ok = true
    setSize(steps[1].w, steps[1].h)
    screen:show(pack, function() end)
    for i, st in ipairs(steps) do
        if i > 1 then
            setSize(st.w, st.h)
            require("src.ui.FontManager").clearCache()
            screen:resize()
        end
        if st.select then
            local k = UiScale.k(st.w, st.h)
            local x, y = cardCenter(screen, 2, k)
            screen:mousepressed(x, y, 1); screen:mousereleased(x, y, 1)
        end
        for _ = 1, math.floor(st.t / STEP) do
            EventManager.update(STEP)
            screen:update(STEP)
        end
        local c = love.graphics.newCanvas(st.w, st.h)
        love.graphics.setCanvas(c)
        love.graphics.clear(0.12, 0.09, 0.07, 1)
        screen:draw()
        love.graphics.setCanvas()
        local id = c:newImageData()
        id:encode("png", "pv2_resize_" .. st.name .. ".png")
        id:release(); c:release()
        love.graphics.present()
        local k = UiScale.k(st.w, st.h)
        local zv, problems = Layout.validate(screen._zones, math.floor(st.w / k + 0.5), math.floor(st.h / k + 0.5))
        ok = ok and zv
        print(("[pacotes_v2] resize %s k=%.2f %s"):format(st.name, k,
            zv and "GEOMETRIA OK" or ("FALHA: " .. table.concat(problems, "; "))))
    end
    screen:hide()
    return ok
end

function M.run(raw)
    if tostring(raw) == "resize" then
        _G.EventManager = _G.EventManager or require("engine.EventManager")
        _G.Event = _G.Event or require("engine.Event")
        require("src.i18n.I18n").init()
        require("src.i18n.I18n").setLocale("pt_BR")
        require("src.ui.PixelCanvas").enableNearest()
        local UiScale = require("src.ui.UiScale")
        UiScale.force(nil)
        UiScale.adoptDefaults()
        require("src.ui.DissolveShader").load()
        require("src.ui.HoloShader").load()
        local game = require("src.core.Game"):new()
        game:startNewRun("warrior")
        _G.game = game
        _G.gameSettings = _G.gameSettings or {}
        local size = { 1280, 720 }
        local mouse, restore = fakeWindow(1, 1)
        love.graphics.getWidth = function() return size[1] end
        love.graphics.getHeight = function() return size[2] end
        love.graphics.getDimensions = function() return size[1], size[2] end
        local ok = runResize(mouse, function(w, h) size[1], size[2] = w, h end)
        restore()
        print("[pacotes_v2] TOTAL " .. (ok and "ok" or "FAIL"))
        return ok
    end
    local W, H, tag, only = parseArg(raw)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    UiScale.adoptDefaults()
    require("src.ui.CRTShader").load()
    require("src.ui.DissolveShader").load()
    require("src.ui.FlashShader").load()
    require("src.ui.BoosterShader").load()
    require("src.ui.FoilShader").load()
    require("src.ui.PolychromeShader").load()
    require("src.ui.HoloShader").load()
    require("src.systems.ScreenShake").install()
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    _G.game = game
    _G.gameSettings = _G.gameSettings or {}

    local mouse, restore = fakeWindow(W, H)
    require("src.ui.FontManager").clearCache()
    require("src.ui.CardFrame").clearCache()
    local ok = true
    for _, kind in ipairs(KINDS) do
        if not only or only == kind:lower() or only == "all" then
            _G.gameSettings.reducedMotion = false
            ok = runKind(kind, W, H, tag, mouse, {}) and ok
        end
    end
    if not only or only == "extra" then
        _G.gameSettings.reducedMotion = true
        ok = runKind("Arcana", W, H, tag, mouse, { suffix = "_reduced" }) and ok
        _G.gameSettings.reducedMotion = false
        ok = runKind("Buffoon", W, H, tag, mouse, { suffix = "_pular", skip = true }) and ok
        ok = runKind("Celestial", W, H, tag, mouse, { suffix = "_5cartas", size = 5 }) and ok
    end
    restore()
    print("[pacotes_v2] TOTAL " .. (ok and "ok" or "FAIL"))
    return ok
end

return M
