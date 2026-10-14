-- tools/screenshot_tutorial.lua
-- Captura o NARRADOR do tutorial (src/systems/Tutorial) sobre as telas da
-- jornada — uma PNG por fala da conversa, num tamanho de janela FALSIFICADO.
--
--   love . test_one screenshot_tutorial <cena>:<locale>:<WxH>
--   cenas: rewards · shop · dice · rest · forge · endless · seals · class
--   ex.:   love . test_one screenshot_tutorial shop:de:1920x1080
--
-- Saída (save dir): tut_<cena>_<fala>_<locale>_<W>x<H>.png
-- A batalha (intro, chefe, elite...) captura pelo screenshot_enemy_scene
-- (TUT_TIP=<conversa>:<fala>) e o evento pelo screenshot_event (TUT_TIP).

local M = {}

function M.run(arg)
    local scene, loc, w, h = (arg or "rewards:pt_BR:1024x768"):match("^(%w+):([%w_]+):(%d+)x(%d+)$")
    scene, loc = scene or "rewards", loc or "pt_BR"
    w, h = tonumber(w) or 1024, tonumber(h) or 768
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(loc, true)
    require("src.ui.PixelCanvas").enableNearest()
    for _, sh in ipairs({ "CRTShader", "DissolveShader", "FlashShader", "BoosterShader",
        "FoilShader", "PolychromeShader" }) do
        pcall(function() require("src.ui." .. sh).load() end)
    end

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    if game.economySystem then game.economySystem.currentGold = 30 end
    require("src.systems.Rng").setActive(require("src.systems.Rng").new(4242))
    local Tutorial = require("src.systems.Tutorial")
    local EM = require("engine.EventManager")
    local topBar = require("components.TopBar"):new()
    topBar:setGame(game)

    local screen, convId, drawScreen
    local dice = require("components.ScribeDiceScreen"):new()
    _G.openScribeDice = function(g, cb) dice:show(g, cb) end

    if scene == "rewards" or scene == "shop" or scene == "dice" then
        screen = require("components.CardRewardScreen"):new(game.shopSystem)
        screen:show(game, function() end, function() end, scene == "rewards" and "rewards" or "shop")
        convId = scene
        drawScreen = function()
            screen:draw(); topBar:draw()
            if dice:isVisible() then dice:draw() end
        end
        if scene == "dice" then dice:show(game, function() end) end
        Tutorial.setScreens({ cardReward = screen, dice = dice })
    elseif scene == "rest" or scene == "forge" then
        screen = require("components.RestScreen"):new()
        screen:show(game, function() end, scene == "forge" and "forge" or nil)
        convId = scene
        drawScreen = function() screen:draw(); topBar:draw() end
        Tutorial.setScreens({ rest = screen })
    elseif scene == "endless" then
        local Config = require("src.core.Config")
        local RM = require("src.systems.RunModifiers")
        local run = game.runManager.currentRun
        run.actNumber, run.floorInAct = Config.TotalActs, 8
        run.currentFloor = Config.TotalActs * 8
        run.campaignWon = true
        game.runManager:advanceFloorInAct()
        screen = require("components.EndlessCurseScreen"):new()
        screen:show(game)
        convId = "endless"
        drawScreen = function() topBar:draw(); screen:draw() end
        Tutorial.setScreens({ endless = screen })
        assert(RM.pending(run), "sem maldição pendente")
    elseif scene == "class" then
        -- 1ª visita de verdade: perfil novo, sem o override de ferramenta
        -- (mago e ladino acorrentados)
        local US = require("src.systems.UnlockSystem")
        require("engine.ProfileStats")._swapForTests({ runs = 0, wins = 0 })
        US.setOverrideAll(false)
        US._resetForTests()
        screen = require("components.ClassSelectionScreen"):new()
        screen:show(function() end, function() end)
        convId = "class_select"
        drawScreen = function() screen:draw() end
    elseif scene == "seals" then
        local CSS = require("components.ClassSelectionScreen")
        CSS._sealCap = function() return 3 end   -- selos já liberados
        screen = CSS:new()
        screen:show(function() end, function() end)
        convId = "seals"
        drawScreen = function() screen:draw() end
    else
        print("[screenshot_tutorial] cena desconhecida: " .. tostring(scene))
        return false
    end

    -- assenta as entradas (slide/fade) como no jogo
    for _ = 1, 90 do
        EM.update(1 / 60)
        if screen.update then screen:update(1 / 60) end
        topBar:update(1 / 60, game)
        if dice:isVisible() then dice:update(1 / 60) end
    end

    local def = Tutorial.byId(convId)
    for _, line in ipairs(def.lines) do
        local cv = love.graphics.newCanvas(w, h)
        love.graphics.setCanvas(cv)
        love.graphics.origin()
        love.graphics.clear(0.18, 0.13, 0.09, 1)
        drawScreen()              -- 1ª passada: as âncoras são reportadas
        Tutorial._show(convId, line.id, game)
        if os.getenv("TUT_DEBUG") then
            local r = Tutorial.spotRect(line.spot)
            print("[dbg] spot", line.id, r and r.x, r and r.y, r and r.w, r and r.h)
            for i, o in ipairs(screen.shopOffers or {}) do
                local p = (o._slot and screen.cardPositions[o._slot]) or screen.cardPositions[i]
                print("[dbg] offer", i, o._slot, p and p.x, p and p.y, p and p.w, p and p.h)
            end
        end
        love.graphics.clear(0.18, 0.13, 0.09, 1)
        drawScreen()
        Tutorial.draw()
        love.graphics.setCanvas()
        local name = ("tut_%s_%s_%s_%dx%d.png"):format(convId, line.id, loc, w, h)
        cv:newImageData():encode("png", name)
        print("[screenshot_tutorial] " .. name)
    end
    Tutorial._reset()
    return true
end

return M
