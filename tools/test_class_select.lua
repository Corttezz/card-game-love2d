-- tools/test_class_select.lua
-- Trava da seleção de classe v4 ("página do grimório": uma classe em foco,
-- detalhes sob demanda, Out/2026 — memory/class_emblems.md).
--
-- O que garante:
--   • o layout de ZONAS (ClassSelectLayout) é válido em todo tamanho de
--     janela suportado (800×600 até 2560×1440) — nenhuma banda encosta;
--   • o resize() de verdade (janela falsificada, cache de fonte limpo)
--     reposiciona os botões no layout novo e o draw não explode;
--   • a tela usa no máximo DUAS fontes (nome e corpo);
--   • foco × início: o emblema pequeno só troca o foco, COMEÇAR inicia;
--   • classe BLOQUEADA: selectClass devolve false e o callback NUNCA roda —
--     nem por clique direto (mousepressed/released no painel);
--   • classe LIBERADA: o callback roda com o id certo;
--   • os assets dos emblemas e das correntes existem e carregam;
--   • nenhuma referência sobrou aos heróis chibi aposentados.
--
-- O UnlockSystem é dirigido por monkeypatch das 3 funções do CONTRATO —
-- vale pro stub e pra versão real da frente progressão.
--
--   love . test_one test_class_select
--   love . test_all

local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

local SIZES = {
    { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 },
    { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 },
}

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local realMouse = love.mouse.getPosition
local fakeW, fakeH, mx, my
local function installFake()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
    love.mouse.getPosition = function() return mx or 1, my or 1 end
end
local function restore()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.mouse.getPosition = realMouse
end

