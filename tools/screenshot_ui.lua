-- tools/screenshot_ui.lua
-- Captura as telas de UI SEM harness próprio (levantamento do redesign UI/UX):
--   love . screenshot_ui menu|class|settings|rest|event|collection|all
-- Salva ui_<tela>.png no save dir. Segue o pipeline de validação visual do
-- memory/balatro_fidelity_directive.md ("ver com os olhos").

local M = {}

-- padrão do screenshot_worldroad "all": loop SÍNCRONO draw→capture→present
-- (encadear present dentro do callback de captura não dispara o próximo)
local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "ui_" .. name .. ".png")
        print("[screenshot] ui_" .. name .. ".png salvo")
    end)
    love.graphics.present()
end

local function simulate(obj, secs)
    for _ = 1, math.floor(secs * 30) do
        obj:update(1 / 30)
    end
end

function M.run(mode)
    mode = mode or "all"
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local shots = {}

    local function addShot(name, fn)
        if mode == "all" or mode == name then
            shots[#shots + 1] = { name = name, fn = fn }
        end
    end

    addShot("menu", function()
        -- Seed TEMPORÁRIO de perfil (plaque só aparece com histórico). Só se
        -- não existe perfil real — removido no fim pra não poluir o do jogador.
        local seeded = false
        if not love.filesystem.getInfo("profile.lua") then
            love.filesystem.write("profile.lua",
                'return { runs = 7, wins = 2, losses = 5, bestAct = 2, bestFloor = 6 }')
            seeded = true
        end
        local Menu = require("components.Menu")
        local menu = Menu:new()
        simulate(menu, 2.4)              -- intro stagger termina
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        if seeded then love.filesystem.remove("profile.lua") end
    end)

    addShot("boot", function()
        -- Splash no auge da cascade (título visível). BootScene é module-level
        -- state — init + simula 2.3s manualmente com EventManager.
        -- BootScene consome _G.EventManager (sem ele, pula direto pro fim).
        local EventManager = require("engine.EventManager")
        _G.EventManager = EventManager
        local BootScene = require("src.scenes.BootScene")
        BootScene.init({ onComplete = function() end })
        local dt = 1 / 60
        -- 2.8s: título já em alpha 1 (ease termina em splash+2.05 = 2.55s
        -- total) e cascade ainda no ar; flash só em splash+2.70.
        for _ = 1, math.floor(2.8 * 60) do
            EventManager.update(dt)
            BootScene.update(dt)
        end
        love.graphics.clear(0, 0, 0, 1)
        BootScene.draw()
    end)

    addShot("class", function()
        local ClassSelectionScreen = require("components.ClassSelectionScreen")
        local cs = ClassSelectionScreen:new()
        cs:show(function() end, function() end)
        simulate(cs, 1.0)
        love.graphics.clear(0, 0, 0, 1)
        cs:draw()
    end)

    addShot("settings", function()
        local Menu = require("components.Menu")
        local SettingsMenu = require("components.SettingsMenu")
        local menu = Menu:new()
        simulate(menu, 2.4)
        local sm = SettingsMenu:new()
        sm:show()
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        sm:draw()
    end)

    addShot("rest", function()
        local RestScreen = require("components.RestScreen")
        local rs = RestScreen:new()
        rs:show(game, function() end)
        simulate(rs, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        rs:draw()
    end)

    addShot("event", function()
        local Events = require("src.data.events")
        local EventScreen = require("components.EventScreen")
        local ev = Events.roll(1)
        -- prefere evento COM ilustração (valida o slot de arte do redesign)
        for _ = 1, 30 do
            if ev and love.filesystem.getInfo(
                "assets/sprites/ui/event_" .. tostring(ev.id) .. ".png") then
                break
            end
            ev = Events.roll(1) or ev
        end
        if not ev then print("[screenshot] sem evento") return end
        local es = EventScreen:new()
        es:show(ev, game, function() end)
        simulate(es, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        es:draw()
    end)

    addShot("deck", function()
        -- Deck Viewer global (F5): deck com cartas variadas + forja no badge
        local run = game.runManager.currentRun
        for _, id in ipairs({ "warrior_strike", "attack_001", "defense_001",
                              "warrior_defend", "mage_zap", "rogue_strike" }) do
            table.insert(run.currentDeck, id)
        end
        game.runManager:upgradeCard("warrior_strike")
        game.runManager:upgradeCard("warrior_strike")
        local DeckViewerScreen = require("components.DeckViewerScreen")
        local dv = DeckViewerScreen:new()
        dv:show(game)
        love.graphics.clear(0.10, 0.14, 0.10, 1)
        dv:draw()
    end)

    addShot("achievements", function()
        -- Galeria de conquistas (F4). Seed em memória: HEADLESS_TOOL impede
        -- gravação no profile.lua real.
        local ProfileStats = require("engine.ProfileStats")
        local s = ProfileStats.get()
        s.achievements = { primeira_pagina = true, relampago = true,
                           miasma = true, grimorio_bolso = true }
        local AchievementsScreen = require("components.AchievementsScreen")
        local as = AchievementsScreen:new()
        as:show(function() end)
        love.graphics.clear(0.05, 0.04, 0.03, 1)
        as:draw()
    end)

    addShot("collection", function()
        local CollectionScreen = require("components.CollectionScreen")
        local cs = CollectionScreen:new()
        cs:show(function() end)
        simulate(cs, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        cs:draw()
    end)

    for _, s in ipairs(shots) do
        local ok, err = pcall(s.fn)
        if ok then
            capture(s.name)
        else
            print("[screenshot] " .. s.name .. " FALHOU: " .. tostring(err))
        end
    end
    love.event.quit()
end

return M
