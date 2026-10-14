-- tools/screenshot_tutorial.lua
-- Captura o NARRADOR do tutorial (src/systems/Tutorial) sobre as telas da
-- jornada — uma PNG por fala da conversa, num tamanho de janela FALSIFICADO.
--
--   love . test_one screenshot_tutorial <cena>:<locale>:<WxH>
--   cenas: rewards · shop · dice · rest · forge · endless · seals · class · mage
--   ex.:   love . test_one screenshot_tutorial shop:de:1920x1080
--
-- Saída (save dir): tut_<cena>_<fala>_<locale>_<W>x<H>.png
-- A batalha (intro, chefe, elite...) captura pelo screenshot_enemy_scene
-- (TUT_TIP=<conversa>:<fala>) e o evento pelo screenshot_event (TUT_TIP).
--
-- `mage`: a 1ª batalha do MAGO pelo GameplayScene real, uma PNG por fala das
-- conversas de orbe (Tutorial.MAGE_CONVERSATIONS), cada uma com o estado que a
-- dispara (orbe do Conduíte, Descarga na mão, 2 orbes canalizados, carta de
-- Evocar, fileira cheia, Foco). Saída em tools/preview_out/tutorial_mago/
-- (gravada por io.open: fora do save dir, pra ficar junto das outras provas).

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
    elseif scene == "mage" then
        return M.mageScene(loc, w, h)
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

-- ===========================================================================
-- MAGO: a batalha real (GameplayScene.draw) com o corvo por cima, fala a fala.
-- ===========================================================================
function M.mageScene(loc, w, h)
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local Tutorial = require("src.systems.Tutorial")
    local EM = require("engine.EventManager")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local game = Game:new()
    game:startNewRun("mage")
    game:startGame()
    _G.game = game
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 1, 2
    run.currentNode = { type = "battle" }
    game.enemy.spriteId = EnemyRenderer.resolveSpriteId(1, "battle")
    if game.messageSystem then game.messageSystem.messages = {} end

    local topBar = TopBar:new()
    topBar:setGame(game)
    local playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar")
    local endTurnButton = Button:new(w * 0.80, h * 0.87, 150, 33, "Encerrar")
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = playButton, endTurnButton = endTurnButton })
    WorldRoad.setBiome(1)
    WorldRoad.setTimeOfDay(0.75, true)
    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end

    local cv = love.graphics.newCanvas(w, h)
    local db = game.deckManager.cardDatabase
    local function instance(id) return db:createCardInstance(db:getCard(id)) end
    local function setHand(ids)
        game.hand = {}
        for _, id in ipairs(ids) do game.hand[#game.hand + 1] = instance(id) end
        game.selectedCards = {}
    end
    -- Assenta a cena (cartas voam até o lugar) sem HandDeal nem cinemática.
    local function settle(frames)
        for _ = 1, frames or 45 do
            EM.update(1 / 30)
            pcall(GameplayScene.update, 1 / 30)
            topBar:update(1 / 30, game)
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            love.graphics.setCanvas()
        end
    end

    local outDir = love.filesystem.getSource() .. "/tools/preview_out/tutorial_mago/"
    local function shot(conv, lineId)
        love.graphics.setCanvas(cv)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()              -- âncoras reportadas aqui
        Tutorial._show(conv, lineId, game)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        Tutorial.draw()
        love.graphics.setCanvas()
        local spot
        for _, l in ipairs(Tutorial.byId(conv).lines) do
            if l.id == lineId then spot = Tutorial.spotRect(l.spot) end
        end
        local name = ("tut_mage_%s_%s_%s_%dx%d.png"):format(conv, lineId, loc, w, h)
        local data = cv:newImageData():encode("png"):getString()
        local f = assert(io.open(outDir .. name, "wb"))
        f:write(data); f:close()
        print(("[screenshot_tutorial] %s  recorte=%s"):format(name,
            spot and ("%d,%d %dx%d"):format(spot.x, spot.y, spot.w, spot.h) or "nenhum"))
        Tutorial._reset()
    end

    -- 1. Conduíte: 1ª luta, orbe de Raio já na fileira, Descarga + Defender na mão
    setHand({ "mage_zap", "defense_001" })
    game.player.orbs = { { type = "lightning", value = 4 } }
    settle()
    shot("conduit", "passive"); shot("conduit", "row"); shot("conduit", "number")
    -- 2. Canalizar: a carta na mão (antes) ...
    shot("channel", "card")
    -- ... e o orbe criado (depois): 2 orbes
    game.player.orbs = { { type = "lightning", value = 4 }, { type = "lightning", value = 5 } }
    setHand({ "defense_001" })
    settle(20)
    for _, line in ipairs({ "made", "oldest", "hover" }) do
        Tutorial.noteEvent("orb_channel", { slot = 2, type = "lightning" })
        shot("channel", line)
    end
    -- 3. Pulso: turno 2, mão nova
    game.battleTurn = 1
    setHand({ "mage_zap", "defense_001" })
    settle(20)
    shot("pulse", "happened"); shot("pulse", "kinds"); shot("pulse", "reveal")
    -- 4. Evocar: Conjuração Dupla (e Fissão pra "todos")
    setHand({ "mage_dualcast", "defense_001", "mage_fission" })
    settle(20)
    shot("evoke_card", "card"); shot("evoke_card", "preview"); shot("evoke_card", "all")
    -- 5. Fileira cheia
    game.player.orbs = { { type = "ice", value = 3 }, { type = "lightning", value = 5 }, { type = "lightning", value = 5 } }
    setHand({ "mage_zap", "defense_001" })
    settle(20)
    shot("overflow", "full"); shot("overflow", "plan")
    -- 6. Foco (ato 3: o Conduíte também dá Foco)
    run.actNumber = 3
    game.player:addBuff("focus", 99, 1)
    settle(20)
    shot("focus", "what"); shot("focus", "conduit")

    Tutorial._reset()
    return true
end

return M
