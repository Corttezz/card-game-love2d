-- tools/screenshot_unlocks.lua
-- Capturas da META-PROGRESSÃO (UnlockSystem):
--   unlocks_reveal_mid.png   — tela de derrota com a barra de maestria enchendo
--   unlocks_reveal_end.png   — mesma tela com cartas/classe já reveladas
--   unlocks_victory_end.png  — vitória (vários níveis + classe nova)
--   unlocks_collection.png   — Coleção de um perfil novo (maioria "?")
--   unlocks_collection_hover.png — tooltip de carta bloqueada
-- Roda: love . screenshot_unlocks
-- Perfil é FALSO (ProfileStats._swapForTests) — nada toca o disco.

local M = {}

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[screenshot_unlocks] " .. name)
    end)
    love.graphics.present()
end

function M.run()
    local EventManager = require("engine.EventManager")
    _G.EventManager = EventManager
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local ProfileStats = require("engine.ProfileStats")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local UnlockReveal = require("src.ui.UnlockReveal")
    local EndScreens = require("src.scenes.EndScreens")
    UnlockSystem.setOverrideAll(false)

    -- ===== 1) Derrota no ato 2: sobe 1 nível, libera pacote + mago =====
    local prev = ProfileStats._swapForTests({ runs = 0 })
    UnlockSystem.ensure()
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    game.score = 3120
    UnlockSystem.onBossDefeated(2, game)   -- mago libera no meio da run
    game.unlockResult = UnlockSystem.onRunEnded({
        classId = "warrior", victory = false, actNumber = 3, floorInAct = 2 })

    UnlockReveal.dtOverride = 1 / 60
    local function run(fn, secs, shotName)
        local steps = math.floor(secs * 60)
        for _ = 1, steps do
            EventManager.update(1 / 60)
            love.graphics.clear(0, 0, 0, 1)
            fn(game)
        end
        capture(shotName)
    end
    run(EndScreens.drawGameOver, 1.3, "unlocks_reveal_mid.png")
    run(EndScreens.drawGameOver, 3.5, "unlocks_reveal_late.png")
    UnlockReveal.finish()
    run(EndScreens.drawGameOver, 0.6, "unlocks_reveal_end.png")

    -- ===== 2) Vitória: vários níveis + ladino =====
    game.unlockResult = UnlockSystem.onRunEnded({
        classId = "warrior", victory = true, actNumber = 3, floorInAct = 8 })
    run(EndScreens.drawVictory, 0.2, "unlocks_victory_start.png")
    UnlockReveal.finish()
    run(EndScreens.drawVictory, 0.6, "unlocks_victory_end.png")
    UnlockReveal.dtOverride = nil

    -- ===== 3) Coleção de perfil novo =====
    ProfileStats._swapForTests({ runs = 0 })
    UnlockSystem.ensure()
    for _, id in ipairs({ "warrior_strike", "warrior_defend", "warrior_bash",
        "warrior_iron_wave", "attack_cleave", "warrior_twin_strike" }) do
        UnlockSystem.markDiscovered(id)
    end
    local CollectionScreen = require("components.CollectionScreen")
    local screen = CollectionScreen:new()
    screen:show(function() end)
    local guard = 0
    while not screen._buildDone and guard < 2000 do
        screen:_buildInstances(0.05); guard = guard + 1
    end
    screen:_applyFilter()
    local origPos = love.mouse.getPosition
    love.mouse.getPosition = function() return 2, 2 end
    for _ = 1, 30 do screen:update(1 / 60) end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("unlocks_collection.png")

    -- hover numa carta bloqueada (procura a 1ª oculta+bloqueada visível)
    local W = love.graphics.getWidth()
    local ox = (W - (5 * 128 + 4 * 18)) / 2
    for i, inst in ipairs(screen.filtered) do
        if inst._hidden and inst._locked and i <= 10 then
            local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
            local mx, my = ox + col * 146 + 64, 120 + row * 216 + 96
            love.mouse.getPosition = function() return mx, my end
            break
        end
    end
    for _ = 1, 30 do screen:update(1 / 60) end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("unlocks_collection_hover.png")
    love.mouse.getPosition = origPos

    ProfileStats._swapForTests(prev)
    love.event.quit()
    return true
end

return M
