-- tools/test_journal_resize.lua
-- Auditoria de RESIZE do Roteiro da jornada (components/RunJournalScreen.lua).
--
-- memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". A tela é
-- criada num tamanho e o layout é REAPROVEITADO noutro — é aí que o defeito
-- mora. A mesma memória registra que `love.window.setMode` repetido dentro de
-- um tool TRAVA, então a janela é FALSIFICADA (monkey-patch em
-- love.graphics.getWidth/getHeight), igual ao tools/test_forge_resize.lua.
--
-- O que este teste garante, em 7 tamanhos × 5 idiomas × run curta (2 atos) e
-- longa (6 atos + endless), no fim e no topo da rolagem — via
-- RunJournalLayout.validate (src/ui/RunJournalLayout.lua):
--   • as zonas não se cruzam (capítulos entre o cabeçalho e o rodapé);
--   • nenhuma parada sai da janela nem da própria faixa; castelo fora da grade;
--   • o detalhe (hover) de TODA parada visível fica dentro da faixa do próprio
--     ato, dentro da zona e da janela, sem tapar a própria parada;
--   • o scroll nunca aponta pra fora do conteúdo recém-medido.
--
--   love . test_one test_journal_resize
--   love . test_all

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

-- ===== Janela falsa =====
local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH = nil, nil
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
end

-- Espelha o que love.resize faz de verdade: limpa o cache de fontes ANTES de
-- avisar a tela. Teste mais leniente que o jogo não vale nada.
local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    screen:resize()
end

-- Monta uma run com histórico de 2 atos (8 + 4 nós), igual ao screenshot.
local function seededGame()
    local game = TK.newRunGame("warrior")
    local rm = game.runManager
    local run = rm.currentRun
    run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
    local plan = {
        { 1, 1, "battle" }, { 1, 2, "battle" }, { 1, 3, "event" }, { 1, 4, "battle" },
        { 1, 5, "rest" }, { 1, 6, "shop" }, { 1, 7, "mini_boss" }, { 1, 8, "boss" },
        { 2, 1, "battle" }, { 2, 2, "elite" }, { 2, 3, "rest" }, { 2, 4, "shop" },
    }
    for _, p in ipairs(plan) do
        run.actNumber, run.floorInAct = p[1], p[2]
        run.currentFloor = (p[1] - 1) * 8 + p[2]
        table.insert(run.mapHistory,
            { actNumber = p[1], floorInAct = p[2], type = p[3] })
        rm:journalBegin({ type = p[3] }, { hp = 50, maxHp = 60, gold = 40 })
        rm:journalNote({ kind = "card", id = "warrior_bash" })
        rm:journalEnd({ hp = 44, gold = 55 })
    end
    run.actNumber, run.floorInAct = 2, 4
    return game
end

-- Run longa: os 6 atos da campanha + endless com 11 paradas (linhas de 8).
local function longGame()
    local g = TK.newRunGame("warrior")
    local rm = g.runManager
    local run = rm.currentRun
    run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
    local types = { "battle", "event", "battle", "rest", "shop", "elite", "mini_boss", "boss" }
    local function add(act, fl, t)
        run.actNumber, run.floorInAct = act, fl
        run.currentFloor = (act - 1) * 8 + fl
        table.insert(run.mapHistory, { actNumber = act, floorInAct = fl, type = t })
        rm:journalBegin({ type = t }, { hp = 50, maxHp = 60, gold = 10 })
        -- shop com muitos ganhos: é o detalhe mais alto, o que testa o corte
        if t == "shop" then
            for _ = 1, 6 do rm:journalNote({ kind = "card", id = "warrior_bash" }) end
            rm:journalNote({ kind = "remove", id = "warrior_strike" })
        else
            rm:journalNote({ kind = "card", id = "warrior_bash" })
        end
        rm:journalEvent("evt_x", 1, "Opcao longa de evento pra medir a largura")
        rm:journalEnd({ hp = 45, gold = 20 })
    end
    for act = 1, 6 do
        for fl = 1, 8 do add(act, fl, types[fl]) end
    end
    for i = 1, 11 do add(7, ((i - 1) % 8) + 1, types[((i - 1) % 8) + 1]) end
    run.actNumber, run.endlessMode = 7, true
    return g
end

