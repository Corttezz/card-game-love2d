local Debug = require("src.core.Debug")

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiPanel     = require("src.ui.UiPanel")
local MenuKit     = require("src.ui.MenuKit")
local TextFit     = require("src.ui.TextFit")
local I18n        = require("src.i18n.I18n")
local Easing      = require("engine.Easing")
local Sfx         = require("src.systems.Sfx")
local UnlockQueue = require("src.systems.UnlockQueue")
local CardFrame   = require("src.ui.CardFrame")

local Showcase = {}
Showcase.__index = Showcase

Showcase.ownsNavigation = true

Showcase.OPEN_DELAY = 0.6
Showcase.INPUT_DELAY = 0.25

local PAD, GAP = 22, 12

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function className(id)
    return I18n.t("classes." .. tostring(id) .. ".name")
end

local function sealDef(n)
    local RM = require("src.systems.RunModifiers")
    return RM.SEALS and RM.SEALS[n]
end

function Showcase.texts(it)
    if not it then return { title = "", name = "", sub = "" } end
    if it.kind == "card" then
        return { title = I18n.t("unlock_showcase.title_card"),
                 name = I18n.cardName(it.id), sub = I18n.t("unlock_showcase.card_sub") }
    elseif it.kind == "class" then
        return { title = I18n.t("unlock_showcase.title_class"),
                 name = className(it.id), sub = I18n.t("unlock_showcase.class_sub") }
    elseif it.kind == "mastery" then
        local sub = I18n.t("unlock_showcase.mastery_sub", { class = className(it.classId) })
        local bundles = require("src.data.unlocks").CLASS_BUNDLES[it.classId or ""]
        local b = bundles and bundles[it.level or 0]
        if b and b.cards and #b.cards > 0 then
            sub = sub .. ". " .. I18n.t("unlock_showcase.mastery_cards")
        end
        return { title = I18n.t("unlock_showcase.title_mastery"),
                 name = I18n.t("unlock_showcase.mastery_level", { level = it.level or "?" }),
                 sub = sub }
    elseif it.kind == "seal" then
        local d = sealDef(it.n)
        local rule = d and I18n.t("seals." .. d.id .. ".desc") or ""
        return { title = I18n.t("unlock_showcase.title_seal", { n = it.n or "?" }),
                 name = d and I18n.t("seals." .. d.id .. ".name") or "",
                 sub = I18n.t("unlock_showcase.seal_sub", { class = className(it.classId), rule = rule }) }
    elseif it.kind == "achievement" then
        local AS = require("src.systems.AchievementSystem")
        return { title = I18n.t("unlock_showcase.title_achievement"),
                 name = AS.nameOf(it.id), sub = AS.descOf(it.id) }
    end
    Debug.warn("[UnlockShowcase] AVISO: tipo de item desconhecido: " .. tostring(it.kind))
    return { title = "", name = tostring(it.id), sub = "" }
end

function Showcase.layout(sw, sh)
    local pw = math.min(660, sw - 32)
    local ph = math.min(600, sh - 32)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local inner = pw - PAD * 2
    local L = { panel = { x = px, y = py, w = pw, h = ph } }
    local x0, y = px + PAD, py + PAD
    L.title = { x = x0, y = y, w = inner, h = 28 }; y = y + 28 + 4
    L.counter = { x = x0, y = y, w = inner, h = 12 }; y = y + 12 + GAP
    local actionsH, subH, nameH = 40, 34, 26
    local stageH = (py + ph - PAD) - y - (GAP + nameH + 4 + subH + GAP + actionsH)
    L.stage = { x = x0, y = y, w = inner, h = stageH }; y = y + stageH + GAP
    L.name = { x = x0, y = y, w = inner, h = nameH }; y = y + nameH + 4
    L.sub = { x = x0, y = y, w = inner, h = subH }; y = y + subH + GAP
    local bw = math.min(240, math.floor((inner - GAP) / 2))
    local rowW = bw * 2 + GAP
    local bx = math.floor(px + (pw - rowW) / 2)
    L.buttons = {
        { key = "continue", x = bx, y = y, w = bw, h = actionsH, primary = true },
        { key = "skip", x = bx + bw + GAP, y = y, w = bw, h = actionsH },
    }
    L.actions = { x = bx, y = y, w = rowW, h = actionsH }
    return L
