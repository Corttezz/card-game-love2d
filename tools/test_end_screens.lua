local TK = require("tools.testkit")

local M = {}

local SIZES = { {1024, 768}, {1280, 720}, {1366, 768}, {1920, 1080}, {2560, 1440} }
local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function withSize(w, h, fn)
    local gw, gh, gd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    local ok, err = pcall(fn)
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = gw, gh, gd
    if not ok then error(err, 0) end
end

local function center(b) return b.x + b.w / 2, b.y + b.h / 2 end

function M.run()
    local t = TK.new("end screens")
    TK.bootstrap()
    TK.seedRng(777)
    local I18n = require("src.i18n.I18n")
    local EndScreens = require("src.scenes.EndScreens")
    local PS = require("engine.ProfileStats")
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local prevProfile = PS._swapForTests({ runs = 1, wins = 0, losses = 0 })
    local prevLocale = I18n.current

    local ok, err = pcall(function()
        local gv = TK.newRunGame("warrior")
        local rv = gv.runManager.currentRun
        rv.actNumber, rv.floorInAct = Config.TotalActs, MapManager.FLOORS_PER_ACT
        rv.currentNode = { type = "boss" }
        gv.enemy.health = 0
        gv:checkVictory()
        local gd = TK.newRunGame("mage")
        gd.enemy.spriteId = "tower_lich"
        gd.player.health = 0
        gd:checkGameOver()

        local calls = {}
        EndScreens.setCallbacks({
            onRetry = function() calls[#calls + 1] = "retry" end,
            onMenu = function() calls[#calls + 1] = "menu" end,
            onEndless = function() calls[#calls + 1] = "endless" end,
        })

        for _, loc in ipairs(LOCALES) do
            I18n.setLocale(loc)
            for _, sz in ipairs(SIZES) do
                withSize(sz[1], sz[2], function()
                    for _, case in ipairs({ { "victory", gv }, { "gameOver", gd } }) do
                        local L = EndScreens.layout(case[1], case[2])
                        local probs = EndScreens.validate(L)
                        t:eq(("%s %s %dx%d: layout valido%s"):format(loc, case[1], sz[1], sz[2],
                            #probs > 0 and (" — " .. probs[1]) or ""), #probs, 0)
                    end
                end)
            end
        end
        I18n.setLocale("pt_BR")

        for _, loc in ipairs(LOCALES) do
            I18n.setLocale(loc)
            local miss = {}
            for _, k in ipairs({ "defeat_title", "retry", "menu", "endless", "label_class",
                "label_killed_by", "reached_endless", "enemy.tower_lich", "enemy.eclipse_queen" }) do
                local v = I18n.t("end_screen." .. k)
                if v == "end_screen." .. k then miss[#miss + 1] = k end
            end
            t:eq(loc .. ": chaves end_screen presentes" .. (#miss > 0 and (" (falta " .. miss[1] .. ")") or ""),
                #miss, 0)
        end
        I18n.setLocale("pt_BR")
        t:truthy("pt_BR: titulo da derrota NAO e mais o ingles 'GAME OVER'",
            I18n.t("end_screen.defeat_title") ~= "GAME OVER")

        local sum = EndScreens.summary("gameOver", gd)
        t:eq("resumo tem 8 celulas", #sum.cells, 8)
        t:truthy("subtitulo nomeia quem matou", sum.subtitle:find(I18n.t("end_screen.enemy.tower_lich"), 1, true))
        local sumV = EndScreens.summary("victory", gv)
        t:eq("vitoria: desfecho = Vitoria", sumV.cells[3].value, I18n.t("end_screen.fate_victory"))
        t:eq("tempo formatado", EndScreens.formatTime(3725), "1:02:05")
        t:eq("tempo curto", EndScreens.formatTime(75), "1:15")

        withSize(1024, 768, function()
            EndScreens._enter("victory", gv, 0)
            EndScreens.keypressed("return")
            t:eq("tecla no instante da entrada e ignorada", #calls, 0)

            EndScreens._enter("victory", gv, 1)
            local L = EndScreens._state().layout
            t:eq("vitoria tem 3 botoes", #L.buttons, 3)
            t:eq("foco inicial no Endless (primario)", EndScreens.focusedKey(), "endless")
            EndScreens.keypressed("right")
            t:eq("seta direita move o foco", EndScreens.focusedKey(), "retry")
            EndScreens.keypressed("right"); EndScreens.keypressed("right")
            t:eq("foco da a volta", EndScreens.focusedKey(), "endless")
            EndScreens.keypressed("left")
            t:eq("seta esquerda volta (com wrap)", EndScreens.focusedKey(), "menu")
            EndScreens.keypressed("return")
            t:eq("Enter ativa o focado", calls[#calls], "menu")
            EndScreens._enter("victory", gv, 1)
            EndScreens.keypressed("space")
            t:eq("Espaco confirma o primario (Endless)", calls[#calls], "endless")
            EndScreens.keypressed("r")
            t:eq("R = tentar de novo", calls[#calls], "retry")
            EndScreens.keypressed("escape")
            t:eq("ESC = menu principal", calls[#calls], "menu")

            EndScreens._enter("gameOver", gd, 1)
            t:eq("game over tem 2 botoes", #EndScreens._state().layout.buttons, 2)
            t:eq("foco inicial: tentar de novo", EndScreens.focusedKey(), "retry")
            EndScreens.keypressed("right")
            t:eq("dpad move o foco", EndScreens.focusedKey(), "menu")
            EndScreens.keypressed("return")
            t:eq("botao A ativa", calls[#calls], "menu")
            local src = love.filesystem.read("main.lua") or ""
            local gp = src:match("function love%.gamepadpressed.-\nend")
            t:truthy("love.gamepadpressed encaminha as telas finais",
                gp and gp:find('currentState == "gameOver" or currentState == "victory"', 1, true))
            t:truthy("love.mousepressed roteia as telas finais",
                src:find("EndScreens.mousepressed(x, y, button)", 1, true))
            t:truthy("love.mousereleased roteia as telas finais",
                src:find("EndScreens.mousereleased(x, y, button)", 1, true))

            EndScreens._enter("gameOver", gd, 1)
            local Lg = EndScreens._state().layout
            local n0 = #calls
            local rx, ry = center(Lg.buttons[1])
            EndScreens.mousepressed(rx, ry, 1)
            EndScreens.mousereleased(rx, ry, 1)
            t:eq("clique no botao ativa", calls[#calls], "retry")
            local mx, my = center(Lg.buttons[2])
            EndScreens.mousepressed(rx, ry, 1)
            EndScreens.mousereleased(mx, my, 1)
            t:eq("press num botao e release em outro NAO ativa", #calls, n0 + 1)
            EndScreens.mousepressed(5, 5, 1)
            EndScreens.mousereleased(5, 5, 1)
            t:eq("clique fora dos botoes nao faz nada", #calls, n0 + 1)
            EndScreens.mousepressed(mx, my, 2)
            EndScreens.mousereleased(mx, my, 2)
            t:eq("botao direito nao ativa", #calls, n0 + 1)

            local gc = TK.newRunGame("rogue")
            gc.isRunMode = false
            EndScreens._enter("victory", gc, 1)
            t:eq("vitoria sem run vencida: so 2 botoes", #EndScreens._state().layout.buttons, 2)
        end)

        withSize(1024, 768, function() EndScreens._enter("gameOver", gd, 1) end)
        local before = EndScreens._state().layout.actions.y
        withSize(1920, 1080, function()
            EndScreens.resize()
            EndScreens._enter("gameOver", gd, 1)
        end)
        t:truthy("depois do resize as acoes descem pro rodape novo",
            EndScreens._state().layout.actions.y > before)
    end)
    I18n.setLocale(prevLocale or "pt_BR")
    PS._swapForTests(prevProfile)
    require("engine.SaveManager").deleteRun()
    t:truthy("suite sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