-- Invariantes do layout resolvido + o detalhe de CADA parada visível.
local function auditLayout(screen)
    local Layout = require("src.ui.RunJournalLayout")
    local L = screen:_layout()
    local problems = Layout.validate(L)
    for bi, lb in ipairs(L.bands) do
        for ni, c in ipairs(lb.cells) do
            local visible = c.y + c.h > L.zone.y and c.y < L.zone.y + L.zone.h
            if visible then
                local tip = screen:_tipFor(L, bi, ni)
                local whole = c.y >= L.zone.y and c.y + c.h <= L.zone.y + L.zone.h
                if whole and not tip then
                    problems[#problems + 1] = ("[detalhe %d/%d] parada inteira visível sem detalhe"):format(bi, ni)
                end
                for _, p in ipairs(tip and Layout.validate(L, tip) or {}) do
                    problems[#problems + 1] = ("[detalhe %d/%d] %s"):format(bi, ni, p)
                end
            end
        end
    end
    return problems, L
end

function M.run()
    TK.bootstrap()
    TK.seedRng(23)
    local t = TK.new("roteiro: resize")

    local game = seededGame()
    local Screen = require("components.RunJournalScreen")
    local screen = Screen:new()

    installFakeWindow()
    local ok = pcall(function()
        -- NASCE pequeno (é o caminho do bug: layout calculado aqui).
        fakeW, fakeH = 800, 600
        screen:show(game)

        local sizes = {
            { 800, 600 },    -- nasce
            { 1920, 1080 },  -- cresce (fullscreen)
            { 800, 600 },    -- volta
            { 1024, 768 },   -- padrão
            { 640, 480 },    -- mínimo suportado
            { 1280, 400 },   -- largo e baixo: força o scroll
            { 420, 900 },    -- estreito e alto: força a serpentina
        }

        local I18n = require("src.i18n.I18n")
        local prevLocale = I18n.getLocale and I18n.getLocale() or "pt_BR"
        local long = Screen:new()
        local gLong = longGame()
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            I18n.setLocale(loc)
            for _, s in ipairs(sizes) do
                local w, h = s[1], s[2]
                for _, sc in ipairs({ { screen, game, "curta" }, { long, gLong, "longa" } }) do
                    local scr = sc[1]
                    if not scr:isVisible() then scr:show(sc[2]) end
                    resizeTo(scr, w, h)
                    local problems, L = auditLayout(scr)
                    -- rola pro topo e confere de novo (show abre no fim)
                    scr:keypressed("home")
                    local p2 = auditLayout(scr)
                    for _, p in ipairs(p2) do problems[#problems + 1] = p end
                    t:eq(("%s %s %dx%d sem violação de zona"):format(sc[3], loc, w, h),
                        #problems, 0)
                    for i = 1, math.min(5, #problems) do print("      -> " .. problems[i]) end
                    t:truthy(("%s %s %dx%d disco dentro dos limites"):format(sc[3], loc, w, h),
                        L.disc >= 24 and L.disc <= 56)
                end
            end
        end
        I18n.setLocale(prevLocale)
        long:hide()

        -- Com 2 atos o layout SEMPRE cabe (a faixa encolhe junto com a janela),
        -- então o scroll só aparece com muitas faixas — um roteiro longo, que é
        -- o caso do endless. É esse que precisa reclampar ao crescer a janela.
        local long = Screen:new()
        local g3 = TK.newRunGame("warrior")
        local r3 = g3.runManager
        r3.currentRun.mapHistory, r3.currentRun.journal = {}, {}
        r3.currentRun.journalOpen = nil
        for act = 1, 6 do
            for fl = 1, 8 do
                r3.currentRun.actNumber, r3.currentRun.floorInAct = act, fl
                r3.currentRun.currentFloor = (act - 1) * 8 + fl
                table.insert(r3.currentRun.mapHistory,
                    { actNumber = act, floorInAct = fl, type = "battle" })
                r3:journalBegin({ type = "battle" }, { hp = 50, maxHp = 60, gold = 10 })
                r3:journalEnd({ hp = 45, gold = 20 })
            end
        end
        r3.currentRun.actNumber = 6

        fakeW, fakeH = 640, 480
        long:show(g3)
        long:_layout()
        t:eq("roteiro longo agrupou 6 faixas", #long:_layout().bands, 6)
        t:truthy("janela pequena gera scroll", long.maxScroll > 0)

        long:wheelmoved(0, -999)
        t:truthy("rolou até o fim", long.scroll > 0)
        local deep = long.scroll
        t:eq("abre no fim (o ato em andamento)", long.scroll, long.maxScroll)

        -- teclado: home/end/setas/página
        long:keypressed("home")
        t:eq("HOME vai pro topo", long.scroll, 0)
        long:keypressed("down")
        t:truthy("SETA pra baixo rola", long.scroll > 0)
        long:keypressed("pagedown")
        local afterPg = long.scroll
        t:truthy("PAGE DOWN rola mais que a seta", afterPg > 48)
        long:keypressed("up")
        t:truthy("SETA pra cima volta", long.scroll < afterPg)
        long:keypressed("end")
        t:eq("END vai pro fim", long.scroll, long.maxScroll)
        long:wheelmoved(0, 1)
        t:truthy("RODA pra cima sobe", long.scroll < long.maxScroll)
        long:keypressed("end")

        resizeTo(long, 1920, 1080)
        long:_layout()
        t:truthy("scroll reclampado ao crescer a janela",
            long.scroll <= long.maxScroll + 0.001)
        t:truthy("scroll de fato encolheu", long.scroll <= deep)
        t:eq("sem violação de zona no roteiro longo",
            #auditLayout(long), 0)

        -- Roteiro vazio não pode explodir em nenhum tamanho.
        local empty = Screen:new()
        local g2 = TK.newRunGame("warrior")
        g2.runManager.currentRun.mapHistory = {}
        g2.runManager.currentRun.journal = {}
        g2.runManager.currentRun.journalOpen = nil
        fakeW, fakeH = 640, 480
        empty:show(g2)
        local L = empty:_layout()
        t:eq("roteiro vazio tem zero faixas", #L.bands, 0)
        t:eq("roteiro vazio não gera scroll", empty.maxScroll, 0)
    end)

    restoreWindow()
    FontManager.clearCache()
    t:truthy("nenhuma exceção durante a auditoria", ok)

    return t:done()
end

return M
