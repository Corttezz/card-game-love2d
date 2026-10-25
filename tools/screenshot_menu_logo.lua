local M = {}

local SIZES = { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 } }

local function outDir(sub)
    local d = love.filesystem.getSource() .. "/tools/preview_out/menu_logo/" .. (sub and (sub .. "/") or "")
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function save(cv, dir, name)
    local id = cv:newImageData()
    local fd = id:encode("png")
    local f = assert(io.open(dir .. name, "wb"))
    f:write(fd:getString())
    f:close()
    fd:release()
    id:release()
    print("[menu_logo] " .. dir .. name)
end

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function step(menu, dt)
    if _G.EventManager then _G.EventManager.update(dt) end
    menu:update(dt)
end

local canvases = {}

local function render(menu, w, h)
    local key = w .. "x" .. h
    local cv = canvases[key] or love.graphics.newCanvas(w, h)
    canvases[key] = cv
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    love.graphics.setCanvas()
    return cv
end

function M.run(arg)
    local label, size = tostring(arg or "depois"):match("^([^:]+):?(.*)$")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.i18n.I18n").setLocale(os.getenv("LOGO_LOCALE") or "en")
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    UiScale.adoptDefaults()
    local Menu = require("components.Menu")
    local dt = 1 / 60

    if label == "fidelity" then
        local MB = require("src.ui.MenuBrand")
        local r = MB.load()
        local D = require("src.data.menu_brand")
        local cv = love.graphics.newCanvas(D.seal.w, D.seal.h)
        local worst = 0
        for _, t in ipairs({ 0.5, 1.0, 1.5, 2.0, 2.4, 2.65, 2.8 }) do
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setShader(r.sealShader)
            r.sealShader:send("T", t)
            r.sealShader:send("origin", { 0, 0 })
            r.sealShader:send("pxScale", 1)
            r.sealShader:send("sweepP", -10000)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(r.sealData, 0, 0)
            love.graphics.setShader()
            love.graphics.setCanvas()
            local got = cv:newImageData()
            local path = ("tools/preview_out/menu_logo/ref/seal_%.2f.png"):format(t)
            local f = assert(io.open(love.filesystem.getSource() .. "/" .. path, "rb"))
            local fd = love.filesystem.newFileData(f:read("*a"), "ref.png")
            f:close()
            local ref = love.image.newImageData(fd)
            local bad = 0
            for y = 0, D.seal.h - 1 do
                for x = 0, D.seal.w - 1 do
                    local r1, g1, b1, a1 = got:getPixel(x, y)
                    local r2, g2, b2, a2 = ref:getPixel(x, y)
                    local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2), math.abs(a1 - a2))
                    if d > 2 / 255 then bad = bad + 1 end
                end
            end
            worst = math.max(worst, bad)
            print(("[menu_logo] fidelidade T=%.2f pixels divergentes=%d"):format(t, bad))
            got:release(); ref:release(); fd:release()
        end
        print("[menu_logo] pior quadro: " .. worst)
        return true
    end

    if label == "sting" then
        local w, h = 1280, 720
        local sw, sh = size:match("^(%d+)x(%d+)$")
        if sw then w, h = tonumber(sw), tonumber(sh) end
        local restore = fakeWindow(w, h)
        FontManager.clearCache()
        if Menu._resetSting then Menu._resetSting() end
        local menu = Menu:new()
        menu:enterWithIntro()
        local dir = outDir("sting_" .. w .. "x" .. h)
        local fps, total = 20, 6.0
        local t, nextShot, n = 0, 0, 0
        while t <= total + 1e-6 do
            if t >= nextShot - 1e-6 then
                save(render(menu, w, h), dir, ("f_%03d.png"):format(n))
                n = n + 1
                nextShot = n / fps
            end
            step(menu, dt)
            t = t + dt
        end
        restore()
        FontManager.clearCache()
        return true
    end

    local dir = outDir(nil)
    local SaveManager = require("engine.SaveManager")
    local realHasRun = SaveManager.hasRun
    for _, withSave in ipairs({ false, true }) do
        SaveManager.hasRun = function() return withSave end
        for _, sz in ipairs(SIZES) do
            local w, h = sz[1], sz[2]
            local restore = fakeWindow(w, h)
            FontManager.clearCache()
            local menu = Menu:new()
            menu:enterWithIntro()
            for _ = 1, 60 * 7 do step(menu, dt) end
            save(render(menu, w, h), dir, ("%s_%dx%d_%s.png"):format(label, w, h, withSave and "comsave" or "semsave"))
            restore()
        end
    end
    SaveManager.hasRun = realHasRun
    FontManager.clearCache()
    return true
end

return M