end

function Showcase.validate(L, sw, sh)
    local probs = {}
    local p = L.panel
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then
        probs[#probs + 1] = ("painel fora da tela (%dx%d em %dx%d)"):format(p.w, p.h, sw, sh)
    end
    if L.stage.h < 120 then probs[#probs + 1] = "palco pequeno demais (" .. L.stage.h .. ")" end
    local zones = { { L.title, "title" }, { L.counter, "counter" }, { L.stage, "stage" },
        { L.name, "name" }, { L.sub, "sub" }, { L.buttons[1], "continue" }, { L.buttons[2], "skip" } }
    for i, a in ipairs(zones) do
        local r = a[1]
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w or r.y + r.h > p.y + p.h then
            probs[#probs + 1] = a[2] .. " fora do painel"
        end
        for j = i + 1, #zones do
            if MenuKit.overlaps(r, zones[j][1]) then
                probs[#probs + 1] = a[2] .. " sobrepoe " .. zones[j][2]
            end
        end
    end
    return probs
end

function Showcase:new()
    local self = setmetatable({ visible = false, t = 0, idx = 0, total = 0,
        focus = 1, menuTime = 0, item = nil, cardFocus = false }, Showcase)
    self.inspectModal = require("src.ui.CardInspectModal"):new()
    return self
end

function Showcase:isVisible() return self.visible end

local SOUND = {
    card = { "cardDiscovered" }, class = { "packSealBreak" }, mastery = { "actComplete" },
    seal = { "packSealBreak" }, achievement = { "comboTrigger", { pitch = 1.2 } },
}

function Showcase:_enterItem()
    self.item = UnlockQueue.peek()
    self.t = 0
    self.focus = 1
    self.pressed = nil
    self.pressedCard = nil
    self.cardFocus = false
    self.cardInst = nil
    self._cardBox = nil
    self.inspectModal.card = nil
    local s = self.item and SOUND[self.item.kind]
    if s then Sfx.play(s[1], s[2]) end
end

function Showcase:show()
    if UnlockQueue.count() == 0 then return false end
    self.visible = true
    self.total = UnlockQueue.count()
    self.idx = 1
    Sfx.play("menuOpen")
    self:_enterItem()
    return true
end

function Showcase:hide()
    if not self.visible then return end
    self.visible = false
    self.item = nil
    self.cardInst = nil
    self._cardBox = nil
    self.inspectModal.card = nil
    Sfx.play("menuClose")
end

function Showcase:resize() end

function Showcase:watch(state, dt)
    if self.visible then return end
    if state ~= "menu" then self.menuTime = 0 return end
    self.menuTime = self.menuTime + (dt or 0)
    if self.menuTime < Showcase.OPEN_DELAY or UnlockQueue.count() == 0 then return end
    if require("src.ui.InputFocus").captor() then return end
    self:show()
end

function Showcase:advance()
    UnlockQueue.pop()
    if UnlockQueue.count() == 0 then self:hide() return end
    self.idx = self.idx + 1
    self.total = math.max(self.total, self.idx + UnlockQueue.count() - 1)
    self:_enterItem()
end

function Showcase:skipAll()
    UnlockQueue.clear()
    self:hide()
end

function Showcase:_ready() return self.visible and self.t >= Showcase.INPUT_DELAY end

function Showcase:_activate(key)
    Sfx.playWithVariation("buttonClick", 1.0, 0.08)
    if key == "skip" then self:skipAll() else self:advance() end
end

function Showcase:update(dt)
    if not self.visible then return end
    self.t = self.t + (dt or 0)
    local L = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local mx, my = love.mouse.getPosition()
    self.inspectModal:update(dt or 0)
    if self.item and self.item.kind == "card" then
        local inst = self:_card()
        if inst and inst.image then
            local r = self:_cardRect(L)
            if inst.baseScale ~= r.s then
                inst.baseScale, inst.currentScale, inst.targetScale = r.s, r.s, r.s
            end
            inst.layoutX, inst.layoutY = r.x, r.y
            local hx, hy = mx, my
            if self.cardFocus then hx, hy = r.x + r.w / 2, r.y + r.h * 0.6 end
            local allowed = self.t > 0.1 and inst._showcaseLaid == true
                and not self.inspectModal:isVisible()
            inst:updateMouse(hx, hy, dt or 0, allowed)
        end
    end
    if mx ~= self._mx or my ~= self._my then
        local first = self._mx == nil
        self._mx, self._my = mx, my
        for i, b in ipairs(L.buttons) do
            if not first and MenuKit.hit(b, mx, my) and self.focus ~= i then
                self.focus = i
                Sfx.playWithVariation("menuHover", 1.0, 0.12)
            end
        end
    end
end

local function buttonAt(L, x, y)
    for i, b in ipairs(L.buttons) do
        if MenuKit.hit(b, x, y) then return i end
    end
end

function Showcase:_cardAt(x, y)
    if not (self.item and self.item.kind == "card") then return false end
    local inst = self:_card()
    if not inst then return false end
    if inst.isHovered then return true end
    local r = self._cardBox
    return r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Showcase:openInspect()
    if not self:_ready() or self.inspectModal:isVisible() then return false end
    local inst = self.item and self.item.kind == "card" and self:_card()
    if not inst then return false end
    inst:updateMouse(-1e4, -1e4, 0, false)
    self.inspectModal:show(inst, { inst }, 1)
    return true
end

function Showcase:mousepressed(x, y, button)
    if not self.visible then return false end
    if self.inspectModal:isVisible() then
        self.inspectModal:mousepressed(x, y, button)
        return true
    end
    if not self:_ready() then return true end
    if self:_cardAt(x, y) then
        if button == 2 then self:openInspect()
        elseif button == 1 then self.pressedCard = true end
        return true
    end
    if button == 1 then
        self.pressed = buttonAt(Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight()), x, y)
    end
    return true
end

function Showcase:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.inspectModal:isVisible() then
        self.inspectModal:mousereleased(x, y, button)
        return true
    end
    if button ~= 1 then return true end
    local pressedCard = self.pressedCard
    self.pressedCard = nil
    if pressedCard then
        if self:_cardAt(x, y) then self:openInspect() end
        return true
    end
    local L = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local i = self:_ready() and buttonAt(L, x, y)
    local pressed = self.pressed
    self.pressed = nil
    if i and i == pressed then self:_activate(L.buttons[i].key) end
    return true
end

function Showcase:wheelmoved() return true end

function Showcase:keypressed(key)
    if not self.visible then return false end
    if self.inspectModal:isVisible() then
        self.inspectModal:keypressed(key)
        return true
    end
    if not self:_ready() then return true end
    local hasCard = self.item and self.item.kind == "card"
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    if key == "i" then
        local inst = hasCard and self:_card()
        if inst and (self.cardFocus or inst.isHovered) then self:openInspect() end
    elseif it == "up" then
        if hasCard and not self.cardFocus then
            self.cardFocus = true
            Sfx.playWithVariation("menuHover", 1.0, 0.12)
        elseif not hasCard and self.focus ~= 1 then
            Sfx.playWithVariation("menuHover", 1.0, 0.12); self.focus = 1
        end
    elseif it == "down" then
        if self.cardFocus then
            self.cardFocus = false
            Sfx.playWithVariation("menuHover", 1.0, 0.12)
        elseif self.focus ~= 2 then
            Sfx.playWithVariation("menuHover", 1.0, 0.12); self.focus = 2
        end
    elseif it == "left" or it == "tab_prev" then
        if self.focus ~= 1 or self.cardFocus then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        self.focus, self.cardFocus = 1, false
    elseif it == "right" or it == "tab_next" then
        if self.focus ~= 2 or self.cardFocus then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        self.focus, self.cardFocus = 2, false
    elseif it == "confirm" then
        if self.cardFocus then
            self:openInspect()
        else
            self:_activate(self.focus == 2 and "skip" or "continue")
        end
    elseif it == "back" then
        self:_activate("skip")
    end
    return true
end

local cardDb = nil
function Showcase:_card()
    if self.cardInst == nil then
        self.cardInst = false
        local id = self.item and self.item.id
        local CardDatabase = require("src.systems.CardDatabase")
        cardDb = cardDb or CardDatabase:new()
        local cd = id and cardDb:getCard(id)
        if cd then
            local ok, inst = pcall(function() return cardDb:createCardInstance(cd) end)
            if ok and inst then
                self.cardInst = inst
                inst.isRewardCard = true
                inst.tooltipSide, inst.deferTooltip = true, true
                inst.navGroup = "showcase"
            else
                Debug.warn("[UnlockShowcase] AVISO: falha ao montar a carta " .. tostring(id))
            end
        else
            Debug.warn("[UnlockShowcase] AVISO: carta desconhecida na fila: " .. tostring(id))
        end
    end
    return self.cardInst or nil
end

function Showcase:_cardRect(L)
    local st = L.stage
    local Config = require("src.core.Config")
    local lift = (Config.Cards.LIFT_AMOUNT or 25) + (Config.Cards.DEPTH_OFFSET or 15)
    local s = math.min((st.h - lift) / 144, st.w / 96)
    if s >= 2 then s = math.floor(s) end
    local w, h = 96 * s, 144 * s
    local r = { x = math.floor(st.x + (st.w - w) / 2),
                y = math.floor(st.y + lift + (st.h - lift - h) / 2),
                w = w, h = h, s = s }
    self._cardBox = r
    return r
end

local function cardImage(self, id)
    local inst = self:_card()
    return inst and inst.image
end

Showcase.CELL = 2

local stageShader, stageShaderTried, whitePx
local function getStageShader()
    if stageShaderTried then return stageShader end
    stageShaderTried = true
    local ok, s = pcall(love.graphics.newShader, "shaders/reveal_stage.glsl")
    if ok then stageShader = s
    else Debug.warn("[UnlockShowcase] AVISO: shader do palco falhou: " .. tostring(s)) end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    whitePx = love.graphics.newImage(data)
    whitePx:setFilter("nearest", "nearest")
    return stageShader
end

local function rgb(c) return { c[1], c[2], c[3] } end

local function drawGlow(cx, cy, r, t, alpha)
    local sh = getStageShader()
    if not sh then return end
    local motion = not reducedMotion()
    local size = math.floor(r * 2)
    sh:send("size", { size, size })
    sh:send("cell", Showcase.CELL)
    sh:send("levels", 4)
    sh:send("rays", 12)
    sh:send("rot", motion and t * 0.22 or 0)
    sh:send("rayOn", motion and 1 or 0)
    sh:send("pulse", motion and (0.86 + 0.14 * math.sin(t * 2.4)) or 1)
    sh:send("glowCol", rgb(Palette.AGED_GOLD))
    sh:send("rayCol", rgb(Palette.AGED_GOLD_LIGHT))
    love.graphics.setShader(sh)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(whitePx, math.floor(cx - size / 2), math.floor(cy - size / 2), 0, size, size)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

local function hash(seed, i, k)
    local v = math.sin(i * 127.1 + k * 311.7 + seed * 74.7) * 43758.5453
    return v - math.floor(v)
end

local function drawSparkles(cx, cy, r, t, alpha, seed)
    if reducedMotion() then return end
    local cell = Showcase.CELL
    local function snap(v) return math.floor(v / cell) * cell end
    for i = 1, 14 do
        local ang = hash(seed, i, 1) * math.pi * 2
        local rad = r * (0.42 + 0.56 * hash(seed, i, 2))
        local phase = hash(seed, i, 3) * math.pi * 2
        local speed = 1.6 + hash(seed, i, 4) * 1.8
        local b = math.sin(t * speed + phase)
        if b > 0.45 then
            local x, y = snap(cx + math.cos(ang) * rad), snap(cy + math.sin(ang) * rad)
            Palette.set(b > 0.9 and Palette.PARCHMENT_LIGHT or Palette.AGED_GOLD_LIGHT, alpha)
            love.graphics.rectangle("fill", x, y, cell, cell)
            if b > 0.8 then
                Palette.set(Palette.AGED_GOLD_LIGHT, alpha * 0.8)
                love.graphics.rectangle("fill", x - cell, y, cell, cell)
                love.graphics.rectangle("fill", x + cell, y, cell, cell)
                love.graphics.rectangle("fill", x, y - cell, cell, cell)
                love.graphics.rectangle("fill", x, y + cell, cell, cell)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function steppedDisc(cx, cy, r)
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
    for dy = -r, r do
        local half = math.floor(math.sqrt(math.max(0, r * r - dy * dy)))
        love.graphics.rectangle("fill", cx - half, cy + dy, half * 2 + 1, 1)
    end
end

local function drawSeal(n, cx, cy, size)
    local r = size / 2
    Palette.set(Palette.INK, 0.6)
    steppedDisc(cx + 2, cy + 3, r)
    Palette.set(Palette.BLOOD_DARK)
    steppedDisc(cx, cy, r)
    Palette.set(Palette.BLOOD)
    steppedDisc(cx, cy, r * 0.82)
    Palette.set(Palette.BLOOD_DARK)
    steppedDisc(cx, cy, r * 0.68)
    Palette.set(Palette.BLOOD)
    steppedDisc(cx, cy, r * 0.60)
    local f = FontManager.getFont(math.max(8, math.floor(size * 0.36)))
    love.graphics.setFont(f)
    local s = tostring(n or "?")
    Palette.set(Palette.INK, 0.8)
    love.graphics.print(s, math.floor(cx - f:getWidth(s) / 2) + 1, math.floor(cy - f:getHeight() / 2) + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(s, math.floor(cx - f:getWidth(s) / 2), math.floor(cy - f:getHeight() / 2))
end

function Showcase:_drawItem(it, st)
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    if it.kind == "card" then
        local img = cardImage(self, it.id)
        if img then
            local s = math.min(st.h / img:getHeight(), st.w / img:getWidth())
            if s >= 1 then s = math.floor(s) end
            local w, h = img:getWidth() * s, img:getHeight() * s
            local x, y = math.floor(cx - w / 2), math.floor(cy - h / 2)
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.rectangle("fill", x + 3, y + 4, w, h)
            love.graphics.setColor(1, 1, 1, 1)
            local fx = self.cardInst and self.cardInst.visualEffect
            if fx == "holo" or fx == "glow" then
                local HoloShader = require("src.ui.HoloShader")
                HoloShader.draw(img, x, y, HoloShader.strengthFor(fx, 1), 0, s, s, 0, 0,
                    { kind = (fx == "holo") and 1 or 0, anim = 1 })
            else
                love.graphics.draw(img, x, y, 0, s, s)
            end
            return { x = x, y = y, w = w, h = h, image = img, scale = s }
        end
    elseif it.kind == "class" or it.kind == "mastery" then
        local ClassEmblem = require("src.ui.ClassEmblem")
        local id = it.id or it.classId
        local boxH = st.h * (it.kind == "class" and 0.92 or 0.72)
        if ClassEmblem.draw(id, cx, cy, boxH, { hover = 1 }) then
            return { x = cx - boxH / 2, y = cy - boxH / 2, w = boxH, h = boxH }
        end
    elseif it.kind == "seal" then
        local size = math.min(st.h, st.w) * 0.7
        drawSeal(it.n, cx, cy, size)
        return { x = cx - size / 2, y = cy - size / 2, w = size, h = size }
    elseif it.kind == "achievement" then
        local AchievementIcons = require("src.ui.AchievementIcons")
        local img = AchievementIcons.get(it.id, false)
        local size = math.min(st.h, st.w) * 0.8
        if img and size >= img:getWidth() then size = math.floor(size / img:getWidth()) * img:getWidth() end
        AchievementIcons.draw(it.id, false, cx, cy, size, 1)
        return { x = cx - size / 2, y = cy - size / 2, w = size, h = size }
    end
    return nil
end

local stageCanvas, snapCanvas, stageCW, stageCH
local function getStageCanvas(w, h)
    if not stageCanvas or stageCW ~= w or stageCH ~= h then
        stageCanvas = love.graphics.newCanvas(w, h)
        stageCanvas:setFilter("nearest", "nearest")
        snapCanvas = love.graphics.newCanvas(w, h)
        snapCanvas:setFilter("nearest", "nearest")
        stageCW, stageCH = w, h
    end
    return stageCanvas, snapCanvas
end

function Showcase:_drawStageItem(it, st, t)
    local cell = Showcase.CELL
    local cw, ch = math.floor(st.w / cell), math.floor(st.h / cell)
    if cw < 8 or ch < 8 then return end
    local cv, snap = getStageCanvas(cw, ch)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    local art = self:_drawItem(it, { x = 0, y = 0, w = cw, h = ch })
    if art then
        local DiscoveryMark = require("src.ui.DiscoveryMark")
        if art.image then
            DiscoveryMark.drawSweep(art.image, art.x, art.y, art.scale, t, 1, true)
        else
            love.graphics.setCanvas(snap)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.draw(cv, 0, 0)
            love.graphics.setCanvas(cv)
            DiscoveryMark.drawSweep(snap, 0, 0, 1, t, 1, true)
        end
    end
    love.graphics.pop()

    local motion = not reducedMotion()
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    local k = math.min(1, t / 0.45)
    local e = motion and Easing.backOut(k) or 1
    local bob = (motion and it.kind == "card") and math.floor(math.sin(t * 2) * 3 / cell) * cell or 0
    love.graphics.push()
    love.graphics.translate(cx, cy + bob)
    love.graphics.scale(math.max(0.01, e), math.max(0.01, e))
    love.graphics.translate(-cx, -cy)
    local dx, dy = math.floor(cx - cw * cell / 2), math.floor(cy - ch * cell / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, dx, dy, 0, cell, cell)
    local flash = math.max(0, 1 - t / 0.35)
    if flash > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.85 * flash)
        love.graphics.draw(cv, dx, dy, 0, cell, cell)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    return art ~= nil
end

local function drawButton(b, label, focused)
    local fill, outline, col
    if b.primary then
        fill = focused and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD
        outline, col = Palette.AGED_GOLD_LIGHT, Palette.INK
    else
        fill = focused and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.55)
            or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.25)
        outline = focused and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
        col = focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
    end
    Palette.set(Palette.INK, 0.6)
    love.graphics.rectangle("fill", b.x + 3, b.y + 3, b.w, b.h, 3, 3)
    Palette.set(fill)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3, 3)
    love.graphics.setColor(1, 1, 1, b.primary and 0.22 or 0.06)
    love.graphics.rectangle("fill", b.x + 2, b.y + 1, b.w - 4, 2)
    Palette.set(outline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1, 3, 3)
    Palette.set(col)
    local f = TextFit.fit(label, 14, b.w - 20, 8)
    TextFit.print(label, b.x + 10, b.y + math.floor((b.h - f:getHeight()) / 2),
        { size = 14, maxW = b.w - 20, align = "center", minSize = 8 })
