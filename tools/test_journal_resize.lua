local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

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

local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    screen:resize()
end

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
            { 800, 600 },
            { 1920, 1080 },
            { 800, 600 },
            { 1024, 768 },
            { 640, 480 },
            { 1280, 400 },
            { 420, 900 },
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
                        fakeW, fakeH = 800, 600
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

        resizeTo(long, 640, 480)
        setAll(long, true)
        long:keypressed("end")
        long:toggleAct(2)
        long:toggleAct(2)
        local L = long:_layout()
        local Layout = require("src.ui.RunJournalLayout")
        t:truthy("abrir um ato rola pra ele aparecer", L.sheets[2].y >= L.zone.y - 1
            and L.sheets[2].y <= L.zone.y + Layout.TOP_SLACK + 1)
        long:hide()

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
