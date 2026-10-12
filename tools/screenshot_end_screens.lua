-- tools/screenshot_end_screens.lua
-- Captura as telas finais (game over + vitória) em vários idiomas e tamanhos,
-- desenhando num canvas com getWidth/getHeight FALSIFICADOS (o mesmo truque
-- do BOSS_ROOMS_VIRTUAL — setMode maior que o desktop trava).
--
--   love . test_one screenshot_end_screens            → pt_BR + de, 3 tamanhos
--   love . test_one screenshot_end_screens fr         → só um idioma
--
-- Saída: end_<tipo>_<idioma>_<WxH>.png no diretório de save.

local TK = require("tools.testkit")

local M = {}

local SIZES = { {1024, 768}, {1920, 1080}, {2560, 1440} }

function M.run(only)
    TK.bootstrap()
    TK.seedRng(2026)
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    local EndScreens = require("src.scenes.EndScreens")
    local UnlockReveal = require("src.ui.UnlockReveal")
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local FontManager = require("src.ui.FontManager")
    local PS = require("engine.ProfileStats")
    local prevProfile = PS._swapForTests({ runs = 4, wins = 0, losses = 3, bestScore = 4210 })

    -- Run perdida no ato 3 contra o Tirano do Abismo
    local gd = TK.newRunGame("rogue")
    local rd = gd.runManager.currentRun
    rd.actNumber, rd.floorInAct = 3, 8
    rd.currentNode = { type = "boss" }
    rd.turnsTotal, rd.playSeconds = 87, 2710
    rd.jokers = { "a", "b" }
    gd.economySystem.currentGold = 143
    gd.score = 3120
    gd.enemy.spriteId = "abyss_tyrant"
    gd.player.health = 0
    gd:checkGameOver()

    -- Run vencida (6 atos), oferece Endless
    local gv = TK.newRunGame("warrior")
    local rv = gv.runManager.currentRun
    rv.actNumber, rv.floorInAct = Config.TotalActs, MapManager.FLOORS_PER_ACT
    rv.currentNode = { type = "boss" }
    rv.turnsTotal, rv.playSeconds = 214, 5520
    rv.jokers = { "a", "b", "c", "d" }
    gv.economySystem.currentGold = 388
    gv.score = 9850
    gv.enemy.spriteId = "eclipse_queen"
    gv.enemy.health = 0
    gv:checkVictory()

    local locales = only and { only } or { "pt_BR", "de" }
    local realDelta = love.timer.getDelta
    love.timer.getDelta = function() return 1 / 30 end
    UnlockReveal.dtOverride = 1 / 10

    local gw, gh, gdim = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local saved = {}
    for _, loc in ipairs(locales) do
        I18n.setLocale(loc)
        for _, sz in ipairs(SIZES) do
            local w, h = sz[1], sz[2]
            love.graphics.getWidth = function() return w end
            love.graphics.getHeight = function() return h end
            love.graphics.getDimensions = function() return w, h end
            FontManager.clearCache()
            EndScreens.resize()
            local canvas = love.graphics.newCanvas(w, h)
            for _, case in ipairs({ { "gameOver", gd }, { "victory", gv } }) do
                EndScreens._enter(case[1], case[2], 0)
                UnlockReveal.start(case[2].unlockResult)
                for _ = 1, 60 do
                    love.graphics.setCanvas(canvas)
                    love.graphics.clear(0, 0, 0, 1)
                    if case[1] == "victory" then EndScreens.drawVictory(case[2])
                    else EndScreens.drawGameOver(case[2]) end
                    love.graphics.setCanvas()
                end
                local probs = EndScreens.validate()
                local name = ("end_%s_%s_%dx%d.png"):format(case[1], loc, w, h)
                canvas:newImageData():encode("png", name)
                saved[#saved + 1] = name
                print(("[end_screens] %s  problemas=%d%s"):format(name, #probs,
                    #probs > 0 and (" (" .. probs[1] .. ")") or ""))
            end
        end
    end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = gw, gh, gdim
    love.timer.getDelta = realDelta
    UnlockReveal.dtOverride = nil
    PS._swapForTests(prevProfile)
    require("engine.SaveManager").deleteRun()
    print("[end_screens] salvos em " .. love.filesystem.getSaveDirectory())
    return #saved > 0
end

return M
