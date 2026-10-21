local TK = require("tools.testkit")

local M = {}

local SIZES = {
    { 1024, 768, 1 }, { 1280, 720, 1 }, { 1280, 720, 1.5 }, { 1280, 720, 2 },
    { 1366, 768, 1 }, { 1280, 800, 1.25 }, { 1720, 720, 2 },
}

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local function lum(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function checkLayouts(t, Bestiary, Layout, Card, I18n)
    local entries = Bestiary.entries()
    for _, loc in ipairs(I18n.available) do
        I18n.setLocale(loc, true)
        local bad = {}
        for _, sz in ipairs(SIZES) do
            local sw, sh, k = sz[1], sz[2], sz[3]
            local G = Layout.grid(sw, sh, 114, sh - 36, k, entries)
            for _, p in ipairs(Layout.validateGrid(G, sw, sh)) do
                bad[#bad + 1] = ("%dx%d@%.2f grade: %s"):format(sw, sh, k, p)
            end
            local Grid = require("src.ui.BestiaryGrid")
            for act, ch in pairs(G.chips) do
                local _, tw = Grid.ribbonText(ch)
                local n = #Grid.ribbonLines(nil, act, tw)
                if n > 2 then bad[#bad + 1] = ("%dx%d marcador do ato %d em %d linhas"):format(sw, sh, act, n) end
            end
            for _, e in ipairs(entries) do
                for _, defeated in ipairs({ true, false }) do
                    local texts = Card.texts(e)
                    if defeated then
                        texts.movesHint = nil
                    elseif not texts.movesHint then
                        texts.movesHint = I18n.t("bestiary.ui.moves_hidden")
                    end
                    local C = Layout.card(sw, sh, k, texts)
                    for _, p in ipairs(Layout.validateCard(C, sw, sh, texts)) do
                        bad[#bad + 1] = ("%dx%d@%.2f %s: %s"):format(sw, sh, k, e.id, p)
                    end
                end
            end
        end
        t:eq("layout valido (grade e fichas, 42 criaturas, 7 tamanhos) em " .. loc, #bad, 0)
        for i = 1, math.min(4, #bad) do t:check("  " .. bad[i], false) end
    end
    I18n.setLocale("pt_BR", true)
end

local function frame(screen, canvas)
    local NC = require("src.ui.NavCursor")
    local IF = require("src.ui.InputFocus")
    NC.beginFrame()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    IF.push(IF.SCENE)
    screen:draw()
    IF.pop()
    love.graphics.setCanvas()
    NC.beginFrame()
    love.graphics.setCanvas(canvas)
    IF.push(IF.SCENE)
    screen:draw()
    IF.pop()
    love.graphics.setCanvas()
end

function M.run()
    TK.bootstrap()
    local t = TK.new("bestiario: aba, ficha e fim de corrida")
    local I18n = require("src.i18n.I18n")
    local ProfileStats = require("engine.ProfileStats")
    local Bestiary = require("src.systems.Bestiary")
    local Layout = require("src.ui.BestiaryLayout")
    local Card = require("src.ui.BestiaryCard")
    local Sprites = require("src.ui.BestiarySprites")
    local NC = require("src.ui.NavCursor")
    local IF = require("src.ui.InputFocus")
    local prevProfile = ProfileStats._swapForTests({})
    Bestiary._resetForTests()
    local restore = fakeWindow(1280, 720)
    local realMouse = love.mouse.getPosition
    local realPressed, realReleased, realWheel = love.mousepressed, love.mousereleased, love.wheelmoved
    local mx, my = -50, -50
    love.mouse.getPosition = function()
        local px, py = NC.position()
        if px then return px, py end
        return mx, my
    end
    local canvas = love.graphics.newCanvas(1280, 720)
    local ok, err = pcall(function()
        I18n.setLocale("pt_BR", true)
        checkLayouts(t, Bestiary, Layout, Card, I18n)

        local entries = Bestiary.entries()
        local seenIds = { "cursed_scarecrow", "hollow_farmer", "carrion_king", "tower_lich", "ember_imp" }
        for _, id in ipairs(seenIds) do Bestiary.markSeen(id) end
        Bestiary.markDefeated("cursed_scarecrow")
        for _, id in ipairs(seenIds) do
            if id ~= "hollow_farmer" and id ~= "ember_imp" then Bestiary.clearNew(id) end
        end

        local Screen = require("components.CollectionScreen")
        local s = Screen:new()
        s:show(function() end)
        s:setSection("creatures")
        local grid = s.bestiary
        for _ = 1, 600 do
            Sprites.pump(1)
            if Sprites.pendingCount() == 0 then break end
        end
        s:update(1 / 60)
        frame(s, canvas)

        local function indexOf(id)
            for i, e in ipairs(grid.entries) do if e.id == id then return i end end
        end
        local G = grid:layout()
        local Card = require("src.ui.BestiaryCard")
        local realDraw = Card.drawSprite
        local drawn = {}
        Card.drawSprite = function(id, ...)
            drawn[id] = true
            return realDraw(id, ...)
        end
        grid:setScroll(0, true)
        frame(s, canvas)
        Card.drawSprite = realDraw
        t:falsy("nao descoberta: nada da criatura na pagina (sem silhueta)", drawn.blight_bull)
        t:eq("nao descoberta: nenhum quadro do sprite carregado", Sprites.get("blight_bull").loaded, 0)
        t:truthy("descoberta desenha a criatura", drawn.cursed_scarecrow)
        t:falsy("nao descoberta nao abre a ficha", grid:open(indexOf("blight_bull")))

        t:truthy("aba Criaturas com '!' enquanto ha nova", s:sectionHasNew("creatures"))
        t:truthy("fixture: Lavrador Oco nova", Bestiary.isNew("hollow_farmer"))
        local fx, fy, fw, fh = grid:cellScreen(indexOf("hollow_farmer"))
        mx, my = fx + fw / 2, fy + fh / 2
        s:update(1 / 60)
        t:falsy("'!' some ao passar o mouse", Bestiary.isNew("hollow_farmer"))
        t:truthy("outra nova continua com '!'", Bestiary.isNew("ember_imp"))
        mx, my = -50, -50
        s:update(1 / 60)

        love.mousepressed = function(x, y, b) s:mousepressed(x, y, b) end
        love.mousereleased = function(x, y, b) s:mousereleased(x, y, b) end
        love.wheelmoved = function(x, y) s:wheelmoved(x, y) end
        local visited = {}
        local function predecessor(i)
            local c = G.cells[i]
            local best, bd
            for j, d in pairs(G.cells) do
                if j ~= i and d.y == c.y and d.x < c.x and (not bd or c.x - d.x < bd) then best, bd = j, c.x - d.x end
            end
            if best then return best, "right" end
            local up = grid:columnNeighbor(i, -1)
            if up then return up, "down" end
            return nil, "down"
        end
        for i in pairs(G.cells) do
            local from, dir = predecessor(i)
            local c = G.cells[i]
            NC._reset()
            local view = G.viewH
            local target = c.y + math.min(c.h * 0.6, 110) - view
            if from then
                local d = G.cells[from]
                if dir == "right" then target = math.min(c.y, d.y) - 8 end
                if dir == "down" and c.y + 120 - (d.y + 10) > view then target = d.y end
            else
                target = 0
            end
            grid:setScroll(math.max(0, target), true)
            s:update(1 / 60)
            frame(s, canvas)
            if from then
                local fx, fy, fw, fh = grid:cellScreen(from)
                local vy0 = math.max(fy, G.top)
                local vy1 = math.min(fy + fh, G.bottom)
                NC.mouseMoved(fx + fw / 2, (vy0 + vy1) / 2)
            else
                local ch = G.chips[c.act]
                NC.mouseMoved(ch.x + ch.w / 2, ch.y + ch.h / 2)
            end
            NC.intent(dir, "keyboard")
            NC.intent(dir, "keyboard")
            local key = NC.focusKey()
            local got = type(key) == "string" and tonumber(key:match("^bst:(%d+)$"))
            if got == i then visited[i] = true end
        end
        local missing = {}
        for i = 1, #grid.entries do if not visited[i] then missing[#missing + 1] = grid.entries[i].id end end
        t:eq("teclado: cada celula a uma seta da vizinha (" .. table.concat(missing, ",") .. ")", #missing, 0)

        NC._reset()
        grid:setScroll(0, true)
        s:update(1 / 60)
        frame(s, canvas)
        local kx, ky, kw, kh = grid:cellScreen(indexOf("cursed_scarecrow"))
        NC.mouseMoved(kx + kw / 2, ky + kh / 2)
        NC.intent("down", "keyboard")
        s:update(1 / 60)
        frame(s, canvas)
        t:truthy("NavCursor nao toma o teclado com a grade", NC.claimsInput("collection", s:ownsNavigation()))
        NC.intent("confirm", "keyboard")
        t:truthy("Enter no foco abre a ficha", grid:isOpen())
        t:eq("ficha da criatura focada", grid:openEntry() and grid:openEntry().id, "cursed_scarecrow")
        t:truthy("ficha aberta toma a navegacao", s:ownsNavigation())
        s:keypressed("right")
        t:eq("seta direita pula para a proxima descoberta", grid:openEntry().id, "hollow_farmer")
        s:keypressed("left")
        s:update(1 / 60)
        frame(s, canvas)
        local C, texts = grid:cardLayout()
        t:eq("ficha valida na tela", #Layout.validateCard(C, 1280, 720, texts), 0)
        s:keypressed("escape")
        t:falsy("Esc fecha a ficha", grid:isOpen())
        t:truthy("Esc da ficha nao fecha a colecao", s:isVisible())

        local ES = require("src.scenes.EndScreens")
        local function hasLine()
            local label = I18n.t("bestiary.ui.end_label")
            for _, c in ipairs(ES.summary("gameOver", nil).cells) do
                if c.label == label then return c.value end
            end
        end
        local run = {}
        Bestiary.resetRun(run)
        t:falsy("fim de corrida sem criatura nova: sem a linha", hasLine())
        Bestiary.markSeen("frost_wolf")
        Bestiary.markSeen("dusk_bat")
        t:eq("fim de corrida com 2 novas: linha com 2", hasLine(), "2")

        local prevReduced = _G.gameSettings and _G.gameSettings.reducedMotion
        _G.gameSettings = _G.gameSettings or {}
        _G.gameSettings.reducedMotion = true
        local f0 = Sprites.frameAt("carrion_king", 0)
        local f1 = Sprites.frameAt("carrion_king", 0.7)
        t:truthy("reducedMotion para a animacao no quadro 0", f0 ~= nil and f0 == f1)
        _G.gameSettings.reducedMotion = false
        local moved = false
        for k = 1, 12 do if Sprites.frameAt("carrion_king", k * 0.13) ~= f0 then moved = true end end
        t:truthy("sem reducedMotion o idle anda", moved)
        _G.gameSettings.reducedMotion = prevReduced
        s:hide()
    end)
    love.mouse.getPosition = realMouse
    love.mousepressed, love.mousereleased, love.wheelmoved = realPressed, realReleased, realWheel
    restore()
    NC._reset()
    canvas:release()
    ProfileStats._swapForTests(prevProfile)
    Bestiary._resetForTests()
    if not ok then t:check("sem erro: " .. tostring(err), false) end
    return t:done()
end

return M