local function lockOnly(US, lockedSet)
    US.isClassUnlocked = function(id) return not lockedSet[id] end
    US.getClassUnlockInfo = function(id)
        if lockedSet[id] then
            return { unlocked = false, reqKey = "unlock.class." .. id .. "_req",
                     vars = { act = 2 }, progress = 1, goal = 2 }
        end
        return { unlocked = true, reqKey = "unlock.class.default", vars = {}, progress = 1, goal = 1 }
    end
    US.getClassMastery = function() return { level = 2, maxLevel = 5, xp = 10, xpToNext = 100 } end
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_class_select")
    local Layout = require("src.ui.ClassSelectLayout")
    local US = require("src.systems.UnlockSystem")
    local orig = { US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery }

    -- 0. contrato do UnlockSystem (stub ou real) responde pras 3 classes
    for _, id in ipairs({ "warrior", "mage", "rogue" }) do
        local info = US.getClassUnlockInfo(id)
        local m = US.getClassMastery(id)
        t:truthy("unlockInfo(" .. id .. ") tem reqKey/goal",
            type(info) == "table" and type(info.reqKey) == "string" and type(info.goal) == "number")
        t:truthy("mastery(" .. id .. ") tem level/maxLevel",
            type(m) == "table" and type(m.level) == "number" and type(m.maxLevel) == "number")
    end
    t:truthy("guerreiro liberado por padrão", US.isClassUnlocked("warrior"))

    -- 1. assets
    local ClassEmblem = require("src.ui.ClassEmblem")
    for _, id in ipairs({ "warrior", "mage", "rogue", "locked_chains" }) do
        t:truthy("emblema carrega: " .. id, ClassEmblem.get(id) and true or false)
    end
    t:falsy("heróis chibi aposentados (pasta removida)",
        love.filesystem.getInfo("assets/sprites/characters/heroes"))

    -- 2. layout puro em todos os tamanhos (no espaço VIRTUAL do UiScale,
    --    que é onde a tela desenha)
    local UiScale = require("src.ui.UiScale")
    for _, sz in ipairs(SIZES) do
        local k = UiScale.k(sz[1], sz[2])
        local L = Layout.compute(math.floor(sz[1] / k), math.floor(sz[2] / k), 3)
        local ok, errs = Layout.validate(L)
        t:check(("layout válido em %dx%d (k=%.2f)%s"):format(sz[1], sz[2], k,
            ok and "" or (": " .. table.concat(errs, "; "))), ok)
    end

    installFake()
    local wasPaused = _G.EventManager.paused
    _G.EventManager.paused = false
    _G.EventManager.clear("class_select")
    local okRun, err = pcall(function()
        local Screen = require("components.ClassSelectionScreen")

        -- 3. bloqueada não inicia run; liberada inicia
        lockOnly(US, { rogue = true })
        fakeW, fakeH = 1280, 720
        FontManager.clearCache()
        local started = {}
        local screen = Screen:new()
        screen:show(function(id) table.insert(started, id) end, function() end)
        t:eq("foco inicial = primeira classe liberada", screen.focus, "warrior")

        t:eq("selectClass(rogue bloqueado) recusa", screen:selectClass("rogue"), false)
        TK.pump(nil, 0.6)
        t:eq("nenhuma run iniciada pela bloqueada", #started, 0)
        local rp = screen:_panelOf("rogue")
        t:truthy("bloqueada treme (feedback do clique)", rp and rp.shake > 0)
        t:falsy("bloqueada não trava o input", screen._locked)
        t:eq("a bloqueada entra em foco (mostra a condição)", screen.focus, "rogue")
        t:falsy("bloqueada não tem COMEÇAR", screen.buttons.start.visible)
        t:falsy("bloqueada não tem DETALHES", screen.buttons.details.visible)

        -- clique de verdade no emblema pequeno: só troca o foco
        local function click(b)
            local k = UiScale.k()
            mx, my = (b.x + b.width / 2) * k, (b.y + b.height / 2) * k
            screen:update(1 / 60)
            screen:mousepressed(mx, my, 1)
            screen:mousereleased(mx, my, 1)
        end
        click(screen.buttons.mage)
        TK.pump(nil, 0.6)
        t:eq("clique no emblema pequeno troca o foco", screen.focus, "mage")
        t:eq("trocar o foco não inicia run", #started, 0)
        t:truthy("liberada tem COMEÇAR", screen.buttons.start.visible)

        -- DETALHES sob demanda
        t:eq("página abre no resumo", screen.pageMode, "summary")
        screen:toggleDetails()
        t:eq("marcador abre os detalhes", screen.pageMode, "details")
        screen:keypressed("tab")
        t:eq("tab volta ao resumo", screen.pageMode, "summary")
        screen:keypressed("d")
        t:eq("tecla D passa pra próxima classe", screen.focus, "rogue")
        screen:keypressed("a")
        t:eq("tecla A volta", screen.focus, "mage")

        -- COMEÇAR (o clique de verdade na fita)
        click(screen.buttons.start)
        TK.pump(nil, 0.6)
        t:eq("COMEÇAR inicia a run da classe em foco", started[1], "mage")

        -- 4. resize real: botões acompanham o layout + draw sem erro +
        --    só DUAS fontes na tela (nome e corpo)
        lockOnly(US, { mage = true, rogue = true })
        local s2 = Screen:new()
        s2:show(function() end, function() end)
        local realGetFont = FontManager.getFont
        for _, sz in ipairs(SIZES) do
            fakeW, fakeH = sz[1], sz[2]
            FontManager.clearCache()
            s2:resize()
            local okLay, errs = Layout.validate(s2.layout)
            t:check(("resize %dx%d: layout da tela válido%s"):format(sz[1], sz[2],
                okLay and "" or (": " .. table.concat(errs, "; "))), okLay)
            for i, id in ipairs(Screen.CLASS_ORDER) do
                local btn = s2.buttons[id]
                local m = s2.layout.medallions[i]
                t:check(("resize %dx%d: emblema %s no lugar"):format(sz[1], sz[2], id),
                    btn and btn.x == m.x and btn.y == m.y and btn.width == m.w)
            end
            local st = s2.buttons.start
            t:check(("resize %dx%d: COMEÇAR na fita"):format(sz[1], sz[2]),
                st.x == s2.layout.start.x and st.y == s2.layout.start.y)
            local sizes = {}
            FontManager.getFont = function(size, ...)
                sizes[size] = true
                return realGetFont(size, ...)
            end
            local canvas = love.graphics.newCanvas(sz[1], sz[2])
            love.graphics.setCanvas(canvas)
            local okDraw, e2 = pcall(function()
                s2:update(1 / 30)
                s2:draw()
            end)
            love.graphics.setCanvas()
            FontManager.getFont = realGetFont
            t:check(("draw %dx%d sem erro%s"):format(sz[1], sz[2], okDraw and "" or (": " .. tostring(e2))), okDraw)
            local n, list = 0, {}
            for size in pairs(sizes) do n = n + 1; list[#list + 1] = size end
            table.sort(list)
            t:check(("%dx%d: no máximo 2 tamanhos de fonte (%s)"):format(sz[1], sz[2],
                table.concat(list, ", ")), n <= 2)
            canvas:release()
        end
        FontManager.getFont = realGetFont
        t:falsy("mago bloqueado reflete no painel", s2:_panelOf("mage").unlocked)
        t:truthy("guerreiro liberado tem maestria", s2:_panelOf("warrior").mastery ~= nil)
    end)
    restore()
    _G.EventManager.paused = wasPaused
    US.isClassUnlocked, US.getClassUnlockInfo, US.getClassMastery = orig[1], orig[2], orig[3]
    FontManager.clearCache()
    t:check("sem exceção" .. (okRun and "" or (": " .. tostring(err))), okRun)

    -- 5. nenhuma referência de código aos heróis
    local hits = {}
    for _, f in ipairs({ "components/ClassSelectionScreen.lua", "main.lua", "src/ui/SpriteAnimation.lua" }) do
        local src = love.filesystem.read(f) or ""
        if src:find("characters/heroes", 1, true) or src:find("\"heroes/", 1, true) then
            table.insert(hits, f)
        end
    end
    t:eq("referências a characters/heroes no código", #hits, 0)

    return t:done()
end

return M
