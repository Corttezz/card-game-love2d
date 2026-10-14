local TK = require("tools.testkit")

local M = {}

local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
local function fakeWindow(w, h)
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    require("src.ui.FontManager").clearCache()
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
    require("src.ui.FontManager").clearCache()
end

local function runBoot(seed, sampleAt, drawToo)
    local EM = _G.EventManager
    local BootScene = require("src.scenes.BootScene")
    local done = false
    EM.clear("boot")
    BootScene.init({ onComplete = function() done = true end, seed = seed })
    local samples, spawnTimes, nanSeen = {}, {}, false
    local prevCount = 0
    local maxInFlight = 0
    local t, dt = 0, 1 / 60
    local canvas = drawToo and love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    while not done and t < 20 do
        EM.update(dt)
        BootScene.update(dt)
        t = t + dt
        local n = BootScene.cardsInFlight()
        maxInFlight = math.max(maxInFlight, n)
        local absorbed = BootScene.absorbedCount()
        if n + absorbed > prevCount then
            for _ = 1, n + absorbed - prevCount do spawnTimes[#spawnTimes + 1] = BootScene.splashTime() end
            prevCount = n + absorbed
        end
        for _, p in ipairs(BootScene.cardPositions()) do
            for _, v in ipairs(p) do if v ~= v then nanSeen = true end end
        end
        local st = BootScene.splashTime()
        if BootScene.phase() == "splash" and sampleAt and not samples.done and st >= sampleAt then
            samples.done = true
            samples.poses = BootScene.cardPositions()
        end
        if canvas and math.floor(t * 60) % 30 == 0 then
            love.graphics.push("all")
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 1)
            BootScene.draw()
            love.graphics.pop()
        end
    end
    if canvas then canvas:release() end
    return {
        done = done, t = t, poses = samples.poses or {}, spawnTimes = spawnTimes,
        nan = nanSeen, maxInFlight = maxInFlight, absorbed = BootScene.absorbedCount(),
        inFlightAtEnd = BootScene.cardsInFlight(),
    }
end

local function samePoses(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        for k = 1, 4 do
            if math.abs((a[i][k] or 0) - (b[i][k] or 0)) > 1e-6 then return false end
        end
    end
    return true
end

local function pixelDiff(a, b)
    local n = 0
    local w, h = a:getWidth(), a:getHeight()
    for y = 0, h - 1, 2 do
        for x = 0, w - 1, 2 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            if math.abs(r1 - r2) > 0.004 or math.abs(g1 - g2) > 0.004 or math.abs(b1 - b2) > 0.004 then
                n = n + 1
            end
        end
    end
    return n
end

function M.run()
    local t = TK.new("entrada v14: redemoinho semeado + menu com vida (e estatico em movimento reduzido)")
    TK.bootstrap()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.systems.ScreenShake").install()
    _G.gameSettings = _G.gameSettings or {}
    local savedRM = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = false

    local okRun, err = pcall(function()
        fakeWindow(960, 540)

        local a = runBoot(7, 3.0, true)
        local b = runBoot(7, 3.0, false)
        local c = runBoot(8, 3.0, false)
        t:truthy("boot termina (semente 7)", a.done)
        t:truthy("poses amostradas em t=3.0", #a.poses > 0)
        t:truthy("mesma semente: mesmas poses", samePoses(a.poses, b.poses))
        t:falsy("semente diferente: poses diferentes", samePoses(a.poses, c.poses))
        t:falsy("sem NaN nas poses", a.nan)

        t:eq("34 cartas nasceram", #a.spawnTimes, 34)
        t:eq("34 cartas absorvidas", a.absorbed, 34)
        t:eq("nenhuma carta no ar no fim", a.inFlightAtEnd, 0)
        t:truthy("duracao total razoavel (< 11 s)", a.t < 11)

        local gaps, minG, maxG = {}, math.huge, 0
        for i = 2, #a.spawnTimes do
            local g = a.spawnTimes[i] - a.spawnTimes[i - 1]
            gaps[#gaps + 1] = g
            minG, maxG = math.min(minG, g), math.max(maxG, g)
        end
        t:truthy(("intervalos de nascimento variam (min %.3f, max %.3f)"):format(minG, maxG),
            maxG - minG > 0.05)

        _G.gameSettings.reducedMotion = true
        local r = runBoot(7, 3.0, false)
        t:truthy("movimento reduzido: boot termina", r.done)
        t:eq("movimento reduzido: nenhuma carta nasce", #r.spawnTimes, 0)
        _G.gameSettings.reducedMotion = false

        local Menu = require("components.Menu")
        local fake = { x = 900, y = 500 }
        require("src.ui.InputFocus").installMouseGate(nil, function() return fake.x, fake.y end)
        local menu = Menu:new()
        menu:enterWithIntro()
        for _ = 1, 60 * 5 do _G.EventManager.update(1 / 60); menu:update(1 / 60) end
        local realTime = love.timer.getTime
        local base = realTime()
        local offset = 0
        love.timer.getTime = function() return base + offset end
        local function shot()
            local cv = love.graphics.newCanvas(960, 540)
            love.graphics.push("all")
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            menu:draw()
            love.graphics.pop()
            local d = cv:newImageData()
            cv:release()
            return d
        end
        _G.gameSettings.reducedMotion = true
        for _ = 1, 30 do menu:update(1 / 60) end
        local s1 = shot()
        offset = 0.7
        for _ = 1, 42 do menu:update(1 / 60) end
        local s2 = shot()
        t:eq("menu em movimento reduzido: quadros identicos 0,7 s depois", pixelDiff(s1, s2), 0)
        _G.gameSettings.reducedMotion = false
        for _ = 1, 30 do menu:update(1 / 60) end
        local s3 = shot()
        offset = 1.4
        for _ = 1, 42 do menu:update(1 / 60) end
        local s4 = shot()
        t:truthy("menu com movimento: a cena muda entre quadros", pixelDiff(s3, s4) > 50)
        love.timer.getTime = realTime
    end)
    _G.gameSettings.reducedMotion = savedRM
    restoreWindow()
    t:check("sem excecao" .. (okRun and "" or (": " .. tostring(err))), okRun)
    return t:done()
end

return M
