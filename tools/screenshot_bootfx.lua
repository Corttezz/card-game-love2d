-- tools/screenshot_bootfx.lua
-- Captura o FUNDO da entrada v5 (boot_splash.glsl — plasma swirl estilo Balatro,
-- paleta sépia) em alguns instantes de tempo, através do tubo CRT. Pra validar
-- o look sem rodar o boot inteiro.  love . screenshot_bootfx
local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load(); CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)

    local ok, shader = pcall(love.graphics.newShader, "shaders/boot_splash.glsl")
    if not ok then print("[bootfx] shader falhou: " .. tostring(shader)); love.event.quit(); return end

    local W, H = love.graphics.getDimensions()
    local GOLD = { 0.95, 0.78, 0.32, 1 }        -- colour_1
    local PARCH = { 0.93, 0.86, 0.66, 1 }       -- colour_2

    local shots = {
        { 2.0, 0.0, "bootsplash_t2.png" },
        { 5.0, 0.0, "bootsplash_t5.png" },
        { 9.0, 0.0, "bootsplash_t9.png" },
        { 9.0, 0.6, "bootsplash_flash.png" },   -- indo pro branco
    }
    for _, sh in ipairs(shots) do
        local t, flash, name = sh[1], sh[2], sh[3]
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setShader(shader)
        shader:send("time", t)
        shader:send("vort_speed", 1.0)
        shader:send("colour_1", GOLD)
        shader:send("colour_2", PARCH)
        shader:send("mid_flash", flash)
        shader:send("vort_offset", 12.0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setShader()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[bootfx] " .. name .. " (t=" .. t .. " flash=" .. flash .. ")")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
