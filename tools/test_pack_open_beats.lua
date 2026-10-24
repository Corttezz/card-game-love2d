local TK = require("tools.testkit")
local M = {}

local W, H = 1280, 720

local function fakeWindow()
    local g, m, t = love.graphics, love.mouse, love.timer
    local saved = { g.getWidth, g.getHeight, g.getDimensions, m.getPosition, t.getTime }
    g.getWidth = function() return W end
    g.getHeight = function() return H end
    g.getDimensions = function() return W, H end
    m.getPosition = function() return -500, -500 end
    t.getTime = function() return 12.5 end
    return function()
        g.getWidth, g.getHeight, g.getDimensions, m.getPosition, t.getTime =
            saved[1], saved[2], saved[3], saved[4], saved[5]
    end
end

local function newPack(kind, size)
    local BPS = require("src.systems.BoosterPackSystem")
    TK.seedRng(4242)
    return BPS.expandPackRecord({
        id = "pack_" .. kind:lower(), kind = kind, size = size or 3, choose = 1,
    }, "warrior")
end

local function pump(screen, secs)
    local dt = 1 / 60
    for _ = 1, math.floor(secs / dt + 0.5) do
        _G.EventManager.update(dt)
        if not screen.visible then return end
        screen:update(dt)
    end
end

local function inside(r, z, pad)
    pad = pad or 0
    return r.x >= z.x - pad and r.y >= z.y - pad
        and r.x + r.w <= z.x + z.w + pad and r.y + r.h <= z.y + z.h + pad
end

local function render(screen)
    local c = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    local d = c:newImageData()
    c:release()
    return d
end

