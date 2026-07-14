-- tools/screenshot_bootfx.lua
-- Captura o vórtice procedural da entrada (BootFX) em 3 intensidades sobre a
-- base pixel art, através do tubo CRT. Pra validar o look sem rodar o boot inteiro.
--   love . screenshot_bootfx
local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load(); CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
    local BootFX = require("src.ui.BootFX")

    local base = love.graphics.newImage("assets/sprites/scenes/boot_anim/frame_00.png")
    base:setFilter("nearest", "nearest")
    local W, H = love.graphics.getDimensions()
    local function drawBase()
        local iw, ih = base:getDimensions()
        local s = math.max(W / iw, H / ih)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.draw(base, math.floor((W - iw * s) / 2), math.floor((H - ih * s) / 2), 0, s, s)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local shots = { { 0.4, "bootfx_04.png" }, { 0.7, "bootfx_07.png" }, { 1.0, "bootfx_10.png" } }
    for _, sh in ipairs(shots) do
        local intensity, name = sh[1], sh[2]
        BootFX.reset()
        for _ = 1, 40 do BootFX.update(1 / 30, intensity) end   -- popula bolts/brasas
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        drawBase()
        BootFX.draw(W / 2, H / 2, math.min(W, H) * 0.34, intensity)
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[bootfx] " .. name .. " salvo (intensity=" .. intensity .. ")")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
