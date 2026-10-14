-- tools/test_journal_map.lua
-- TRAVA do Roteiro como MAPA À MÃO (components/RunJournalScreen.lua +
-- src/ui/RunJournalLayout.lua + src/ui/RunJournalInk.lua), Out/2026.
--
-- O que fixa (pedido do dono: "literalmente um mapa... à mão, só tinta preta
-- e no máximo um círculo vermelho, folha envelhecida, abre e fecha por ato"):
--   • a encruzilhada grava os ramos NÃO tomados e o mapa os DESENHA
--     (pixels de tinta no retângulo de cada ramo);
--   • o caminho percorrido é CONTÍNUO: cada parada liga à anterior (estrutura
--     do layout + amostragem de pixels ao longo de cada trecho);
--   • exatamente UM círculo vermelho, em volta da parada atual;
--   • nenhuma cor fora da família papel/tinta/vermelho na captura inteira;
--   • atos anteriores nascem FECHADOS e o atual ABERTO; clique e teclado
--     abrem/fecham; o layout valida em todo estado;
--   • entrada sem `branches` (save antigo) desenha só o caminho.
--
-- Render em canvas com janela FALSIFICADA (sem setMode), como o
-- tools/screenshot_journal.lua; a escala de UI fica em 1 (testkit).
--
--   love . test_one test_journal_map

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

-- ===== janela e mouse falsos =====
local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
local fakeW, fakeH = 1024, 768
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW end
    love.graphics.getHeight = function() return fakeH end
    love.graphics.getDimensions = function() return fakeW, fakeH end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
end
local mx, my = -100, -100
local realMP, realMX, realMY = love.mouse.getPosition, love.mouse.getX, love.mouse.getY
local function installFakeMouse()
    love.mouse.getPosition = function() return mx, my end
    love.mouse.getX = function() return mx end
    love.mouse.getY = function() return my end
end
local function restoreMouse()
    love.mouse.getPosition, love.mouse.getX, love.mouse.getY = realMP, realMX, realMY
end

local function render(screen)
    local canvas = love.graphics.newCanvas(fakeW, fakeH)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    love.graphics.pop()
    local id = canvas:newImageData()
    canvas:release()
    return id
end

-- ===== classificação de cor =====
-- papel/tinta: família sépia (r >= g >= b, com as razões do PARCHMENT ao INK);
-- vermelho: r dominante (BLOOD); preto: a mesa. Fora disso é cor estranha.
local function classify(r, g, b)
    local mx_ = math.max(r, g, b)
    if mx_ < 0.13 then return "ink" end
    if r > 0.28 and g / r < 0.42 and b / r < 0.42 then return "red" end
    if r >= g - 0.02 and g >= b - 0.02 then
        local gr, br = g / r, b / r
        if gr >= 0.5 and gr <= 0.97 and br >= 0.25 and br <= 0.8 then return "sepia" end
    end
    return "foreign"
end

local function isInk(r, g, b)   -- tinta (cheia ou esmaecida) sobre papel
    return math.max(r, g, b) < 0.5
end

function M.run()
    TK.bootstrap()
    TK.seedRng(29)
    local t = TK.new("roteiro: mapa a mao")
    local I18n = require("src.i18n.I18n")
    I18n.setLocale("pt_BR")

    local Shots = require("tools.screenshot_journal")
    local Layout = require("src.ui.RunJournalLayout")
    local Screen = require("components.RunJournalScreen")

    installFakeWindow()
    installFakeMouse()
    local ok, err = pcall(function()
        local game = Shots.setupGame("short")
        local rm = game.runManager
        local screen = Screen:new()

        -- ===== dado: os ramos foram gravados =====
        local j = rm:getJournal()
        local withBranches = 0
        for _, e in ipairs(j) do if e.branches and #e.branches > 1 then withBranches = withBranches + 1 end end
        t:truthy("cenário tem encruzilhadas gravadas", withBranches >= 6)
        t:falsy("nó de backfill não tem ramos", j[1].branches)

        for _, size in ipairs({ { 1024, 768 }, { 1920, 1080 }, { 640, 480 } }) do
            fakeW, fakeH = size[1], size[2]
            FontManager.clearCache()
            mx, my = -100, -100
            screen:show(game)
            local tag = ("%dx%d"):format(fakeW, fakeH)

            -- ===== acordeão: anteriores fechados, atual aberto =====
            t:eq(tag .. " duas folhas (dois atos)", #screen.acts, 2)
            t:falsy(tag .. " ato anterior nasce fechado", screen:isActOpen(1))
            t:truthy(tag .. " ato atual nasce aberto", screen:isActOpen(2))

            local L = screen:_layout()
            local problems = Layout.validate(L)
            t:eq(tag .. " layout sem violação de zona", #problems, 0)
            for i = 1, math.min(5, #problems) do print("      -> " .. problems[i]) end

            local S = L.sheets[2]
            t:truthy(tag .. " folha aberta tem mapa", S and S.open and S.map)
            t:truthy(tag .. " ramos não tomados existem no layout", S and #S.stubs >= 4)
            t:truthy(tag .. " encruzilhada em aberto desenhada à frente", S and S.pending and #S.pending == 3)
            t:eq(tag .. " castelo ainda não alcançado", S and S.castle and S.castle.reached, false)

            -- ===== pixels =====
            local id = render(screen)
            local counts = { ink = 0, red = 0, sepia = 0, foreign = 0 }
            local redMinX, redMinY, redMaxX, redMaxY = 1e9, 1e9, -1, -1
            local foreignSample = nil
            for y = 0, fakeH - 1 do
                for x = 0, fakeW - 1 do
                    local r, g, b = id:getPixel(x, y)
                    local c = classify(r, g, b)
                    counts[c] = counts[c] + 1
                    if c == "red" then
                        if x < redMinX then redMinX = x end
                        if y < redMinY then redMinY = y end
                        if x > redMaxX then redMaxX = x end
                        if y > redMaxY then redMaxY = y end
                    elseif c == "foreign" and not foreignSample then
                        foreignSample = ("(%d,%d)=%.2f,%.2f,%.2f"):format(x, y, r, g, b)
                    end
                end
            end
            t:eq(tag .. " nenhuma cor fora de papel/tinta/vermelho", counts.foreign, 0)
            if foreignSample then print("      -> primeira cor estranha em " .. foreignSample) end
            t:truthy(tag .. " há papel na captura", counts.sepia > fakeW * fakeH * 0.2)

            -- ===== exatamente um círculo vermelho, na parada atual =====
            t:truthy(tag .. " há tinta vermelha", counts.red >= 20)
            local cur, curIdx
            for k, e in ipairs(S.src.nodes) do
                if rm:isJournalEntryOpen(e) then cur, curIdx = S.nodes[k], k end
            end
            t:truthy(tag .. " a parada atual está no mapa", cur ~= nil)
            if cur then
                local r = math.floor(L.glyph / 2) + 4 + L.glyphScale + 4
                t:truthy(tag .. " todo vermelho fica em volta da parada atual (um círculo só)",
                    redMinX >= cur.x - r and redMaxX <= cur.x + r
                    and redMinY >= cur.y - r and redMaxY <= cur.y + r)
                t:truthy(tag .. " o círculo tem diâmetro de círculo",
                    redMaxX - redMinX >= L.glyph and redMaxY - redMinY >= L.glyph)
            end

            -- ===== caminho contínuo: tinta ao longo de cada trecho =====
            t:eq(tag .. " um trecho por par de paradas", #S.segments, #S.nodes - 1)
            local total, hit = 0, 0
            for _, seg in ipairs(S.segments) do
                local dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
                local len = math.sqrt(dx * dx + dy * dy)
                local n = math.max(2, math.floor(len / 4))
                for s = 1, n - 1 do
                    local px = math.floor(seg.x1 + dx * s / n + 0.5)
                    local py = math.floor(seg.y1 + dy * s / n + 0.5)
                    total = total + 1
                    local found = false
                    for oy = -3, 3 do
                        for ox = -3, 3 do
                            local xx, yy = px + ox, py + oy
                            if xx >= 0 and yy >= 0 and xx < fakeW and yy < fakeH then
                                if isInk(id:getPixel(xx, yy)) then found = true end
                            end
                        end
                    end
                    if found then hit = hit + 1 end
                end
            end
            t:truthy(tag .. " caminho percorrido contínuo (tinta em todo o trecho)",
                total > 0 and hit / total >= 0.95)

            -- ===== ramos não tomados desenhados =====
            local drawn = 0
            for _, st in ipairs(S.stubs) do
                local gr = Layout.glyphRect(L, st)
                local dark = 0
                for y = gr.y, gr.y + gr.h - 1 do
                    for x = gr.x, gr.x + gr.w - 1 do
                        if x >= 0 and y >= 0 and x < fakeW and y < fakeH then
                            local r, g, b = id:getPixel(x, y)
                            if math.max(r, g, b) < 0.62 then dark = dark + 1 end
                        end
                    end
                end
                if dark >= 5 then drawn = drawn + 1 end
            end
            t:eq(tag .. " todo ramo não tomado tem tinta", drawn, #S.stubs)

            -- ===== detalhe (hover) de cada parada e ramo cabe nas zonas =====
            for k, p in ipairs(S.nodes) do
                local tip = screen:_tipFor(L, 2, { node = k })
                t:truthy(tag .. " parada " .. k .. " tem detalhe", tip ~= nil)
                if tip then
                    local pr = Layout.validate(L, tip)
                    t:eq(tag .. " detalhe da parada " .. k .. " dentro das zonas", #pr, 0)
                end
            end
            local tipS = screen:_tipFor(L, 2, { stub = 1 })
            t:truthy(tag .. " ramo não tomado tem detalhe", tipS ~= nil)

            -- ===== abrir/fechar: clique e teclado =====
            -- (abre no ato atual; em janela baixa o título do ato 1 está
            -- rolado pra fora da zona, então primeiro HOME)
            screen._openedAt = 0
            screen:keypressed("home")
            L = screen:_layout()
            local t1 = L.sheets[1].title
            screen:mousereleased(t1.x + 20, t1.y + t1.h / 2, 1)
            t:truthy(tag .. " clique no título abre o ato 1", screen:isActOpen(1))
            L = screen:_layout()
            t:eq(tag .. " layout válido com os dois abertos", #Layout.validate(L), 0)
            local S1 = L.sheets[1]
            t:truthy(tag .. " ato conquistado chega ao castelo", S1.castle and S1.castle.reached)
            t:eq(tag .. " ato 1 tem as 8 paradas", #S1.nodes, 8)
            t:truthy(tag .. " ato 1 aberto rolou pra ficar visível", S1.y >= L.zone.y - 1)
            -- nenhum círculo vermelho no ato conquistado
            local id2 = render(screen)
            local redInS1 = 0
            for y = math.max(0, S1.y), math.min(fakeH - 1, S1.y + S1.h) do
                for x = math.max(0, S1.x), math.min(fakeW - 1, S1.x + S1.w) do
                    if classify(id2:getPixel(x, y)) == "red" then redInS1 = redInS1 + 1 end
                end
            end
            t:eq(tag .. " ato conquistado não tem círculo vermelho", redInS1, 0)

            t1 = L.sheets[1].title
            screen:mousereleased(t1.x + 20, t1.y + t1.h / 2, 1)
            t:falsy(tag .. " segundo clique fecha o ato 1", screen:isActOpen(1))

            -- teclado: Enter sobre o título (sem foco do NavCursor, vale o mouse)
            screen:keypressed("home")
            L = screen:_layout()
            t1 = L.sheets[1].title
            mx, my = t1.x + 20, t1.y + t1.h / 2
            screen:keypressed("return")
            t:truthy(tag .. " Enter sobre o título abre", screen:isActOpen(1))
            screen:keypressed("return")
            t:falsy(tag .. " Enter de novo fecha", screen:isActOpen(1))
            mx, my = -100, -100
            screen:keypressed("2")
            t:falsy(tag .. " tecla 2 fecha o ato 2", screen:isActOpen(2))
            screen:keypressed("2")
            t:truthy(tag .. " tecla 2 reabre o ato 2", screen:isActOpen(2))
            L = screen:_layout()
            t:eq(tag .. " layout válido depois do teclado", #Layout.validate(L), 0)

            -- Esc fecha a tela
            screen:keypressed("escape")
            t:falsy(tag .. " Esc fecha o roteiro", screen:isVisible())
        end

        -- ===== save antigo: entrada sem ramos desenha só o caminho =====
        do
            local g2 = TK.newRunGame("warrior")
            local r2 = g2.runManager
            local run = r2.currentRun
            run.mapHistory, run.journal, run.journalOpen, run.pendingNodes = {}, {}, nil, nil
            for fl = 1, 3 do
                run.actNumber, run.floorInAct, run.currentFloor = 1, fl, fl
                table.insert(run.mapHistory, { actNumber = 1, floorInAct = fl, type = "battle" })
                r2:journalBegin({ type = "battle" }, { hp = 50, maxHp = 60, gold = 10 })
                r2:journalEnd({ hp = 45, gold = 20 })
            end
            fakeW, fakeH = 1024, 768
            FontManager.clearCache()
            local s2 = Screen:new()
            s2:show(g2)
            local L = s2:_layout()
            t:eq("save antigo: zero ramos no layout", #L.sheets[1].stubs, 0)
            t:eq("save antigo: três paradas", #L.sheets[1].nodes, 3)
            t:eq("save antigo: layout válido", #Layout.validate(L), 0)
            t:noerror("save antigo: desenha", function() render(s2) end)
            s2:hide()
        end
    end)

    restoreMouse()
    restoreWindow()
    FontManager.clearCache()
    require("src.ui.RunJournalInk").clearPaperCache()
    if not ok then print("      -> " .. tostring(err)) end
    t:truthy("nenhuma exceção durante a auditoria", ok)
    return t:done()
end

return M
