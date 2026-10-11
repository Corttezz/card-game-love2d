-- tools/test_confirm_dialog.lua
-- Trava do diálogo de confirmação do menu (src/ui/ConfirmDialog.lua).
--
-- Defeitos que ele mata (known_gaps 25 + revisão de lançamento, Out/2026):
--   1. "Jogar" com uma corrida salva começava outra SEM PERGUNTAR — e a run
--      nova sobrescreve o slot único no primeiro checkpoint. Um clique no
--      botão errado apagava a corrida.
--   2. ESC no menu principal fechava o jogo NA HORA.
--
-- Também verifica o contrato do modal: ESC cancela, ENTER confirma, clique
-- fora não decide, confirmar dispara UMA vez, e o painel cabe na tela em
-- todos os tamanhos e idiomas.
--
-- Roda: love . test_one test_confirm_dialog
--       love . test_one test_confirm_dialog shots   (salva PNGs pra olhar)

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

    -- 1. Sem save: Jogar vai direto (nada de pergunta à toa).
    do
        local menu, calls = newMenu(false)
        menu:onPlayClick()
        t:falsy("sem save: Jogar NAO abre confirmacao", CD.isVisible())
        t:eq("sem save: Jogar segue pra selecao de classe", calls.play, 1)
    end

    -- 2. Com save: Jogar PERGUNTA e não começa nada ainda.
    do
        local menu, calls = newMenu(true)
        menu:onPlayClick()
        t:truthy("com save: Jogar abre a confirmacao", CD.isVisible())
        t:eq("com save: a corrida salva NAO e descartada antes da resposta", calls.play, 0)
        -- clique fora do painel não decide
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

    -- 3. ESC no menu pergunta antes de sair.
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

    -- 4. Geometria: painel e botões cabem na tela em todo idioma e tamanho.
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

    -- 5. Capturas pra olhar (opcional).
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
