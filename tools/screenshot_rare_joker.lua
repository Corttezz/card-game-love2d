local M = {}

function M.run()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    local DissolveShader = require("src.ui.DissolveShader")
    DissolveShader.load()
    local EventManager = require("engine.EventManager")
    local CardParticles = require("src.systems.CardParticles")
    local CardRewardScreen = require("components.CardRewardScreen")
    local Config = require("src.core.Config")
    local Game = require("src.core.Game")

    local odds = Config.Offers.REWARD_JOKER_CHANCE
    local saved = odds.battle
    odds.battle = 1

    local outDir = love.filesystem.getSource() .. "/tools/preview_out/coringa_raro/"
    os.execute('mkdir "' .. outDir:gsub("/", "\\") .. '" 2>nul')

    local w, h = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(w, h)

    local function session(tag, reduced, marks)
        _G.gameSettings = _G.gameSettings or {}
        _G.gameSettings.reducedMotion = reduced
        TK.seedRng(4040)
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        local screen = CardRewardScreen:new(game.shopSystem)
        screen.lastScreenWidth, screen.lastScreenHeight = w, h
        screen:show(game, function() end, function() end, "rewards")

        local function frame()
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setColor(0.16, 0.12, 0.08, 1)
            love.graphics.rectangle("fill", 0, 0, w, h)
            love.graphics.setColor(0.30, 0.22, 0.12, 1)
            love.graphics.rectangle("fill", 0, h * 0.6, w, h * 0.4)
            love.graphics.setColor(1, 1, 1, 1)
            screen:draw()
            CardParticles.draw()
            love.graphics.setCanvas()
        end

        local t, dt, mi = 0, 1 / 60, 1
        while mi <= #marks do
            EventManager.update(dt)
            CardParticles.update(dt)
            screen:update(dt)
            frame()
            t = t + dt
            if t >= marks[mi] then
                local name = ("%s_%02d_t%.2f.png"):format(tag, mi, marks[mi])
                local f = assert(io.open(outDir .. name, "wb"))
                f:write(cv:newImageData():encode("png"):getString())
                f:close()
                print("[screenshot_rare_joker] " .. outDir .. name)
                mi = mi + 1
            end
        end
        local jokers = 0
        for _, o in ipairs(screen.shopOffers) do
            if o._rareReveal then jokers = jokers + 1 end
        end
        print(("[screenshot_rare_joker] %s: %d coringa(s) com revelacao"):format(tag, jokers))
        screen:hide()
    end

    session("movimento", false, { 0.55, 1.25, 1.55, 1.75, 1.95, 2.3, 3.6 })
    session("reduzido", true, { 0.6, 2.4 })

    odds.battle = saved
    return true
end

return M
