-- tools/screenshot_crt.lua
-- Valida a identidade CRT v2: renderiza o MENU dentro do tubo com power
-- em 4 estágios (linha quente, abertura, assentando, ligado) + strength
-- cheio. As demais capturas do projeto continuam SEM CRT (doutrina).
--   love . screenshot_crt

local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load()
    CRTShader.setEnabled(true)
    CRTShader.setStrength(0.85)

    local Menu = require("components.Menu")
    local menu = Menu:new()
    for _ = 1, 60 do menu:update(1 / 30) end

    local stages = { 0.18, 0.55, 0.90, 1.0 }
    local names = { "crt_line.png", "crt_opening.png",
                    "crt_settling.png", "crt_on.png" }

    -- REVISÃO DE TELAS: HUD de batalha (mana canto inf-dir, vida inf-esq,
    -- TopBar) através do tubo — nada pode ser escondido pela máscara.
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    game.player.health = 48
    game.player.armor = 7
    local TopBar = require("components.TopBar")
    local topBar = TopBar:new()
    topBar:setGame(game)
    local HudManager = require("src.ui.HudManager")
    local hud = HudManager:new()
    hud:update(1 / 30, game)

    CRTShader.setPower(1)
    CRTShader.beginScene()
    love.graphics.clear(0.12, 0.09, 0.07, 1)
    topBar:draw()
    hud:draw(game)
    local HintBar = require("src.ui.HintBar")
    HintBar.draw("Canto a canto: nada pode sumir atras da mascara")
    CRTShader.endScene()
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "crt_hud_review.png")
        print("[crt] crt_hud_review.png salvo")
    end)
    love.graphics.present()

    for i, p in ipairs(stages) do
        CRTShader.setPower(p)
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", names[i])
            print("[crt] " .. names[i] .. " salvo (power=" .. p .. ")")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
