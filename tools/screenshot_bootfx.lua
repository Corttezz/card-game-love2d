-- tools/screenshot_bootfx.lua
-- Valida a ENTRADA v7: usa BootScene.previewBackground (as MESMAS camadas do
-- jogo: câmara + energia no sigilo + glow reativo + chamas/piso), através do
-- tubo CRT.  love . screenshot_bootfx
local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load(); CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
    local BootScene = require("src.scenes.BootScene")

    local shots = {
        -- t do plasma, alpha, flare do sigilo (0.6 = carta recém-absorvida)
        { 1.5, 0.5, 0.0, "bootv7_early.png" },
        { 4.0, 0.8, 0.6, "bootv7_absorb.png" },
        { 7.5, 0.8, 0.0, "bootv7_late.png" },
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
