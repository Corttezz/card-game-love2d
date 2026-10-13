-- tools/test_intro_tube.lua
-- Trava da ABERTURA "página e televisor" (src/scenes/IntroTube.lua):
--   1. fases page -> dive -> done no tempo da tabela IntroTube.T, com o
--      título e o subtítulo datilografados por inteiro antes do mergulho;
--   2. a geometria do mergulho enche a janela com a ABERTURA do tubo (não
--      com o gabinete) em 6 tamanhos de janela;
--   3. pular (tecla/clique) termina na hora e chama onDone uma vez;
--   4. reducedMotion: texto inteiro imediato, sem fase dive, termina;
--   5. draw em todas as fases sem erro (com e sem canvas);
--   6. BootScene com intro ligada passa pela fase "intro" antes de "loading"
--      e chama onTubeOn exatamente uma vez; com intro desligada chama direto;
--   7. a fita do Menu existe, tem borda e fica acima do rodapé.
--   love . test_one test_intro_tube

local TK = require("tools.testkit")
local M = {}

function M.run()
    TK.bootstrap()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    local t = TK.new("abertura: pagina + televisor + mergulho")
    local IntroTube = require("src.scenes.IntroTube")
    _G.gameSettings = _G.gameSettings or {}
    local prevReduced = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = false

    -- ===== 1. fases e datilografia =====
    local done = 0
    IntroTube.init({ onDone = function() done = done + 1 end })
    t:eq("comeca na pagina", IntroTube.phase(), "page")
    local dt = 1 / 60
    local sawDive, firstTyped = false, nil
    for i = 1, 60 * 12 do
        IntroTube.update(dt)
        local a = IntroTube.typed()
        if a > 0 and not firstTyped then firstTyped = i * dt end
        if IntroTube.phase() == "dive" then
            sawDive = true
            local a2, b2 = IntroTube.typed()
            local S = IntroTube._state()
            t:truthy("mergulho so depois do texto inteiro", a2 == S.lenTitle and b2 == S.lenSub)
            break
        end
    end
    t:truthy("chegou ao mergulho", sawDive)
    t:truthy(("datilografia comeca em typeAt (%.2f)"):format(firstTyped or -1),
        firstTyped and math.abs(firstTyped - IntroTube.T.typeAt) < 0.1)
    for _ = 1, 60 * 3 do IntroTube.update(dt) end
    t:eq("termina depois do mergulho", IntroTube.phase(), "done")
    t:eq("onDone uma vez", done, 1)
    IntroTube.update(dt)
    t:eq("update depois de done nao repete onDone", done, 1)

    -- ===== 2. geometria =====
    for _, s in ipairs({ { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 1280, 800 } }) do
        local G = IntroTube.geometry(s[1], s[2])
        t:truthy(("%dx%d: televisor cabe na janela"):format(s[1], s[2]), G.tw < s[1] and G.th < s[2] * 0.8)
        t:truthy(("%dx%d: no fim do mergulho a abertura do tubo cobre a janela"):format(s[1], s[2]),
            G.innerW * G.sEnd >= s[1] - 0.5 and G.innerH * G.sEnd >= s[2] - 0.5)
        t:near(("%dx%d: televisor 4:3"):format(s[1], s[2]), G.th / G.tw, 0.75, 0.01)
    end

    -- ===== 3. pular =====
    done = 0
    IntroTube.init({ onDone = function() done = done + 1 end })
    for _ = 1, 30 do IntroTube.update(dt) end
    IntroTube.keypressed("space")
    t:eq("tecla pula", IntroTube.phase(), "done")
    t:eq("pular chama onDone uma vez", done, 1)
    IntroTube.mousepressed(1, 1, 1)
    t:eq("clique depois de done nao repete", done, 1)

    -- ===== 4. reducedMotion =====
    _G.gameSettings.reducedMotion = true
    done = 0
    IntroTube.init({ onDone = function() done = done + 1 end })
    local a, b = IntroTube.typed()
    local S = IntroTube._state()
    t:truthy("reducedMotion: texto inteiro na hora", a == S.lenTitle and b == S.lenSub)
    local phases = {}
    for _ = 1, 60 * 3 do IntroTube.update(dt); phases[IntroTube.phase()] = true end
    t:falsy("reducedMotion: sem mergulho (movimento)", phases.dive)
    t:eq("reducedMotion: termina", IntroTube.phase(), "done")
    t:eq("reducedMotion: onDone uma vez", done, 1)
    _G.gameSettings.reducedMotion = false

    -- ===== 5. draw em todas as fases =====
    IntroTube.init({})
    t:noerror("draw na pagina", function() IntroTube.draw() end)
    for _ = 1, 60 * 6 do IntroTube.update(dt); if IntroTube.phase() == "dive" then break end end
    IntroTube.update(IntroTube.T.dive / 2)
    t:noerror("draw no mergulho", function() IntroTube.draw() end)
    IntroTube.skip()
    t:noerror("draw depois de done (nao desenha)", function() IntroTube.draw() end)

    -- ===== 6. BootScene =====
    local BootScene = require("src.scenes.BootScene")
    local on, complete = 0, 0
    BootScene.init({ intro = true, seed = 7, onTubeOn = function() on = on + 1 end,
        onComplete = function() complete = complete + 1 end })
    t:eq("boot com intro comeca em intro", BootScene.phase(), "intro")
    t:eq("onTubeOn ainda nao", on, 0)
    for _ = 1, 60 * 2 do BootScene.update(dt) end
    t:eq("ainda na intro (datilografando)", BootScene.phase(), "intro")
    BootScene.keypressed("space")
    t:truthy("pular a intro leva ao loading", BootScene.phase() == "loading" or BootScene.phase() == "splash")
    t:eq("onTubeOn uma vez ao sair da intro", on, 1)
    BootScene.keypressed("space")
    t:eq("segundo pulo termina o boot", BootScene.phase(), "done")
    t:eq("onComplete uma vez", complete, 1)
    local on2 = 0
    BootScene.init({ intro = false, seed = 7, onTubeOn = function() on2 = on2 + 1 end, onComplete = function() end })
    t:eq("sem intro: comeca em loading", BootScene.phase(), "loading")
    t:eq("sem intro: onTubeOn na hora", on2, 1)
    BootScene.skip()

    -- ===== 7. fita do menu =====
    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:show(function() end, function() end)
    local R = menu:ribbonRect()
    local H = love.graphics.getHeight()
    t:truthy("fita existe e tem altura", R and R.h >= 16)
    t:truthy("fita no pe da tela", R.y + R.h <= H and R.y >= H - 40)
    t:truthy("rodape da versao acima da fita", menu:footerY() + 12 <= R.y)
    t:truthy("borda da fita de 4 px (como o site)", Menu.RIBBON_BORDER == 4)
    t:noerror("menu desenha com a fita", function() menu:draw() end)
    if menu.hide then menu:hide() end

    _G.gameSettings.reducedMotion = prevReduced or false
    return t:done()
end

return M