end

function Showcase:draw()
    if not self.visible or not self.item then return end
    local it = self.item
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local L = Showcase.layout(sw, sh)
    local t = self.t
    local first = (self.idx == 1)
    MenuKit.drawVeil(first and t or MenuKit.ENTER_DUR, 0.78)
    if first then MenuKit.pushEnter(t) else love.graphics.push() end

    local p = L.panel
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local tx = Showcase.texts(it)

    Palette.set(Palette.AGED_GOLD_LIGHT)
    TextFit.print(tx.title, L.title.x, L.title.y, { size = 22, maxW = L.title.w, align = "center",
        minSize = 10, shadow = { 0, 0, 0, 0.8 } })
    Palette.set(Palette.PARCHMENT)
    TextFit.print(I18n.t("unlock_showcase.counter", { i = self.idx, n = self.total }),
        L.counter.x, L.counter.y, { size = 10, maxW = L.counter.w, align = "center", minSize = 8 })

    local st = L.stage
    local cx, cy = st.x + st.w / 2, st.y + st.h / 2
    local r = math.min(st.w, st.h) * 0.62
    local seed = (self.idx or 1) * 17 + #tostring(it.id or it.classId or "")
    drawGlow(cx, cy, r, t, math.min(1, t / 0.3))
    local inst = (it.kind == "card") and self:_card() or nil
    if inst and inst.image then
        local cr = self:_cardRect(L)
        local motion = not reducedMotion()
        local e = motion and Easing.backOut(math.min(1, t / 0.45)) or 1
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(math.max(0.01, e), math.max(0.01, e))
        love.graphics.translate(-cx, -cy)
        inst:draw(cr.x, cr.y, false, false)
        inst._showcaseLaid = true
        local shown = CardFrame.displayImage(inst) or inst.image
        require("src.ui.DiscoveryMark").drawSweep(shown, cr.x, cr.y, cr.s, t, 1, true)
        local flash = math.max(0, 1 - t / 0.35)
        if flash > 0 then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 1, 1, 0.85 * flash)
            love.graphics.draw(shown, cr.x, cr.y, 0, cr.s, cr.s)
            love.graphics.setBlendMode("alpha")
        end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        if self.cardFocus and self:_ready() then
            MenuKit.focusRing(cr.x, cr.y, cr.w, cr.h, t)
        end
    else
        self:_drawStageItem(it, st, t)
    end
    drawSparkles(cx, cy, r, t, math.min(1, math.max(0, (t - 0.2) / 0.4)), seed)

    Palette.set(Palette.PARCHMENT_LIGHT)
    TextFit.print(tx.name, L.name.x, L.name.y, { size = 18, maxW = L.name.w, align = "center",
        minSize = 9, shadow = { 0, 0, 0, 0.8 } })
    local df = FontManager.getFont(10)
    local _, lines = df:getWrap(tx.sub or "", L.sub.w)
    if #lines > 2 then df = FontManager.getFont(8); _, lines = df:getWrap(tx.sub or "", L.sub.w) end
    love.graphics.setFont(df)
    Palette.set(Palette.PARCHMENT)
    local lh = math.ceil(df:getHeight() * 1.3)
    for i = 1, math.min(2, #lines) do
        love.graphics.print(lines[i], math.floor(L.sub.x + (L.sub.w - df:getWidth(lines[i])) / 2),
            L.sub.y + (i - 1) * lh)
    end

    local labels = { I18n.t("unlock_showcase.continue"), I18n.t("unlock_showcase.skip") }
    local NavCursor = require("src.ui.NavCursor")
    for i, b in ipairs(L.buttons) do
        drawButton(b, labels[i], i == self.focus)
        NavCursor.target("showcase:" .. b.key, b.x, b.y, b.w, b.h, { key = "showcase:" .. b.key })
    end
    if self:_ready() and not self.cardFocus then
        local b = L.buttons[self.focus]
        MenuKit.focusRing(b.x, b.y, b.w, b.h, t)
    end

    if inst and not self.inspectModal:isVisible() then inst:drawDeferredTooltip() end
    love.graphics.pop()
    self.inspectModal:draw()
    love.graphics.setColor(1, 1, 1, 1)
end

require("src.ui.UiScale").adopt(Showcase)

return Showcase
