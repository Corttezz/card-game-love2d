local TK = require("tools.testkit")

local M = {}

local BOSS = "abyss_tyrant"
local INSET = 6

local function openBossMiddle(reduced)
    local EventManager = require("engine.EventManager")
    local Game = require("src.core.Game")
    local CardRewardScreen = require("components.CardRewardScreen")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = reduced
    TK.seedRng(4040)
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    game.runManager.currentRun.currentNode = { type = "boss", enemyId = BOSS }
    local ss = game.shopSystem
    local real = ss.getCurrentOffers
    ss.getCurrentOffers = function(self)
        local offers = real(self)
        local bi
        for i, o in ipairs(offers) do if o.bossJoker then bi = i end end
        local mid = math.floor((#offers + 1) / 2)
        if bi and bi ~= mid then offers[bi], offers[mid] = offers[mid], offers[bi] end
        return offers
    end
    local screen = CardRewardScreen:new(ss)
    screen.lastScreenWidth, screen.lastScreenHeight = love.graphics.getDimensions()
    screen:show(game, function() end, function() end, "rewards")
    ss.getCurrentOffers = real
    for _ = 1, 60 * 5 do
        EventManager.update(1 / 60)
        screen:update(1 / 60)
    end
    return screen
end

local function frame(cv, screen)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.origin()
    love.graphics.clear(0.10, 0.08, 0.06, 1)
    love.graphics.setColor(1, 1, 1, 1)
    screen:draw()
    love.graphics.pop()
    return cv:newImageData()
end

local function diffIn(a, b, x0, y0, x1, y1)
    local n = 0
    x0, y0 = math.max(0, math.floor(x0)), math.max(0, math.floor(y0))
    x1 = math.min(a:getWidth() - 1, math.floor(x1))
    y1 = math.min(a:getHeight() - 1, math.floor(y1))
    for y = y0, y1 do
        for x = x0, x1 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 1e-4 then n = n + 1 end
        end
    end
    return n
end

local function rectDist(cx, cy, r)
    local dx = math.max(r.x - cx, 0, cx - (r.x + r.w))
    local dy = math.max(r.y - cy, 0, cy - (r.y + r.h))
    return math.sqrt(dx * dx + dy * dy)
end

local function neighborChecks(t, reduced)
    local RareReveal = require("src.ui.RareReveal")
    local tag = reduced and "reduzido" or "movimento"
    local screen = openBossMiddle(reduced)
    local special, specialSt, neighbors = nil, nil, {}
    for _, inst in ipairs(screen.cardInstances) do
        local o = inst.shopOffer
        if o and o.bossJoker then special, specialSt = inst, o._rareReveal
        else neighbors[#neighbors + 1] = inst end
    end
    t:truthy(tag .. ": coringa do chefe no meio, com revelacao", special and specialSt
        and special.shopOffer._slot == 2)
    t:truthy(tag .. ": duas cartas vizinhas", #neighbors == 2)
    if not (special and specialSt) then return end

    local w, h = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(w, h)
    local realBack = RareReveal.drawBack
    local withFx = frame(cv, screen)
    RareReveal.drawBack = function() end
    local without = frame(cv, screen)
    RareReveal.drawBack = realBack
    cv:release()

    local sr = special._drawRect
    local p = RareReveal.haloParams(specialSt, sr.w, sr.h)
    local cx, cy = sr.x + sr.w / 2, sr.y + sr.h / 2
    local total = diffIn(withFx, without, 0, 0, w - 1, h - 1)
    t:truthy(tag .. ": o brilho aparece na tela (" .. total .. " px)", total > 0)
    for i, nb in ipairs(neighbors) do
        local r = nb._drawRect
        t:truthy(tag .. (": brilho alcanca a vizinha %d (teste nao e vazio)"):format(i),
            p and rectDist(cx, cy, r) < p.r * 0.9)
        local d = diffIn(withFx, without, r.x + INSET, r.y + INSET, r.x + r.w - INSET, r.y + r.h - INSET)
        t:eq(tag .. (": nenhum pixel da vizinha %d muda com o brilho do coringa"):format(i), d, 0)
    end
    screen:hide()
end

local function src(path)
    return love.filesystem.read(path) or ""
end

local function sharedChecks(t)
    local RevealGlow = require("src.ui.RevealGlow")
    local RareReveal = require("src.ui.RareReveal")
    local BossTrophy = require("src.ui.BossTrophy")
    local BossJokers = require("src.systems.BossJokers")

    for _, path in ipairs({ "src/ui/RareReveal.lua", "src/ui/BossTrophy.lua", "components/UnlockShowcase.lua" }) do
        local s = src(path)
        t:truthy(path .. " usa o brilho de conquista compartilhado (RevealGlow)",
            s:find('require("src.ui.RevealGlow")', 1, true) ~= nil)
        t:falsy(path .. " nao carrega o shader do palco por conta propria", s:find("reveal_stage", 1, true))
    end
    for _, path in ipairs({ "src/ui/RareReveal.lua", "src/ui/BossTrophy.lua" }) do
        local s = src(path)
        t:falsy(path .. ": sem raio vetorial (polygon)", s:find("polygon(", 1, true))
        t:falsy(path .. ": sem camada pixelada em blocos", s:find("pixelLayer", 1, true) or s:find("PIX", 1, true))
        t:falsy(path .. ": sem disco/anel em degraus", s:find('circle("', 1, true))
        t:falsy(path .. ": sem retangulo de brilho em volta", s:find('rectangle("line"', 1, true))
    end
    t:eq("RareReveal sem camada de frente (nada por cima das vizinhas)", RareReveal.drawFront, nil)

    local cv = love.graphics.newCanvas(320, 320)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)

    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    local st = RareReveal.new({ delay = 0 })
    RareReveal.update(st, 2.5, 120, 180)
    RevealGlow.drawn = 0
    RareReveal.drawBack(st, 160, 160, 120, 180)
    t:truthy("revelacao rara desenha o brilho de conquista", RevealGlow.drawn > 0)
    local stR = RareReveal.new({ delay = 0, reduced = true })
    RareReveal.update(stR, 1.0, 120, 180)
    local pR = RareReveal.haloParams(stR, 120, 180)
    t:truthy("reduzido: destaque parado fica (sem movimento, alpha > 0)", pR and not pR.motion and pR.alpha > 0)

    for _, reduced in ipairs({ false, true }) do
        BossTrophy.start({ card = BossJokers.cardFor(BOSS), boss = BOSS, dur = 4.4 }, nil, reduced)
        for _ = 1, 150 do BossTrophy.update(1 / 60) end
        RevealGlow.drawn = 0
        BossTrophy.draw()
        t:truthy(("trofeu do chefe (%s) desenha o brilho de conquista"):format(reduced and "reduzido" or "movimento"),
            RevealGlow.drawn > 0)
        BossTrophy.stop()
    end
    love.graphics.pop()
    cv:release()
end

function M.run()
    local t = TK.new("brilho do coringa = brilho de conquista, sempre por baixo das vizinhas")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.ui.DissolveShader").load()
    require("src.ui.HoloShader").load()
    t:truthy("shader do brilho carrega", require("src.ui.RevealGlow").shader() ~= nil)
    local realTime, realMouse = love.timer.getTime, love.mouse.getPosition
    local savedReduced = _G.gameSettings and _G.gameSettings.reducedMotion
    love.mouse.getPosition = function() return -500, -500 end
    local ok, err = pcall(function()
        love.timer.getTime = function() return 41.3 end
        neighborChecks(t, false)
        neighborChecks(t, true)
        sharedChecks(t)
    end)
    love.timer.getTime, love.mouse.getPosition = realTime, realMouse
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = savedReduced
    t:truthy("sem erro: " .. tostring(err), ok)
    return t:done()
end

return M
