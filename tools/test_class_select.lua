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

    for _, id in ipairs({ "warrior", "mage", "rogue" }) do
        local info = US.getClassUnlockInfo(id)
        local m = US.getClassMastery(id)
        t:truthy("unlockInfo(" .. id .. ") tem reqKey/goal",
            type(info) == "table" and type(info.reqKey) == "string" and type(info.goal) == "number")
        t:truthy("mastery(" .. id .. ") tem level/maxLevel",
            type(m) == "table" and type(m.level) == "number" and type(m.maxLevel) == "number")
    end
    t:truthy("guerreiro liberado por padrão", US.isClassUnlocked("warrior"))

    local ClassEmblem = require("src.ui.ClassEmblem")
    for _, id in ipairs({ "warrior", "mage", "rogue", "locked_chains" }) do
        t:truthy("emblema carrega: " .. id, ClassEmblem.get(id) and true or false)
    end
    t:falsy("heróis chibi aposentados (pasta removida)",
        love.filesystem.getInfo("assets/sprites/characters/heroes"))

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

        t:eq("página abre no resumo", screen.pageMode, "summary")
        screen:toggleDetails()
        t:eq("marcador abre os detalhes", screen.pageMode, "details")
        screen:keypressed("tab")
        t:eq("tab volta ao resumo", screen.pageMode, "summary")
        screen:keypressed("d")
        t:eq("tecla D passa pra próxima classe", screen.focus, "rogue")
        screen:keypressed("a")
        t:eq("tecla A volta", screen.focus, "mage")

        click(screen.buttons.start)
        TK.pump(nil, 0.6)
        t:eq("COMEÇAR inicia a run da classe em foco", started[1], "mage")

        do
            lockOnly(US, {})
            fakeW, fakeH = 1280, 720
            FontManager.clearCache()
            local backs = 0
            local s3 = Screen:new()
            s3:show(function() end, function() backs = backs + 1 end)
            s3:focusClass("mage")
            TK.pump(nil, 0.6)
            local canvas = love.graphics.newCanvas(1280, 720)
            local simNow = 1000
            local realGetTime = love.timer.getTime
            local function frame()
                simNow = simNow + 1 / 60
                love.timer.getTime = function() return simNow end
                love.graphics.setCanvas(canvas)
                local okF, errF = pcall(function()
                    require("src.ui.CardFrame").update()
                    s3:update(1 / 60)
                    s3:draw()
                end)
                love.graphics.setCanvas()
                love.timer.getTime = realGetTime
                if not okF then error(errF, 0) end
            end
            s3:toggleDetails()
            frame()
            local rects = s3._starterRects or {}
            t:truthy("detalhes: cartas iniciais posicionadas", #rects >= 2)
            local p3 = s3:_panelOf(s3.focus)
            local c1 = p3.cards[1]
            local k = UiScale.k()
            local r1 = rects[1]
            mx, my = (r1.x + r1.w / 2) * k, (r1.y + r1.h * 0.6) * k
            for _ = 1, 12 do frame() end
            t:truthy("hover na carta inicial: carta em hover", c1.isHovered)
            t:truthy("hover levanta a carta (sobe da folha)", (c1.liftOffset or 0) < 0)
            t:truthy("hover abre o tooltip (CardInfoDisplay)",
                c1.cardInfoDisplay and c1.cardInfoDisplay.lastRect ~= nil)
            do
                local CardFrame = require("src.ui.CardFrame")
                local CardArt = require("src.ui.CardArt")
                local IFL = require("src.ui.IconFramesLoader")
                local art = CardArt.resolve(c1)
                t:truthy("fixture: a 1ª inicial do mago tem ícone animado",
                    art.iconName and IFL.has(art.iconName) or false)
                local static1 = c1.image
                for _ = 1, 40 do frame() end
                t:truthy("carta inicial animada tem quadro vivo",
                    CardFrame.liveImage(c1) ~= nil)
                t:eq("fora do draw a carta volta à imagem estática", c1.image, static1)
            end
            local drawn = {}
            local function spy(inst, i)
                local real = inst.drawDeferredTooltip
                inst.drawDeferredTooltip = function(self, ...)
                    local ok = real(self, ...)
                    if ok then drawn[#drawn + 1] = i end
                    return ok
                end
                return real
            end
            local real1, real2 = spy(p3.cards[1], 1), spy(p3.cards[2], 2)
            local r2 = rects[2]
            mx, my = (r2.x + r2.w / 2) * k, (r2.y + r2.h * 0.6) * k
            for _ = 1, 12 do frame() end
            drawn = {}
            frame()
            t:eq("hover na 2ª carta: exatamente um tooltip", #drawn, 1)
            t:eq("o tooltip é o da 2ª carta", drawn[1], 2)
            t:falsy("a 1ª saiu do hover", c1.isHovered)
            mx, my = (r1.x + r1.w / 2) * k, (r1.y + r1.h * 0.6) * k
            for _ = 1, 12 do frame() end
            s3:mousepressed(mx, my, 1)
            s3:mousereleased(mx, my, 1)
            t:truthy("clique abre a inspeção", s3.inspectModal:isVisible())
            t:eq("inspeção na carta clicada", s3.inspectModal.card, c1)
            t:truthy("handle do InputFocus visível (captura teclado/pad)", s3.inspectHandle.isVisible())
            t:truthy("handle navega sozinho (NavCursor não anda por trás)", s3.inspectHandle.ownsNavigation)
            drawn = {}
            frame()
            t:eq("inspeção aberta: nenhum tooltip de carta inicial", #drawn, 0)
            s3.inspectHandle:keypressed("right")
            t:eq("seta passa pra próxima inicial", s3.inspectModal.card, p3.cards[2])
            s3.inspectHandle:keypressed("escape")
            t:falsy("Esc fecha a inspeção", s3.inspectModal:isVisible())
            t:eq("Esc com a inspeção aberta não volta ao menu", backs, 0)
            for _ = 1, 3 do frame() end
            s3:mousepressed(mx, my, 2)
            t:truthy("botão direito também inspeciona", s3.inspectModal:isVisible())
            s3.inspectHandle:keypressed("return")
            t:falsy("A/Enter fecha", s3.inspectModal:isVisible())
            local T = require("src.systems.Tutorial")
            local ov = T.overlay
            local prevVis = ov and ov.isVisible
            if ov then ov.isVisible = function() return true end end
            t:falsy("corvo falando: inspeção não abre", s3:openInspect(1))
            if ov then ov.isVisible = prevVis end
            s3:toggleDetails()
            for _ = 1, 3 do frame() end
            t:falsy("resumo: sem hover em carta inicial", c1.isHovered)
            s3:mousepressed(mx, my, 1)
            t:falsy("resumo: clique ali não inspeciona", s3.inspectModal:isVisible())
            p3.cards[1].drawDeferredTooltip, p3.cards[2].drawDeferredTooltip = real1, real2
            canvas:release()
            mx, my = 1, 1
        end

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
            local paused = false
            local okHB, HB = pcall(require, "src.ui.HelpBadge")
            local realHB = okHB and HB.draw
            if realHB then
                HB.draw = function(...)
                    paused = true
                    local r = { realHB(...) }
                    paused = false
                    return unpack(r)
                end
            end
            FontManager.getFont = function(size, ...)
                if not paused then sizes[size] = true end
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
            if realHB then HB.draw = realHB end
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
