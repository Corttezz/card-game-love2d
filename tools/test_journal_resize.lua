-- tools/test_journal_resize.lua
-- Auditoria de RESIZE do Roteiro da jornada (components/RunJournalScreen.lua).
--
-- memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". A tela é
-- criada num tamanho e o layout é REAPROVEITADO noutro — é aí que o defeito
-- mora. A mesma memória registra que `love.window.setMode` repetido dentro de
-- um tool TRAVA, então a janela é FALSIFICADA (monkey-patch em
-- love.graphics.getWidth/getHeight), igual ao tools/test_forge_resize.lua.
--
-- O que este teste garante, em TODO tamanho testado:
--   • as zonas não se cruzam (trilhas ficam entre o cabeçalho e o rodapé);
--   • nenhum nó sai da janela pela esquerda/direita;
--   • o castelo nunca invade a trilha;
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

-- Invariantes geométricas do layout resolvido.
local function auditLayout(L, sw, sh)
    local problems = {}
    local zoneTop, zoneBot = L.zoneY, L.zoneY + L.zoneH

    if zoneBot > sh then
        table.insert(problems, "zona de trilhas passa do rodapé")
    end
    if L.trailX + L.trailW + L.castleW > sw then
        table.insert(problems, "trilha + castelo estouram a largura")
    end

    for bi, lb in ipairs(L.bands) do
        if lb.castle.x < L.trailX + L.trailW then
            table.insert(problems, "castelo invade a trilha na faixa " .. bi)
        end
        for ni, n in ipairs(lb.nodes) do
            local half = L.nodeSize / 2
            if n.cx - half < 0 or n.cx + half > sw then
                table.insert(problems,
                    ("nó %d/%d fora da janela (cx=%d)"):format(bi, ni, n.cx))
            end
            if n.cx + half > lb.castle.x then
                table.insert(problems,
                    ("nó %d/%d encosta no castelo"):format(bi, ni))
            end
        end
        -- Sem scroll, a faixa tem que caber na zona (se não couber, maxScroll
        -- existe e o scissor cuida do resto).
        if L.contentH <= L.zoneH then
            if lb.y < zoneTop - 1 or lb.y + lb.h > zoneBot + 1 then
                table.insert(problems, "faixa " .. bi .. " fora da zona sem scroll")
            end
        end
    end
    return problems
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

        for _, s in ipairs(sizes) do
            local w, h = s[1], s[2]
            resizeTo(screen, w, h)
            local L = screen:_layout()
            local problems = auditLayout(L, w, h)
            t:eq(("%dx%d sem violação de zona"):format(w, h),
                #problems, 0)
            if #problems > 0 then
                for _, p in ipairs(problems) do print("      -> " .. p) end
            end
            t:truthy(("%dx%d escala do nó dentro dos limites"):format(w, h),
                L.nodeSize >= 26 and L.nodeSize <= 76)
            t:truthy(("%dx%d scroll dentro do conteúdo"):format(w, h),
                screen.scroll >= 0 and screen.scroll <= screen.maxScroll + 0.001)
        end

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

        resizeTo(long, 1920, 1080)
        long:_layout()
        t:truthy("scroll reclampado ao crescer a janela",
            long.scroll <= long.maxScroll + 0.001)
        t:truthy("scroll de fato encolheu", long.scroll <= deep)
        t:eq("sem violação de zona no roteiro longo",
            #auditLayout(long:_layout(), 1920, 1080), 0)

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
