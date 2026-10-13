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
--   7. o Menu desenha SEM a fita ticker (removida a pedido do dono).
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
    -- as secoes 1-5 sao do televisor do shader: sem a arte do computador,
    -- mesmo que o jogo ja tenha src/data/intro_computer.lua instalado
    local prevData = IntroTube.DATA_PATH
    IntroTube.DATA_PATH = "tut_intro_nao_existe.lua"
    IntroTube.reloadArt()

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

    -- ===== 5b. ARTE do computador (dados + PNG no save dir) =====
    do
        local idata = love.image.newImageData(120, 150)
        idata:mapPixel(function(x, y)
            if x >= 20 and x < 100 and y >= 20 and y < 80 then return 0, 0, 0, 0 end   -- a tela (transparente)
            return 0.72, 0.63, 0.41, 1
        end)
        idata:encode("png", "tut_intro_computer.png")
        love.filesystem.write("tut_intro_computer.lua",
            'return { image = "tut_intro_computer.png", w = 120, h = 150, screen = { x = 20, y = 20, w = 80, h = 60 }, slot = { x = 55, y = 120, w = 50, h = 4 } }')
        local prevPath = "tut_intro_nao_existe.lua"   -- de volta ao modo tubo, mesmo com a arte instalada
        IntroTube.DATA_PATH = "tut_intro_computer.lua"
        IntroTube.reloadArt()
        local d = IntroTube.computerArt()
        t:truthy("arte do computador carrega do arquivo de dados", d ~= nil and d.img ~= nil)
        for _, s in ipairs({ { 1024, 768 }, { 1920, 1080 }, { 2560, 1440 } }) do
            local G = IntroTube.geometry(s[1], s[2])
            t:eq(("%dx%d: modo arte"):format(s[1], s[2]), G.mode, "art")
            t:truthy(("%dx%d: computador cabe (<= 70%% da altura)"):format(s[1], s[2]), G.ah <= s[2] * 0.70 + 1)
            t:truthy(("%dx%d: a TELA da arte esta dentro do computador"):format(s[1], s[2]),
                G.sx >= G.ax and G.sy >= G.ay and G.sx + G.sw <= G.ax + G.aw and G.sy + G.sh <= G.ay + G.ah)
            local B = IntroTube.BEZEL_PX
            t:truthy(("%dx%d: no fim do mergulho a tela cai na abertura do CRT (janela menos o gabinete)"):format(s[1], s[2]),
                math.abs(G.sw * G.sEndX - (s[1] - 2 * B)) < 0.5 and math.abs(G.sh * G.sEndY - (s[2] - 2 * B)) < 0.5)
        end
        IntroTube.init({})
        t:noerror("draw com a arte (pagina)", function() IntroTube.draw() end)
        for _ = 1, 60 * 10 do IntroTube.update(dt); if IntroTube.phase() == "dive" then break end end
        IntroTube.update(IntroTube.T.dive / 2)
        t:noerror("draw com a arte (mergulho)", function() IntroTube.draw() end)
        t:truthy("no meio do mergulho ainda nao terminou pelo mergulho", not IntroTube.endedWithDive())
        IntroTube.update(IntroTube.T.dive)
        t:eq("mergulho completo termina", IntroTube.phase(), "done")
        t:truthy("terminou PELO mergulho (CRT liga aceso)", IntroTube.endedWithDive())
        IntroTube.init({})
        IntroTube.skip()
        t:truthy("pular nao conta como mergulho", not IntroTube.endedWithDive())

        -- ===== 5c. a CARTA entra na fenda do disquete antes do mergulho =====
        IntroTube.init({})
        local sawInsert = false
        for _ = 1, 60 * 10 do IntroTube.update(dt); if IntroTube.phase() == "insert" then sawInsert = true break end end
        t:truthy("com a arte, depois do texto vem a fase insert (carta na fenda)", sawInsert)
        local G2 = IntroTube.geometry(1280, 720)
        t:truthy("a fenda dos dados fica abaixo da tela e dentro do computador",
            G2.slot and G2.slot.y > G2.sy + G2.sh and G2.slot.y + G2.slot.h <= G2.ay + G2.ah + 0.5)
        IntroTube.update(IntroTube.T.insert * 0.5)
        t:near("meio do caminho da carta", IntroTube.insertProgress(), 0.5, 0.05)
        t:noerror("draw com a carta entrando", function() IntroTube.draw() end)
        IntroTube.update(IntroTube.T.insert * 0.6)
        t:noerror("draw com o flash da tela", function() IntroTube.draw() end)
        IntroTube.update(IntroTube.T.insertHold)
        t:eq("depois da fenda vem o mergulho", IntroTube.phase(), "dive")
        IntroTube.skip()
        -- sem a fenda nos dados: fracao de fallback, ainda abaixo da tela
        love.filesystem.write("tut_intro_computer.lua",
            'return { image = "tut_intro_computer.png", w = 120, h = 150, screen = { x = 20, y = 20, w = 80, h = 60 } }')
        IntroTube.reloadArt()
        local G3 = IntroTube.geometry(1280, 720)
        t:truthy("sem slot nos dados: fenda de fallback abaixo da tela", G3.slot and G3.slot.y > G3.sy + G3.sh)
        -- reducedMotion: sem carta, sem mergulho
        _G.gameSettings.reducedMotion = true
        IntroTube.init({})
        for _ = 1, 60 * 4 do IntroTube.update(dt); if IntroTube.phase() == "done" then break end end
        t:eq("reducedMotion com a arte: termina sem insert nem dive", IntroTube.phase(), "done")
        _G.gameSettings.reducedMotion = false
        IntroTube.DATA_PATH = prevPath
        IntroTube.reloadArt()
        t:truthy("sem dados: volta ao televisor do shader", IntroTube.geometry(1280, 720).mode == "tube")
    end

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

    -- ===== 7. menu SEM fita (dono, 13/Out: "tira isso, deixa sem nada") =====
    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:show(function() end, function() end)
    t:truthy("menu nao tem mais a fita ticker", menu.ribbonRect == nil and Menu.RIBBON_H == nil)
    t:noerror("menu desenha sem a fita", function() menu:draw() end)
    if menu.hide then menu:hide() end

    _G.gameSettings.reducedMotion = prevReduced or false
    IntroTube.DATA_PATH = prevData
    IntroTube.reloadArt()
    return t:done()
end

return M
