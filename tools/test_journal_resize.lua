-- tools/test_journal_resize.lua
-- Auditoria de RESIZE do Roteiro da jornada (components/RunJournalScreen.lua,
-- versão MAPA À MÃO, Out/2026).
--
-- memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". A tela é
-- criada num tamanho e o layout é REAPROVEITADO noutro — é aí que o defeito
-- mora. A mesma memória registra que `love.window.setMode` repetido dentro de
-- um tool TRAVA, então a janela é FALSIFICADA (monkey-patch em
-- love.graphics.getWidth/getHeight), igual ao tools/test_forge_resize.lua.
--
-- O que este teste garante, em 7 tamanhos × 5 idiomas × run curta (2 atos) e
-- longa (6 atos + endless), com o acordeão no estado inicial (só o ato atual
-- aberto), todo aberto e todo fechado, no fim e no topo da rolagem — via
-- RunJournalLayout.validate (src/ui/RunJournalLayout.lua):
--   • as zonas não se cruzam (folhas abaixo do cabeçalho, uma por ato, sem
--     encostar na seguinte); numerais / mapa / margem / legenda dentro da folha;
--   • toda parada e todo ramo (tomado, não tomado, à frente) dentro do mapa;
--     o caminho percorrido contínuo; o castelo dentro do mapa;
--   • o detalhe (hover) de TODA parada visível cabe na folha ∩ zona ∩ janela
--     sem tapar a própria parada;
--   • o scroll nunca aponta pra fora do conteúdo recém-medido;
--   • a altura da linha do mapa fica entre ROW_MIN e ROW_MAX (quem cede é a
--     escala, nunca a posição das bandas).
--
--   love . test_one test_journal_resize
--   love . test_all

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

-- ===== Janela falsa =====
local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
local fakeW, fakeH = nil, nil
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
    love.graphics.getDimensions = function() return fakeW or realW(), fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
end

-- Espelha o que love.resize faz de verdade: limpa o cache de fontes ANTES de
-- avisar a tela. Teste mais leniente que o jogo não vale nada.
local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    screen:resize()
end

