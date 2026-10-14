local M = {}
local TK = require("tools.testkit")

local function newMenu(hasSave)
    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu._hasSave = hasSave
    local calls = { play = 0 }
    menu:setPlayCallback(function() calls.play = calls.play + 1 end)
    return menu, calls
end

function M.run(arg)
    TK.bootstrap()
    local t = TK.new("test_confirm_dialog")
    local CD = require("src.ui.ConfirmDialog")
    local I18n = require("src.i18n.I18n")

    do
        local menu, calls = newMenu(false)
        menu:onPlayClick()
        t:falsy("sem save: Jogar NAO abre confirmacao", CD.isVisible())
        t:eq("sem save: Jogar segue pra selecao de classe", calls.play, 1)
    end

    do
        local menu, calls = newMenu(true)
        menu:onPlayClick()
        t:truthy("com save: Jogar abre a confirmacao", CD.isVisible())
        t:eq("com save: a corrida salva NAO e descartada antes da resposta", calls.play, 0)
        CD.mousepressed(2, 2, 1); CD.mousereleased(2, 2, 1)
        t:truthy("clique fora do painel nao fecha nem decide", CD.isVisible())
        CD.keypressed("escape")
        t:falsy("ESC cancela", CD.isVisible())
        t:eq("cancelar NAO comeca corrida nova", calls.play, 0)
        t:truthy("cancelar deixa o menu visivel", menu.visible)

        menu:onPlayClick()
        CD.keypressed("return")
        t:falsy("ENTER confirma e fecha", CD.isVisible())
        t:eq("confirmar comeca a corrida nova UMA vez", calls.play, 1)
        t:falsy("trava de confirmacao nao vaza pro proximo clique", menu._newRunConfirmed)
    end

    do
        local menu = newMenu(false)
        local quit = 0
        menu.onQuitClick = function() quit = quit + 1 end
        menu:requestQuit()
        t:truthy("ESC no menu abre 'Sair do jogo?'", CD.isVisible())
        t:eq("o jogo NAO fecha sem resposta", quit, 0)
        menu:requestQuit()
        CD.keypressed("escape")
        t:eq("cancelar mantem o jogo aberto", quit, 0)
        menu:requestQuit()
        CD.keypressed("return")
        t:eq("confirmar sai", quit, 1)
    end

    do
        local fired = 0
        CD.show({ title = "x", body = "y", confirm = I18n.t("confirm.ok"),
            onConfirm = function() fired = fired + 1 end })
        t:eq("aviso tem UM botao", #CD._state().buttons, 1)
        CD.keypressed("return")
        t:falsy("ENTER fecha o aviso", CD.isVisible())
        t:eq("e confirma uma vez", fired, 1)
    end

    do
        local SaveManager = require("engine.SaveManager")
        SaveManager.saveRun({ classId = "warrior" })
        t:truthy("(pre) ha save", SaveManager.hasRun())
        t:truthy("quarantineRun move o save", SaveManager.quarantineRun())
        t:falsy("depois disso o menu nao oferece Continuar", SaveManager.hasRun())
        t:falsy("sem save, quarantine e no-op", SaveManager.quarantineRun())
    end

    do
        local realW, realH = love.graphics.getWidth, love.graphics.getHeight
        local sizes = { { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1920, 1080 }, { 640, 480 } }
        local cases = 0
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            I18n.setLocale(loc, true)
            for _, s in ipairs(sizes) do
                love.graphics.getWidth = function() return s[1] end
                love.graphics.getHeight = function() return s[2] end
                CD.show({ title = I18n.t("confirm.new_run_title"),
                    body = I18n.t("confirm.new_run_body"),
                    confirm = I18n.t("confirm.new_run_yes"),
                    cancel = I18n.t("confirm.cancel"), danger = true })
                local st = CD._state()
                local p = st.panel
                local inside = p.x >= 0 and p.y >= 0 and p.x + p.w <= s[1] and p.y + p.h <= s[2]
                local btnOk = true
                for _, b in ipairs(st.buttons) do
                    if b.x < p.x or b.x + b.width > p.x + p.w or b.y + b.height > p.y + p.h then
                        btnOk = false
                    end
                    local f = require("src.ui.FontManager").getFont(b.fontSize or 11)
                    if f:getWidth(b.text) > b.width + 40 then btnOk = false end
                end
                local bodyBottom = p.y + 24 + st.titleFont:getHeight() + 14
                    + #st.bodyLines * st.bodyFont:getHeight() * 1.25
                local noOverlap = bodyBottom <= st.buttons[1].y
                if not (inside and btnOk and noOverlap) then
                    t:check(loc .. " " .. s[1] .. "x" .. s[2] .. ": painel/botoes/texto cabem", false)
                end
                cases = cases + 1
                CD.hide()
            end
        end
        love.graphics.getWidth, love.graphics.getHeight = realW, realH
        I18n.setLocale("pt_BR", true)
        t:check("geometria verificada em " .. cases .. " combinacoes (25)", cases == 25)
    end

    if arg == "shots" then
        local menu = newMenu(true)
        menu:onPlayClick()
        for _ = 1, 10 do CD.update(1 / 30) end
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        CD.draw()
        love.graphics.captureScreenshot(function(img)
            img:encode("png", "confirm_new_run.png")
            print("[confirm] confirm_new_run.png salvo")
        end)
        love.graphics.present()
        CD.hide()
    end

    return t:done()
end

return M
