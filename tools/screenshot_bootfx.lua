-- tools/screenshot_bootfx.lua
-- Valida a ENTRADA v9: usa BootScene.previewBackground (as MESMAS camadas do
-- jogo: parede-selo + carga do selo), através do tubo CRT.
--   love . screenshot_bootfx
local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load(); CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
    local BootScene = require("src.scenes.BootScene")

    local shots = {
        -- t, carga do selo, flare (0.6 = carta recém-absorvida; 1.0 = flash)
        { 1.5, 0.4, 0.0, "bootv9_early.png" },
        { 4.0, 1.0, 0.6, "bootv9_absorb.png" },
        { 7.5, 1.0, 1.0, "bootv9_peak.png" },
    }
    for _, sh in ipairs(shots) do
        local t, a, flare, name = sh[1], sh[2], sh[3], sh[4]
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        BootScene.previewBackground(t, a, flare)
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[bootfx] " .. name .. " (t=" .. t .. " a=" .. a .. " flare=" .. flare .. ")")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