function M.run()
    TK.bootstrap()
    local t = TK.new("test_pack_open_beats")
    local restore = fakeWindow()
    _G.gameSettings = _G.gameSettings or {}
    local prevRM = _G.gameSettings.reducedMotion
    local ok, err = pcall(function()
        local Screen = require("components.PackOpenScreen")
        local Layout = require("src.ui.PackChoiceLayout")

        _G.gameSettings.reducedMotion = false
        local s = Screen:new()
        local got
        s:show(newPack("Buffoon"), function(sel) got = sel end)
        pump(s, 0.5)
        t:falsy("abrindo: ainda nao pronto em 0,5 s", s._cardsReady)
        t:truthy("abrindo: clique adianta a abertura", s:mousepressed(10, 10, 1))
        t:truthy("adiantou: pronto na hora", s._cardsReady)
        t:truthy("adiantou: Pular ativo", s._skipReady and s.skipButton and not s.skipButton.disabled)
        t:eq("adiantou: sem pedaco nem faisca sobrando", s._burst:count(), 0)
        for i, c in ipairs(s.pack.instances) do
            local fp = s._finalCardPositions[i]
            t:check("adiantou: carta " .. i .. " na vaga e inteira",
                c._packShown and c.dissolve == 0 and c.renderX == fp.x and c.renderY == fp.y
                and (c._tagPop or 0) >= 1)
        end
        local normalReady = s._readyAt
        s:skip()
        pump(s, 1.5)
        t:falsy("Pular: tela fecha", s.visible)
        t:check("Pular: callback sem carta", got ~= nil and #got == 0)

        got = nil
        local s2 = Screen:new()
        s2:show(newPack("Arcana"), function(sel) got = sel end)
        pump(s2, 3.2)
        t:truthy("sem adiantar: fica pronto sozinho", s2._cardsReady)
        local hov = {}
        for _, c in ipairs(s2.pack.instances) do if c.isHovered then hov[#hov + 1] = tostring(c.id) end end
        t:check("mouse fora: nenhuma carta em hover (" .. table.concat(hov, ",") .. ")", #hov == 0)
        local c2 = s2.pack.instances[2]
        local cx = c2.renderX + c2.image:getWidth() * c2.currentScale * 0.5
        local cy = c2.renderY + c2.image:getHeight() * c2.currentScale * 0.5
        s2:mousepressed(cx, cy, 1)
        pump(s2, 0.4)
        t:truthy("1o clique destaca", s2.selectedCard == c2)
        t:check("destaque sobe de verdade (" .. s2:_liftMax() .. " px)", s2:_liftMax() >= 8)
        local z = s2:_z()
        local sb, se, ca = s2.skipButton, s2.selectButton, s2.cancelButton
        render(s2):release()
        t:check("zona: Pular dentro do cabecalho",
            inside({ x = sb.x, y = sb.y, w = sb.width, h = sb.height }, z.header))
        t:check("zona: Selecionar dentro da banda de acao",
            inside({ x = se.x, y = se.y, w = se.width, h = se.height }, z.action))
        t:check("zona: Cancelar dentro da banda de acao",
            inside({ x = ca.x, y = ca.y, w = ca.width, h = ca.height }, z.action))
        for _, c in ipairs(s2.pack.instances) do
            local rx, ry, rw, rh = s2:_tagRect(c)
            t:check("zona: etiqueta de " .. tostring(c.id) .. " na banda das etiquetas",
                inside({ x = rx, y = ry, w = rw, h = rh }, z.tags))
        end
        t:check("zona: carta destacada nao invade o cabecalho",
            c2.renderY - (c2._selLift or 0) - s2:_overhang() >= z.header.y + z.header.h - 0.5)
        local okL, probs = Layout.validate(z, W, H)
        t:check("zonas validas" .. (okL and "" or (": " .. table.concat(probs, "; "))), okL)
        s2:mousepressed(cx, cy - (c2._selLift or 0), 1)
        pump(s2, 1.5)
        t:falsy("2o clique confirma e fecha", s2.visible)
        t:check("confirmou a carta clicada", got ~= nil and got[1] == c2)

        local s5 = Screen:new()
        s5:show(newPack("Celestial", 5), function() end)
        pump(s5, 1.6)
        for _, size in ipairs({ { 1920, 1080 }, { 1024, 600 }, { 1280, 720 } }) do
            W, H = size[1], size[2]
            s5:resize()
            pump(s5, 2.0)
            local zz = s5:_z()
            local okZ, pr = Layout.validate(zz, W, H)
            t:check(("resize %dx%d: zonas validas%s"):format(W, H, okZ and "" or (": " .. table.concat(pr, "; "))), okZ)
            local okC = s5._cardsReady
            for i, c in ipairs(s5.pack.instances) do
                local fp = s5._finalCardPositions[i]
                if math.abs(c.renderX - fp.x) > 1 or math.abs(c.renderY - fp.y) > 1
                    or math.abs(c.currentScale - zz.cardScale) > 0.01 then okC = false end
            end
            t:check(("resize %dx%d: cartas na vaga nova e na escala nova"):format(W, H), okC)
            local sb = s5.skipButton
            render(s5):release()
            t:check(("resize %dx%d: Pular no cabecalho e ativo"):format(W, H),
                inside({ x = sb.x, y = sb.y, w = sb.width, h = sb.height }, zz.header) and not sb.disabled)
        end
        s5:hide()

        local NavCursor = require("src.ui.NavCursor")
        got = nil
        local s4 = Screen:new()
        s4:show(newPack("Standard"), function(sel) got = sel end)
        s4:fastForward()
        NavCursor._reset()
        NavCursor.beginFrame()
        render(s4):release()
        NavCursor.beginFrame()
        local seen = 0
        for _, tg in ipairs(NavCursor._targets()) do
            for _, c in ipairs(s4.pack.instances) do if tg.key == c then seen = seen + 1 end end
        end
        t:eq("pad: as 3 cartas viram alvo do cursor", seen, 3)
        t:truthy("pad: Y pula o pacote", NavCursor.runAction("y"))
        pump(s4, 1.5)
        t:check("pad: Y fechou sem carta", not s4.visible and got ~= nil and #got == 0)
        NavCursor._reset()

        _G.gameSettings.reducedMotion = true
        local s3 = Screen:new()
        s3:show(newPack("Celestial"), function() end)
        local moved, burst = false, 0
        local dt = 1 / 60
        for _ = 1, 150 do
            _G.EventManager.update(dt)
            s3:update(dt)
            burst = math.max(burst, s3._burst:count())
            if (s3._packYOff or 0) ~= 0 or (s3._packRot or 0) ~= 0 then moved = true end
            for i, c in ipairs(s3.pack.instances) do
                local fp = s3._finalCardPositions[i]
                if c._packShown and (c.renderX ~= fp.x or c.renderY ~= fp.y) then moved = true end
            end
        end
        t:falsy("reducedMotion: nada se move (pacote, cartas)", moved)
        t:eq("reducedMotion: sem faisca nem pedaco", burst, 0)
        t:truthy("reducedMotion: fica pronto", s3._cardsReady)
        t:check("reducedMotion: pronto antes do normal", s3._readyAt < normalReady)
        t:truthy("reducedMotion: nome do pacote", s3.titleText ~= nil)
        t:truthy("reducedMotion: Pular ativo", s3._skipReady)
        for _, c in ipairs(s3.pack.instances) do
            t:check("reducedMotion: carta e etiqueta visiveis (" .. tostring(c.id) .. ")",
                c._packShown and c.dissolve == 0 and (c._tagPop or 0) >= 1)
        end

        local A = render(s3)
        local c3 = s3.pack.instances[2]
        s3:_setCardSelection(2, c3)
        s3:_finishTweens()
        local B = render(s3)
        local lift = c3._selLift or 0
        local s3z = s3:_z()
        local cw = c3.image:getWidth() * c3.currentScale
        local ch = c3.image:getHeight() * c3.currentScale
        local allowed = {
            { x = c3.renderX, y = c3.renderY - lift - s3:_overhang(), w = cw, h = ch + lift + s3:_overhang() },
            s3z.tags, s3z.detail, s3z.action,
        }
        local outside = 0
        local bx0, by0, bx1, by1 = W, H, 0, 0
        for y = 0, H - 1, 2 do
            for x = 0, W - 1, 2 do
                local r1, g1, b1 = A:getPixel(x, y)
                local r2, g2, b2 = B:getPixel(x, y)
                if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.02 then
                    local inAny = false
                    for _, r in ipairs(allowed) do
                        if x >= r.x - 1 and x <= r.x + r.w + 1 and y >= r.y - 1 and y <= r.y + r.h + 1 then inAny = true break end
                    end
                    if not inAny then
                        outside = outside + 1
                        bx0, by0 = math.min(bx0, x), math.min(by0, y)
                        bx1, by1 = math.max(bx1, x), math.max(by1, y)
                    end
                end
            end
        end
        A:release(); B:release()
        t:check(("destaque nao desenha fora da carta nem das zonas (%d px em %d,%d..%d,%d; carta %d,%d %dx%d)")
            :format(outside, bx0, by0, bx1, by1, c3.renderX, c3.renderY, cw, ch), outside == 0)
        s3:hide()
    end)
    _G.gameSettings.reducedMotion = prevRM
    restore()
    t:check("sem erro: " .. tostring(err), ok)
    return t:done()
end

return M
