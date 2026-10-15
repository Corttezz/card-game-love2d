local M = {}

local BOSS = "abyss_tyrant"

local function outDir()
    local d = love.filesystem.getSource() .. "/tools/preview_out/brilho_coringa/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function save(cv, dir, name)
    local f = assert(io.open(dir .. name, "wb"))
    f:write(cv:newImageData():encode("png"):getString())
    f:close()
    print("[screenshot_brilho_coringa] " .. dir .. name)
end

local function bossMiddle(game)
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
    return function() ss.getCurrentOffers = real end
end

local function rewardSession(dir, tag, cv, w, h, marks, reduced)
    local TK = require("tools.testkit")
    local EventManager = require("engine.EventManager")
    local CardParticles = require("src.systems.CardParticles")
    local CardRewardScreen = require("components.CardRewardScreen")
    local Game = require("src.core.Game")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = reduced
    TK.seedRng(4040)
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    game.runManager.currentRun.currentNode = { type = "boss", enemyId = BOSS }
    local restore = bossMiddle(game)
    local screen = CardRewardScreen:new(game.shopSystem)
    screen.lastScreenWidth, screen.lastScreenHeight = w, h
    screen:show(game, function() end, function() end, "rewards")
    local t, dt, mi = 0, 1 / 60, 1
    while mi <= #marks do
        EventManager.update(dt)
        CardParticles.update(dt)
        screen:update(dt)
        love.graphics.setCanvas(cv)
        love.graphics.origin()
        love.graphics.clear(0.16, 0.12, 0.08, 1)
        love.graphics.setColor(1, 1, 1, 1)
        screen:draw()
        CardParticles.draw()
        love.graphics.setCanvas()
        t = t + dt
        if t >= marks[mi].t then
            save(cv, dir, ("%s_%s.png"):format(tag, marks[mi].name))
            mi = mi + 1
        end
    end
    screen:hide()
    restore()
end

local function trophySession(dir, tag, cv, w, h)
    local BossTrophy = require("src.ui.BossTrophy")
    local BossJokers = require("src.systems.BossJokers")
    local Data = require("src.data.boss_trophy")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    love.math.setRandomSeed(77)
    local T = Data.timing
    local marks = {
        { t = T.delay * 0.7, name = "trofeu_1_emerge" },
        { t = T.delay + T.rise * 0.6, name = "trofeu_2_subindo" },
        { t = T.delay + T.rise + T.settle + 0.2, name = "trofeu_3_revelado" },
        { t = T.delay + T.rise + T.settle + 1.2, name = "trofeu_4_parado" },
    }
    BossTrophy.start({ card = BossJokers.cardFor(BOSS), boss = BOSS, dur = Data.step.dur }, nil, false)
    local t, dt, mi = 0, 1 / 60, 1
    while mi <= #marks do
        BossTrophy.update(dt)
        t = t + dt
        if t >= marks[mi].t then
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            love.graphics.clear(0.10, 0.07, 0.06, 1)
            love.graphics.setColor(0.22, 0.14, 0.10, 1)
            love.graphics.rectangle("fill", 0, h * 0.62, w, h * 0.38)
            love.graphics.setColor(1, 1, 1, 1)
            BossTrophy.draw()
            love.graphics.setCanvas()
            save(cv, dir, ("%s_%s.png"):format(tag, marks[mi].name))
            mi = mi + 1
        end
    end
    BossTrophy.stop()
end

local function showcaseSession(dir, tag, cv, w, h)
    local PS = require("engine.ProfileStats")
    local UQ = require("src.systems.UnlockQueue")
    local Showcase = require("components.UnlockShowcase")
    local prev = PS._swapForTests({ runs = 3, wins = 1, losses = 2 })
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    UQ.clear()
    UQ.push({ kind = "achievement", id = "primeiro_chefe" })
    local s = Showcase:new()
    s:watch("menu", 1)
    for _ = 1, 45 do s:update(1 / 30) end
    love.graphics.setCanvas(cv)
    love.graphics.origin()
    love.graphics.clear(0.10, 0.07, 0.06, 1)
    s:draw()
    love.graphics.setCanvas()
    save(cv, dir, tag .. "_conquista_referencia.png")
    s:hide()
    UQ.clear()
    PS._swapForTests(prev)
end

function M.run()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.ui.DissolveShader").load()
    require("src.ui.HoloShader").load()
    local tag = os.getenv("BRILHO_TAG") or "atual"
    local dir = outDir()
    local w, h = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(w, h)
    trophySession(dir, tag, cv, w, h)
    rewardSession(dir, tag, cv, w, h, {
        { t = 1.55, name = "revelacao_1_carga" },
        { t = 1.85, name = "revelacao_2_explosao" },
        { t = 2.6, name = "revelacao_3_assentando" },
        { t = 6.0, name = "escolha" },
    }, false)
    rewardSession(dir, tag .. "_reduzido", cv, w, h, { { t = 4.0, name = "escolha" } }, true)
    showcaseSession(dir, tag, cv, w, h)
    return true
end

return M
