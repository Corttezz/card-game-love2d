-- tools/screenshot_discovery.lua
-- Carta INÉDITA na vitrine (src/ui/DiscoveryMark.lua): recompensa, loja e
-- pacote, cada um em dois instantes — no meio da varredura de luz e em
-- repouso (só o marcador "NOVA") — mais a recompensa com reducedMotion.
--
--   DISC_SIZE=1920x1080 love . test_one screenshot_discovery
--   DISC_LOCALE=fr ...   (marcador mais largo: "NOUVELLE")
--
-- Grava disc_<WxH>_<cena>_<instante>.png no save dir. O relógio do
-- DiscoveryMark é trocado pelo tempo SIMULADO: o instante da captura é
-- exato, não depende da velocidade da máquina.
local M = {}

function M.run()
    local sw, sh = (os.getenv("DISC_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh), { resizable = true }) end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    if os.getenv("DISC_LOCALE") then I18n.setLocale(os.getenv("DISC_LOCALE")) end
    require("src.ui.PixelCanvas").enableNearest()
    require("src.ui.CRTShader").load()
    require("src.ui.DissolveShader").load()
    require("src.ui.FlashShader").load()
    require("src.ui.BoosterShader").load()
    require("src.systems.ScreenShake").install()

    local EventManager = require("engine.EventManager")
    local CardParticles = require("src.systems.CardParticles")
    local FloatingText = require("src.ui.FloatingText")
    local DiscoveryMark = require("src.ui.DiscoveryMark")
    local Game = require("src.core.Game")
    local CardRewardScreen = require("components.CardRewardScreen")
    local PackOpenScreen = require("components.PackOpenScreen")
    local BoosterPackSystem = require("src.systems.BoosterPackSystem")
    local Rng = require("src.systems.Rng")

    local simT = 0
    DiscoveryMark.clock = function() return simT end
    _G.gameSettings = _G.gameSettings or {}

    local W, H = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(W, H)
    local size = W .. "x" .. H

    local function drawScene(screen)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.05, 0.04, 0.08, 1)
        love.graphics.setColor(0.18, 0.13, 0.09, 1)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(1, 1, 1, 1)
        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
        love.graphics.setCanvas()
    end
    -- O draw de cada quadro importa: é nele que a carta "aparece" e a
    -- revelação começa (pacote: só depois de materializar).
    local function simulate(screen, secs)
        local dt, t = 1 / 60, 0
        while t < secs do
            EventManager.update(dt)
            CardParticles.update(dt)
            FloatingText.update(dt)
            screen:update(dt)
            simT = simT + dt
            t = t + dt
            drawScene(screen)
        end
    end
    local function shoot(screen, name)
        drawScene(screen)
        local path = ("disc_%s_%s.png"):format(size, name)
        canvas:newImageData():encode("png", path)
        print("[screenshot_discovery] " .. path)
    end
    -- Instante da 1ª revelação: meio da faixa / repouso
    local MID = DiscoveryMark.SWEEP_DELAY + DiscoveryMark.SWEEP_DUR * 0.45

    local function newGame()
        EventManager.clear(); CardParticles.clear(); FloatingText.clear()
        DiscoveryMark.reset()
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        game.messageSystem = nil
        if game.economySystem then game.economySystem.currentGold = 40 end
        _G.game = game
        Rng.setActive(Rng.new(4242))
        return game
    end

    -- Recompensa / loja: o caminho real — offer.isNew → createCardInstances.
    local function offerScene(mode, newSlots, tag, reduced)
        local game = newGame()
        _G.gameSettings.reducedMotion = reduced or nil
        local screen = CardRewardScreen:new(game.shopSystem)
        screen.lastScreenWidth, screen.lastScreenHeight = W, H
        screen:show(game, function() end, function() end, mode)
        local n = 0
        for _, o in ipairs(screen.shopOffers or {}) do
            if o.type == "card" then
                n = n + 1
                o.isNew = newSlots[n] or nil
            end
        end
        screen:createCardInstances()
        -- a revelação começa no 1º draw: espera a entrada e mede dali
        simulate(screen, 0.02)
        simulate(screen, MID - 0.02)
        shoot(screen, tag .. "_sweep")
        simulate(screen, 2.4)
        shoot(screen, tag .. "_rest")
        _G.gameSettings.reducedMotion = nil
    end

    offerScene("rewards", { true, false, true }, "rewards")
    offerScene("shop", { true, false, false, true }, "shop")
    offerScene("rewards", { true, false, true }, "rewards_reduced", true)

    -- Pacote: generateContents marca isNewDiscovery na carta inédita; aqui
    -- forçamos 2 de 3 (o perfil do tool pode já ter visto todas).
    do
        newGame()
        local pack = BoosterPackSystem.expandPackRecord({
            id = "pack_standard", kind = "Standard", size = 3, choose = 1,
        }, "warrior")
        pack.instances[1].isNewDiscovery = true
        pack.instances[3].isNewDiscovery = true
        local screen = PackOpenScreen:new()
        screen:show(pack, function() end)
        -- 1.3s até as cartas nascerem + materialize; captura logo depois
        -- que a 1ª carta revela e com tudo em repouso
        local t0
        local dt = 1 / 60
        for _ = 1, 600 do
            simulate(screen, dt)
            local c = pack.instances[1]
            if not t0 and c.dissolve ~= nil and c.dissolve < 0.2 and (c.dissolve or 1) <= 0.2 then
                t0 = simT
            end
            if t0 and simT - t0 >= MID then break end
        end
        shoot(screen, "pack_sweep")
        simulate(screen, 2.4)
        shoot(screen, "pack_rest")
    end

    DiscoveryMark.clock = love.timer.getTime
    return true
end

return M
