local M = {}
local TK = require("tools.testkit")

function M.run(arg)
    TK.bootstrap()
    local t = TK.new("test_credits")
    local I18n = require("src.i18n.I18n")
    local CreditsScreen = require("components.CreditsScreen")
    local scr = CreditsScreen:new()

    local raw = 0
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        I18n.setLocale(loc, true)
        for _, c in ipairs(CreditsScreen.CREDITS) do
            for _, k in ipairs({ c.role, c.name }) do
                if I18n.t(k) == k then raw = raw + 1; print("    sem traducao: " .. loc .. " " .. k) end
            end
        end
        for _, k in ipairs({ "credits.title", "credits.hint", "credits.thanks", "credits.link" }) do
            if I18n.t(k) == k then raw = raw + 1; print("    sem traducao: " .. loc .. " " .. k) end
        end
    end
    t:eq("toda linha dos creditos traduzida nos 5 idiomas", raw, 0)

    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local cases, bad = 0, 0
    for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
        I18n.setLocale(loc, true)
        for _, s in ipairs({ { 640, 480 }, { 800, 600 }, { 1024, 768 }, { 1920, 1080 } }) do
            love.graphics.getWidth = function() return s[1] end
            love.graphics.getHeight = function() return s[2] end
            local L = scr:layout()
            cases = cases + 1
            if L.listH > (L.bottom - L.top) or L.px < 0 or L.py < 0 then
                bad = bad + 1
                print(string.format("    estoura: %s %dx%d lista=%d zona=%d", loc, s[1], s[2],
                    L.listH, L.bottom - L.top))
            end
        end
    end
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    t:check("geometria verificada em " .. cases .. " combinacoes (20)", cases == 20)
    t:eq("combinacoes em que a lista transborda o painel", bad, 0)

    local closed = 0
    scr:show(function() closed = closed + 1 end)
    scr:mousereleased(10, 10, 1)
    t:truthy("release do clique que abriu NAO fecha a tela", scr:isVisible())
    scr:mousepressed(10, 10, 1); scr:mousereleased(10, 10, 1)
    t:falsy("clique inteiro fecha", scr:isVisible())
    t:eq("fechar devolve ao menu uma vez", closed, 1)
    scr:show(function() closed = closed + 1 end)
    scr:keypressed("escape")
    t:eq("ESC fecha e devolve ao menu", closed, 2)

    if arg == "shots" then
        for _, loc in ipairs({ "pt_BR", "de" }) do
            I18n.setLocale(loc, true)
            scr:show(function() end)
            love.graphics.clear(0.1, 0.08, 0.06, 1)
            scr:draw()
            local name = "credits_" .. loc .. ".png"
            love.graphics.captureScreenshot(function(img) img:encode("png", name) end)
            love.graphics.present()
            scr.visible = false
        end
    end
    I18n.setLocale("pt_BR", true)
    return t:done()
end

return M
