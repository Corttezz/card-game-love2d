-- tools/screenshot_bootfx.lua
-- Valida a ENTRADA v6: câmara pixel art + energia arcana mascarada (miolo) em
-- alguns instantes, através do tubo CRT.  love . screenshot_bootfx
local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load(); CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)

    local ok, shader = pcall(love.graphics.newShader, "shaders/boot_splash.glsl")
    if not ok then print("[bootfx] shader falhou: " .. tostring(shader)); love.event.quit(); return end

    local chamber = love.graphics.newImage("assets/sprites/scenes/boot_anim/frame_00.png")
    chamber:setFilter("nearest", "nearest")
    local W, H = love.graphics.getDimensions()
    local GOLD  = { 0.90, 0.70, 0.26, 1 }
    local EMBER = { 0.66, 0.20, 0.10, 1 }

    local function drawChamber()
        local iw, ih = chamber:getDimensions()
        local s = math.max(W / iw, H / ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(chamber, math.floor((W - iw * s) / 2), math.floor((H - ih * s) / 2), 0, s, s)
    end
    local function drawPlasma(t, alpha)
        love.graphics.setShader(shader)
        shader:send("time", t); shader:send("vort_speed", 0.6)
        shader:send("colour_1", GOLD); shader:send("colour_2", EMBER)
        shader:send("mid_flash", 0); shader:send("vort_offset", 12.0)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
    end

    local shots = {
        { 1.5, 0.5, "bootv6_early.png" },   -- energia despertando
        { 4.0, 0.9, "bootv6_mid.png" },     -- cascade em curso
        { 7.5, 0.9, "bootv6_late.png" },    -- título/respiro
    }
    for _, sh in ipairs(shots) do
        local t, a, name = sh[1], sh[2], sh[3]
        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        drawChamber()
        drawPlasma(t, a)
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[bootfx] " .. name .. " (t=" .. t .. " a=" .. a .. ")")
        end)
        love.graphics.present()
    end
    love.event.quit()
end

return M
