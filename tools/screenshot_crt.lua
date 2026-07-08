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
