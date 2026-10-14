local TK = require("tools.testkit")

local M = {}

local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
local function fakeWindow(w, h)
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
end

local function throughTube(CRTShader, W, H, drawScene)
    local target = love.graphics.newCanvas(W, H)
    love.graphics.push("all")
    CRTShader.beginScene()
    drawScene()
    CRTShader.endScene(target)
    love.graphics.pop()
    local data = target:newImageData()
    target:release()
    return data
end

local function fringe(data, y, x0, x1)
    local n, amp = 0, 0
    for x = x0, x1 do
        local r, _, b = data:getPixel(x, y)
        local d = math.abs(r - b)
        if d > 0.18 then n = n + 1 end
        if d > amp then amp = d end
    end
    return n, amp
end

function M.run()
    local t = TK.new("CRT em niveis: ciclo, settings, lente, aberracao em px, gates")
    TK.bootstrap()
    local CRTShader = require("src.ui.CRTShader")
    local SM = require("engine.SaveManager")

    local okRun, err = pcall(function()
        t:eq("LEVELS = off, low, normal", table.concat(CRTShader.LEVELS, ","), "off,low,normal")
        t:eq("setLevel normal -> 0.75", (CRTShader.setLevel("normal") and CRTShader.getStrength()), 0.75)
        t:truthy("normal: ligado", CRTShader.isEnabled())
        CRTShader.setLevel("low")
        t:truthy("low: ligado, forca 0.35", CRTShader.isEnabled() and math.abs(CRTShader.getStrength() - 0.35) < 1e-9)
        t:eq("getLevel low", CRTShader.getLevel(), "low")
        CRTShader.setLevel("off")
        t:falsy("off: desligado", CRTShader.isEnabled())
        t:eq("off: forca 0", CRTShader.getStrength(), 0)
        t:eq("getLevel off", CRTShader.getLevel(), "off")
        t:eq("nextLevel(normal, +1) = off (Enter no Normal desliga)", CRTShader.nextLevel("normal", 1), "off")
        t:eq("nextLevel(off, +1) = low", CRTShader.nextLevel("off", 1), "low")
        t:eq("nextLevel(off, -1) = normal", CRTShader.nextLevel("off", -1), "normal")
        t:eq("nivel desconhecido cai em normal (avisa)", CRTShader.setLevel("ultra"), "normal")
        CRTShader.setEnabled(false)
        CRTShader.setEnabled(true)
        t:eq("setEnabled(true) depois de off volta ao normal", CRTShader.getLevel(), "normal")

        t:eq("levelFromSettings({}) = normal", CRTShader.levelFromSettings({}), "normal")
        t:eq("save antigo crtShader=false -> off", CRTShader.levelFromSettings({ crtShader = false }), "off")
        t:eq("crtLevel=low vence", CRTShader.levelFromSettings({ crtLevel = "low", crtShader = true }), "low")
        t:eq("crtLevel invalido -> normal", CRTShader.levelFromSettings({ crtLevel = "x" }), "normal")
        t:eq("DEFAULT_SETTINGS.crtLevel = normal", SM.DEFAULT_SETTINGS.crtLevel, "normal")
        local sm = love.filesystem.read("components/SettingsMenu.lua") or ""
        t:truthy("SettingsMenu: linha CRT em ciclo (settings.crt_<nivel>)", sm:find('"settings.crt_" .. CRTShader.getLevel()', 1, true) ~= nil)
        t:truthy("SettingsMenu: snapshot persiste crtLevel", sm:find("crtLevel      = CRTShader.getLevel()", 1, true) ~= nil)
        local main = love.filesystem.read("main.lua") or ""
        t:truthy("main.lua aplica o nivel salvo no boot", main:find("CRTShader.setLevel(CRTShader.levelFromSettings(persistedSettings))", 1, true) ~= nil)
        local osd = love.filesystem.read("src/ui/TvOsd.lua") or ""
        t:truthy("TvOsd.staticNoise so com o tubo ligado", osd:find('require("src.ui.CRTShader").isEnabled()', 1, true) ~= nil)
        local menu = love.filesystem.read("components/Menu.lua") or ""
        t:truthy("Menu: varredura do botao so com o tubo ligado", menu:find('if require("src.ui.CRTShader").isEnabled() then', 1, true) ~= nil)

        local I18n = require("src.i18n.I18n")
        local cur = I18n.getLocale()
        for _, loc in ipairs({ "pt_BR", "en", "es", "de", "fr" }) do
            I18n.setLocale(loc, true)
            for _, k in ipairs({ "settings.crt_off", "settings.crt_low", "settings.crt_normal" }) do
                local v = I18n.t(k, nil, "__missing__")
                t:truthy(loc .. ": " .. k, v ~= "__missing__" and v ~= k and v ~= "")
            end
        end
        I18n.setLocale(cur, true)

        t:truthy("load() compila shaders/crt.glsl", CRTShader.load())
        CRTShader.setLevel("off")
        local px, py = CRTShader.screenToContent(123, 456)
        t:truthy("off: screenToContent e identidade", px == 123 and py == 456)

        CRTShader.setPower(1)
        local function scene(W, H)
            return function()
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", math.floor(W / 2) - 1, math.floor(H * 0.3), 2, math.floor(H * 0.4))
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
        local widths, amps = {}, {}
        for _, lv in ipairs({ "normal", "low" }) do
            for _, sz in ipairs({ { 1920, 1080 }, { 2560, 1440 } }) do
                local W, H = sz[1], sz[2]
                fakeWindow(W, H)
                CRTShader.setLevel(lv)
                local data = throughTube(CRTShader, W, H, scene(W, H))
                local cx = math.floor(W / 2)
                local fw, amp = fringe(data, math.floor(H / 2), cx - 12, cx + 12)
                widths[lv .. W], amps[lv .. W] = fw, amp
                t:truthy(("%s %dx%d: franja de cor <= 4 px (obtido %d, desvio max %.2f)"):format(lv, W, H, fw, amp),
                    fw <= 4)
                local r, g, b = data:getPixel(cx, math.floor(H / 2))
                t:truthy(("%s %dx%d: a linha segue visivel"):format(lv, W, H), (r + g + b) / 3 > 0.45)
            end
        end
        t:truthy("normal: franja em 1440p nao e maior que em 1080p (+1 px de tolerancia)",
            widths.normal2560 <= widths.normal1920 + 1)
        t:truthy("normal: desvio de cor em 1440p ~ igual ao de 1080p (aberracao em px, nao em fracao da tela)",
            math.abs(amps.normal2560 - amps.normal1920) < 0.12)
        t:truthy(("low: desvio de cor menor que normal (%.2f < %.2f)"):format(amps.low1920, amps.normal1920),
            amps.low1920 < amps.normal1920 - 0.05)

        fakeWindow(1920, 1080)
        CRTShader.setLevel("off")
        local target = love.graphics.newCanvas(1920, 1080)
        love.graphics.push("all")
        love.graphics.setCanvas(target)
        CRTShader.beginScene()
        scene(1920, 1080)()
        CRTShader.endScene(target)
        love.graphics.pop()
        local d = target:newImageData()
        target:release()
        local r, g, b = d:getPixel(960, 540)
        local r2, g2, b2 = d:getPixel(900, 540)
        t:truthy("off: linha crua no lugar (branco no centro, preto ao lado)",
            r > 0.99 and g > 0.99 and b > 0.99 and r2 < 0.01 and g2 < 0.01 and b2 < 0.01)
        CRTShader.setLevel("normal")
    end)
    restoreWindow()
    CRTShader.setLevel("normal")
    t:check("sem excecao" .. (okRun and "" or (": " .. tostring(err))), okRun)
    return t:done()
end

return M