-- Invariantes do layout resolvido + o detalhe de CADA parada e ramo visível.
local function auditLayout(screen)
    local Layout = require("src.ui.RunJournalLayout")
    local L = screen:_layout()
    local problems = Layout.validate(L)
    local R = Layout
    if L.rowH < R.ROW_MIN or L.rowH > R.ROW_MAX then
        problems[#problems + 1] = "altura da linha fora dos limites: " .. L.rowH
    end
    for si, S in ipairs(L.sheets) do
        if S.open then
            local function check(hover, p, label)
                local visible = p.y + L.glyph > L.zone.y and p.y - L.glyph < L.zone.y + L.zone.h
                if not visible then return end
                local tip = screen:_tipFor(L, si, hover)
                local whole = p.y - L.glyph >= L.zone.y and p.y + L.glyph <= L.zone.y + L.zone.h
                if whole and not tip then
                    problems[#problems + 1] = ("[%s %d] inteiro visível sem detalhe"):format(label, si)
                end
                for _, pr in ipairs(tip and Layout.validate(L, tip) or {}) do
                    problems[#problems + 1] = ("[%s %d] %s"):format(label, si, pr)
                end
            end
            for ni, p in ipairs(S.nodes) do check({ node = ni }, p, "parada") end
            for k, st in ipairs(S.stubs) do check({ stub = k }, st, "ramo") end
        end
    end
    return problems, L
end

local function setAll(screen, open)
    for i = 1, #screen.acts do
        if screen:isActOpen(i) ~= open then screen:toggleAct(i) end
    end
end

function M.run()
    TK.bootstrap()
    TK.seedRng(23)
    local t = TK.new("roteiro: resize")

    local Shots = require("tools.screenshot_journal")
    local Screen = require("components.RunJournalScreen")

    installFakeWindow()
    local ok, err = pcall(function()
        fakeW, fakeH = 800, 600
        local game = Shots.setupGame("short")
        local gLong = Shots.setupGame("long")
        local screen, long = Screen:new(), Screen:new()

        local sizes = {
            { 800, 600 },    -- nasce
            { 1920, 1080 },  -- cresce (fullscreen)
            { 800, 600 },    -- volta
            { 1024, 768 },   -- padrão
            { 640, 480 },    -- mínimo suportado
            { 1280, 400 },   -- largo e baixo: força o scroll
            { 420, 900 },    -- estreito e alto: espreme o mapa
        }
        local states = { { "inicial", nil }, { "tudo aberto", true }, { "tudo fechado", false } }

        local I18n = require("src.i18n.I18n")
        local prevLocale = I18n.getLocale and I18n.getLocale() or "pt_BR"
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            I18n.setLocale(loc)
            for _, s in ipairs(sizes) do
                local w, h = s[1], s[2]
                for _, sc in ipairs({ { screen, game, "curta" }, { long, gLong, "longa" } }) do
                    local scr = sc[1]
                    for _, st in ipairs(states) do
                        if scr:isVisible() then scr:hide() end
                        fakeW, fakeH = 800, 600            -- NASCE pequeno (o caminho do bug)
                        FontManager.clearCache()
                        scr:show(sc[2])
                        if st[2] ~= nil then setAll(scr, st[2]) end
                        resizeTo(scr, w, h)
                        local problems = auditLayout(scr)
                        scr:keypressed("end")
                        local p2 = auditLayout(scr)
                        for _, p in ipairs(p2) do problems[#problems + 1] = p end
                        scr:keypressed("home")
                        local p3 = auditLayout(scr)
                        for _, p in ipairs(p3) do problems[#problems + 1] = p end
                        t:eq(("%s %s %dx%d %s sem violação de zona"):format(sc[3], loc, w, h, st[1]),
                            #problems, 0)
                        for i = 1, math.min(5, #problems) do print("      -> " .. problems[i]) end
                    end
                end
            end
        end
        I18n.setLocale(prevLocale)
        screen:hide(); long:hide()

        -- ===== rolagem: a run longa com tudo aberto em janela pequena =====
        fakeW, fakeH = 640, 480
        FontManager.clearCache()
        long:show(gLong)
        t:eq("roteiro longo agrupou 7 folhas (6 atos + endless)", #long:_layout().sheets, 7)
        t:truthy("abre com o ato em andamento (endless) aberto", long:isActOpen(7))
        t:falsy("atos anteriores fechados", long:isActOpen(1) or long:isActOpen(3))
        setAll(long, true)
        long:_layout()
        t:truthy("janela pequena gera scroll", long.maxScroll > 0)

        long:wheelmoved(0, -999)
        t:truthy("rolou até o fim", long.scroll > 0)
        local deep = long.scroll
        t:eq("END/roda vão ao fim", long.scroll, long.maxScroll)

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
        t:eq("sem violação de zona no roteiro longo em 1080p", #auditLayout(long), 0)

        -- abrir um ato rola até ele ficar visível do topo (em janela baixa,
        -- onde há o que rolar: com tudo cabendo o scroll fica em zero)
        resizeTo(long, 640, 480)
        setAll(long, true)
        long:keypressed("end")
        long:toggleAct(2)      -- fecha
        long:toggleAct(2)      -- reabre: tem que rolar até ela
        local L = long:_layout()
        local Layout = require("src.ui.RunJournalLayout")
        t:truthy("abrir um ato rola pra ele aparecer", L.sheets[2].y >= L.zone.y - 1
            and L.sheets[2].y <= L.zone.y + Layout.TOP_SLACK + 1)
        long:hide()

        -- Roteiro vazio não pode explodir em nenhum tamanho.
        local empty = Screen:new()
        local g2 = TK.newRunGame("warrior")
        g2.runManager.currentRun.mapHistory = {}
        g2.runManager.currentRun.journal = {}
        g2.runManager.currentRun.journalOpen = nil
        fakeW, fakeH = 640, 480
        FontManager.clearCache()
        empty:show(g2)
        local LE = empty:_layout()
        t:eq("roteiro vazio tem zero folhas", #LE.sheets, 0)
        t:eq("roteiro vazio não gera scroll", empty.maxScroll, 0)
        t:noerror("roteiro vazio desenha", function() empty:draw() end)
        empty:hide()
    end)

    restoreWindow()
    FontManager.clearCache()
    require("src.ui.RunJournalInk").clearPaperCache()
    if not ok then print("      -> " .. tostring(err)) end
    t:truthy("nenhuma exceção durante a auditoria", ok)

    return t:done()
end

return M
