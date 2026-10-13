-- src/ui/shop/ShopScene.lua
-- O BALCÃO DO MERCADOR EM PERSPECTIVA (Loja v3b, docs/plan/shop-v3-balcao.md
-- §12, referência docs/plan/shop_reference_gpt.png): a CENA da loja.
--
-- Camadas, do fundo pra frente:
--   a PINTURA (assets/sprites/shop/counter_scene.png em cover-fit, como os
--   salões de chefe) → pulso da lanterna pintada (ShopProps.lightLevel) →
--   placa de título com os dois "?" → CARTAS nos cavaletes da borda do fundo
--   (perspectiva fixa, placa de latão sob cada uma) → OBJETOS sobre a mesa em
--   diagonal (relíquias, pacote, sino, copo de dados), ordenados pelo pé
--   (mais fundo primeiro), cada um com a placa → marcas de poeira dos
--   vendidos → PERGAMINHO de detalhe à direita (CardDetailPanel em tinta
--   sobre papel + o botão COMPRAR da tela) → vida de frente (mariposa).
--   O CONTINUAR é um Button da tela no canto inferior direito; os objetos
--   que VOAM na compra são desenhados pela tela fora do slide (drawFlies).
--
-- O que NÃO mora aqui: regra de economia. A cena recebe ofertas e avisos
-- (onPurchased/onDenied/reroll/select) e só ANIMA. Geometria: ShopLayout
-- (arte→tela), validada por test_shop_layout. Vida ambiente: ShopProps
-- (loja-vida), chamado pelo contrato opcional — a lanterna pintada dispensa
-- o sprite, então só flameAnchor/lightLevel/drawDiceCup/drawFront/update.

local ShopScene = {}
ShopScene.__index = ShopScene

local ShopLayout   = require("src.ui.shop.ShopLayout")
local ShelfItem    = require("src.ui.shop.ShelfItem")
local Palette      = require("src.ui.Palette")
local FontManager  = require("src.ui.FontManager")
local ImageCache   = require("src.ui.ImageCache")
local I18n         = require("src.i18n.I18n")
local Moveable     = require("engine.Moveable")
local EventManager = require("engine.EventManager")
local Sfx          = require("src.systems.Sfx")

local FLYQ    = "shop_fly"
local REROLLQ = "shop_reroll"

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local quads = {}
local function quad(key, x, y, w, h, sw, sh)
    local q = quads[key]
    if not q then
        q = love.graphics.newQuad(x, y, w, h, sw, sh)
        quads[key] = q
    else
        q:setViewport(x, y, w, h)
    end
    return q
end

local artWarned = {}
local function art(name)
    local img = ImageCache.tryGet("assets/sprites/shop/" .. name .. ".png")
    if not img and not artWarned[name] then
        artWarned[name] = true
        print("[ShopScene] assets/sprites/shop/" .. name .. ".png ausente — desenho procedural")
    end
    return img
end

local propsChecked, props = false, nil
local function getProps()
    if propsChecked then return props end
    propsChecked = true
    local ok, mod = pcall(require, "src.ui.shop.ShopProps")
    if ok and type(mod) == "table" then
        props = mod
        if props.load then
            local okL, err = pcall(props.load)
            if not okL then print("[ShopScene] ShopProps.load falhou: " .. tostring(err)) end
        end
    else
        print("[ShopScene] src/ui/shop/ShopProps.lua ausente — copo de dados em placeholder")
    end
    return props
end
ShopScene._getProps = getProps

local sfxWarned = {}
local function playFirst(codes, opts)
    for _, c in ipairs(codes) do
        if Sfx.has(c) then Sfx.play(c, opts) return c end
    end
    if _G.audioSystem then
        local key = table.concat(codes, "/")
        if not sfxWarned[key] then
            sfxWarned[key] = true
            print("[ShopScene] nenhum sfx registrado em: " .. key)
        end
    end
end

-- ============================================================================
function ShopScene.new(screen)
    local self = setmetatable({}, ShopScene)
    self.screen = screen
    self.items = {}
    self.bySlot = {}
    self.outgoing = nil
    self.t = 0
    self.bell = { ringing = 0, hover = 0, hot = false }
    self.dice = { hover = 0, hot = false }
    self.flies = {}
    self.hovered = nil
    return self
end

function ShopScene:layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local cfg = self.screen.modeConfig or { cards = 4, upgrades = 3, boosters = 1 }
    self.L = ShopLayout.layout(sw, sh, cfg.cards or 4, cfg.upgrades or 3)
    self:_applyGeometry()
    return self.L
end

function ShopScene:geomFor(item)
    local L = self.L
    if not L then return nil end
    if item.kind == "card" then return L.cards[item.index] end
    if item.kind == "relic" then return L.relics[item.index] end
    if item.kind == "pack" then return item.index == 1 and L.pack or nil end
end

function ShopScene:_applyGeometry()
    for _, list in ipairs({ self.items, self.outgoing or {} }) do
        for _, it in ipairs(list) do
            local g = self:geomFor(it)
            if g then it:setGeometry(g) else it.rect = nil end
        end
    end
end

function ShopScene:setOffers(offers)
    local fx = {}
    for _, it in ipairs(self.items) do fx[it.slot] = it:exportFx() end
    self.items, self.bySlot = {}, {}
    local counts = { card = 0, relic = 0, pack = 0 }
    for _, o in ipairs(offers or {}) do
        local kind = (o.type == "card" and "card") or (o.type == "upgrade" and "relic")
            or (o.type == "booster_pack" and "pack") or nil
        if kind then
            local it = ShelfItem.new(kind, o, o._slot or (#self.items + 1))
            counts[kind] = counts[kind] + 1
            it.index = counts[kind]
            it:importFx(fx[it.slot])
            if kind == "card" and not o.purchased and self.screen._makeCardInstance then
                it:setCard(self.screen:_makeCardInstance(o))
            end
            self.items[#self.items + 1] = it
            self.bySlot[it.slot] = it
        end
    end
    if self.L then self:_applyGeometry() end
    self:_syncSelection()
end

function ShopScene:_syncSelection()
    local sel = self.screen.selectedOffer
    for _, it in ipairs(self.items) do it.selected = (sel ~= nil and it.offer == sel) end
end

function ShopScene:cardInstances()
    local out = {}
    for _, it in ipairs(self.items) do
        if it.card and not it.sold then out[#out + 1] = it.card end
    end
    return out
end

function ShopScene:slotPositions()
    local out = {}
    for _, it in ipairs(self.items) do
        local r = it.rect
        if r then
            out[it.slot] = { x = r.x, y = r.y, w = r.w, h = r.h,
                row = (it.kind == "card") and 1 or 2, kind = (it.kind == "relic") and "voucher" or it.kind }
        end
    end
    return out
end

function ShopScene:clear()
    EventManager.clear(FLYQ)
    EventManager.clear(REROLLQ)
    self.items, self.bySlot, self.outgoing = {}, {}, nil
    self.flies = {}
    self.hovered = nil
end

-- ============================================================================
-- UPDATE
-- ============================================================================
function ShopScene:_mouseLocal()
    local mx, my = love.mouse.getPosition()
    return mx, my - (self.screen.slideOffsetY or 0)
end

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ShopScene:update(dt)
    if not self.L then self:layout() end
    self.t = self.t + dt
    local L = self.L
    local mx, my = self:_mouseLocal()
    local blocked = self.screen._closing or self.outgoing ~= nil
        or math.abs(self.screen.slideOffsetY or 0) > 1

    local hovered = nil
    if not blocked then
        -- objetos da frente primeiro (quem está na frente ganha o mouse)
        for k = #self.items, 1, -1 do
            local it = self.items[k]
            if it.rect and it:hit(mx, my) then hovered = it break end
        end
    end
    self.hovered = hovered
    self:_syncSelection()

    for _, it in ipairs(self.items) do
        local entered = it:update(dt, it == hovered)
        if entered then
            local codes = (it.kind == "pack") and { "hoverPack", "hoverCard" }
                or (it.kind == "relic") and { "hoverRelic", "hoverCard" } or { "hoverCard" }
            playFirst(codes, { pitch = 0.95 + (math.random() * 2 - 1) * 0.18 })
        end
    end
    for _, it in ipairs(self.outgoing or {}) do it:update(dt, false) end

    -- sino e copo
    local function hoverOf(obj, r, on)
        if on and not obj.hot then
            obj.hot = true
            if not reducedMotion() then Moveable.juice_up(obj, 0.06, 0.02) end
        elseif not on then obj.hot = false end
        if reducedMotion() then obj.hover = on and 1 or 0
        else obj.hover = obj.hover + ((on and 1 or 0) - obj.hover) * math.min(1, dt * 12) end
        Moveable.updateJuice(obj, dt)
    end
    Moveable.initJuice(self.bell); Moveable.initJuice(self.dice)
    local overBell = not blocked and (inRect(L.bell.rect, mx, my) or inRect(L.bell.plate, mx, my))
    local overDice = not blocked and (inRect(L.dice.rect, mx, my) or inRect(L.dice.plate, mx, my))
    hoverOf(self.bell, L.bell, overBell)
    hoverOf(self.dice, L.dice, overDice)
    self.hoverCounter = (overBell and "bell") or (overDice and "dice") or nil
    if self.bell.ringing > 0 then self.bell.ringing = math.max(0, self.bell.ringing - dt) end

    for i = #self.flies, 1, -1 do
        if self.flies[i]._done then table.remove(self.flies, i) end
    end

    local P = getProps()
    if P and P.update then
        local run = self.screen._run and self.screen:_run() or nil
        local hx, hy
        if hovered and hovered.rect then hx, hy = hovered:center() end
        local ok, err = pcall(P.update, dt, L, { t = self.t, reduced = reducedMotion(), hoverX = hx, hoverY = hy,
            run = run, cupHover = self.dice.hover })
        if not ok then print("[ShopScene] ShopProps.update: " .. tostring(err)) end
    end
end

-- ============================================================================
-- EVENTOS (chamados pela tela)
-- ============================================================================
function ShopScene:_flyTarget(offer, kind)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local tb = _G.topBar
    if kind == "card" then
        local cd = self.screen.cardDatabase and self.screen.cardDatabase:getCard(offer.id)
        if cd and cd.type == "joker" then return math.floor(sw * 0.10), 26, 0.18 end
        if tb and tb._layout then
            local ok, Lt = pcall(tb._layout, tb)
            if ok and Lt and Lt.deck then return Lt.deck.x + 24, 26, 0.12 end
        end
        return 205, 6, 0.12
    elseif kind == "relic" then
        return 60, sh - 70, 0.4
    end
    return sw / 2, sh / 2, 0.3
end

function ShopScene:onPurchased(offer)
    local it = offer and self.bySlot[offer._slot]
    if not it then return end
    -- o pacote não voa: ele ABRE (PackOpenScreen) no lugar
    local payload = (it.kind ~= "pack") and it:flyPayload() or nil
    it:markSold()
    playFirst({ "coinTotalThud", "purchaseConfirm" })
    playFirst({ "sceneWoodKnock" }, { pitch = 1.1, volume = 0.5 })
    if payload and not reducedMotion() then
        local tx, ty, ts = self:_flyTarget(offer, it.kind)
        payload.alpha, payload.rot = 1, 0
        self.flies[#self.flies + 1] = payload
        local dur = 0.45
        EventManager.parallelEase(payload, "x", tx, dur, "ease_in", FLYQ)
        EventManager.parallelEase(payload, "y", ty, dur, "ease_in", FLYQ)
        EventManager.parallelEase(payload, "scale", ts, dur, "ease_in", FLYQ)
        EventManager.parallelEase(payload, "rot", 0.3, dur, "smooth", FLYQ)
        EventManager.parallel(dur, function()
            payload._done = true
            Sfx.play("cardDraw", { pitch = 1.15, volume = 0.7 })
        end, FLYQ)
    end
end

-- Sem ouro: a placa treme (preço vermelho), o ouro da TopBar pisca. Sem toast.
function ShopScene:onDenied(offer)
    local it = offer and self.bySlot[offer._slot]
    if it then it:denyPurchase() end
    local tb = _G.topBar
    if tb and tb.flashGold then tb:flashGold(-1) end
end

-- Sino: os objetos antigos deslizam pra fora da mesa (esquerda) e os novos
-- entram deslizando pela direita, um a um. Dados já trocaram.
function ShopScene:reroll(newOffers)
    self.bell.ringing = 0.9
    EventManager.clear(REROLLQ)
    if reducedMotion() or not self.L then
        self.outgoing = nil
        self:setOffers(newOffers)
        for _, it in ipairs(self.items) do it.slide.x = 0; it.entry.v = 1 end
        return
    end
    self.outgoing = self.items
    self.items, self.bySlot = {}, {}
    self:setOffers(newOffers)
    local off = self.L.limitX + 80
    for _, it in ipairs(self.outgoing) do
        local sl = it.slide
        EventManager.parallelEase(sl, "x", -(self.L.limitX + 120), 0.34, "ease_in", REROLLQ)
    end
    for i, it in ipairs(self.items) do
        it.slide.x = off
        it.entry.v = 1
        local sl, entry = it.slide, it.entry
        EventManager.parallel(0.36 + (i - 1) * 0.06, function()
            EventManager.parallelEase(sl, "x", 0, 0.34, "ease_out", REROLLQ)
            Moveable.juice_up(it, 0.08, 0.02)
            playFirst({ "cardShelfPlace", "cardDraw" }, { pitch = 0.94 + (i - 1) * 0.04 })
            entry.v = 1
        end, REROLLQ)
    end
    EventManager.parallel(0.36, function() self.outgoing = nil end, REROLLQ)
end

-- Entrada da loja: os objetos deslizam pra mesa um a um.
function ShopScene:enter()
    if reducedMotion() or not self.L then
        for _, it in ipairs(self.items) do it.entry.v = 1; it.slide.x = 0 end
        return
    end
    local off = self.L.limitX + 80
    for i, it in ipairs(self.items) do
        it.slide.x = off
        local sl = it.slide
        EventManager.parallel(0.25 + (i - 1) * 0.06, function()
            EventManager.parallelEase(sl, "x", 0, 0.34, "ease_out", REROLLQ)
            Moveable.juice_up(it, 0.08, 0.02)
            playFirst({ "cardShelfPlace", "cardDraw" }, { pitch = 0.94 + (i - 1) * 0.04 })
        end, REROLLQ)
    end
end

function ShopScene:isBusy()
    return self.outgoing ~= nil
end

function ShopScene:itemAt(mx, my)
    if self.outgoing or self.screen._closing then return nil end
    for k = #self.items, 1, -1 do
        local it = self.items[k]
        if not it.sold and it.rect and it:hit(mx, my) then return it end
    end
    return nil
end

-- ============================================================================
-- DRAW
-- ============================================================================
function ShopScene:_drawPainting()
    local L = self.L
    local img = art("counter_scene")
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if img then
        local cv = L.cover
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, cv.ox, cv.oy, 0, cv.s, cv.s)
    else
        Palette.set(Palette.darken(Palette.INK, 0.6))
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    -- pulso da lanterna pintada (nível em degraus do ShopProps)
    local P = getProps()
    local level = 1
    if P and P.lightLevel then
        local ok, v = pcall(P.lightLevel)
        if ok and type(v) == "number" then level = v end
    end
    local f = L.lantern.flame
    local warm = Palette.AGED_GOLD
    for i = 3, 1, -1 do
        love.graphics.setColor(warm[1], warm[2] * 0.85, warm[3] * 0.5, 0.05 * (level - 0.6))
        love.graphics.circle("fill", f.x, f.y, L.lantern.w * (0.6 + i * 0.5) * level)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_drawSign()
    local L = self.L
    local s = L.sign
    -- tábua escura atrás do título (lê sobre qualquer trecho da pintura)
    Palette.set(Palette.INK, 0.72)
    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
    Palette.set(Palette.AGED_GOLD_DARK, 0.9)
    love.graphics.rectangle("fill", s.x, s.y + s.h - 1, s.w, 1)
    love.graphics.rectangle("fill", s.x, s.y, s.w, 1)
    local font = FontManager.getFont(math.max(13, math.floor(love.graphics.getHeight() / 80)))
    love.graphics.setFont(font)
    local title = I18n.t("reward.shop_title")
    local tw = font:getWidth(title)
    local tx = s.x + 14
    local ty = math.floor(s.y + (s.h - font:getHeight()) / 2)
    FontManager.drawWithOutline(title, tx, ty, Palette.AGED_GOLD_LIGHT, 0.9)
    local midY = ty + math.floor(font:getHeight() / 2)
    local HelpBadge = require("src.ui.HelpBadge")
    local r = 9
    local cx = math.min(tx + tw + 22, L.diceHelp.x - r - 8)
    local h = { x = cx - r - 3, y = midY - r - 3, w = r * 2 + 6, h = r * 2 + 6 }
    L.help = h
    local mx, my = self:_mouseLocal()
    local hot = inRect(h, mx, my)
    HelpBadge.draw(cx, midY, r, hot)
    require("src.ui.NavCursor").target("rules", h.x, h.y, h.w, h.h)
    if hot then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my + (self.screen.slideOffsetY or 0))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_itemCtx(it)
    local afford = true
    local eco = self.screen.game and self.screen.game.economySystem
    if eco and it.offer and (it.offer.cost or 0) > 0 then afford = eco:canAfford(it.offer.cost) end
    return { t = self.t, afford = afford, alpha = 1, reduced = reducedMotion() }
end

function ShopScene:_drawCards(list)
    local NavCursor = require("src.ui.NavCursor")
    for _, it in ipairs(list) do
        if it.rect and it.kind == "card" then
            if not it.sold then it:drawStand(false, 1) end
            it:drawDust({ alpha = 1 })
            local ctx = self:_itemCtx(it)
            it:drawObject(ctx)
            if not it.sold then
                it:drawStand(true, 1)
                local r = it.rect
                NavCursor.target(it.card or ("offer:" .. it.slot), r.x + (it.slide.x or 0), r.y, r.w, r.h)
            end
            it:drawPlateFor(ctx)
        end
    end
end

function ShopScene:_drawTable(list)
    local NavCursor = require("src.ui.NavCursor")
    local L = self.L
    -- tudo que está sobre a mesa, ordenado pelo pé (fundo → frente)
    local order = {}
    for _, it in ipairs(list) do
        if it.rect and it.kind ~= "card" then order[#order + 1] = { foot = it.foot, item = it } end
    end
    order[#order + 1] = { foot = L.bell.foot, bell = true }
    -- o copo está SEMPRE na mesa (o clique é que depende de _G.openScribeDice)
    order[#order + 1] = { foot = L.dice.foot, dice = true }
    table.sort(order, function(a, b) return a.foot < b.foot end)
    for _, e in ipairs(order) do
        if e.item then
            local it = e.item
            it:drawDust({ alpha = 1 })
            local ctx = self:_itemCtx(it)
            it:drawObject(ctx)
            it:drawPlateFor(ctx)
            if not it.sold then
                local r = it.rect
                NavCursor.target("offer:" .. it.slot, r.x + (it.slide.x or 0), r.y, r.w, r.h)
            end
        elseif e.bell then
            self:_drawBell()
        elseif e.dice then
            self:_drawDice()
        end
    end
end

function ShopScene:_drawBell()
    local L, sc = self.L, self.screen
    local B = L.bell
    local eco = sc.game and sc.game.economySystem
    local cost = sc.shopSystem and sc.shopSystem.getRefreshCost and sc.shopSystem:getRefreshCost() or 0
    local canRing = (not eco) or eco:canAfford(cost)
    local bell = ShelfItem.art("assets/sprites/shop/objects/bell.png", true) or art("bell")
    local frame = 1
    if self.bell.ringing > 0 and not reducedMotion() then
        local seq = { 2, 3, 2, 4, 3, 2, 1 }
        frame = seq[math.min(#seq, 1 + math.floor((0.9 - self.bell.ringing) * 12))] or 1
    end
    local lift = reducedMotion() and 0 or (self.bell.hover * 4 - Moveable.hopOffset(self.bell))
    local s = Moveable.scaleFactor(self.bell)
    local r = B.rect
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse("fill", B.footX, B.foot - 1, r.w * 0.35, math.max(2, r.h * 0.07))
    if bell then
        local frames = (bell:getWidth() >= bell:getHeight() * 3) and 4 or 1
        local fw, fh = bell:getWidth() / frames, bell:getHeight()
        local k = (r.w / fw) * s
        if canRing then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.55, 0.5, 0.45, 0.9) end
        local q = quad("bell", (math.min(frame, frames) - 1) * fw, 0, fw, fh, bell:getWidth(), bell:getHeight())
        love.graphics.draw(bell, q, B.footX - fw * k / 2, B.foot - fh * k - lift, 0, k, k)
    else
        Palette.set(canRing and Palette.AGED_GOLD or Palette.STEEL)
        love.graphics.ellipse("fill", B.footX, B.foot - r.h * 0.45 - lift, r.w * 0.4, r.h * 0.35)
    end
    ShelfItem.drawPlate(B.plate, {
        { I18n.t("shop.bell_plate"), Palette.INK },
        { "$" .. tostring(cost), canRing and Palette.INK or Palette.BLOOD },
    })
end

function ShopScene:_drawDice()
    local L, sc = self.L, self.screen
    local D = L.dice
    local P = getProps()
    local drawn = false
    local run = sc._run and sc:_run() or nil
    local ScribeDice = require("src.systems.ScribeDice")
    local st = ScribeDice.state(run)
    if P and P.drawDiceCup then
        local ok, err = pcall(P.drawDiceCup, D.rect, { hover = self.dice.hover, used = ScribeDice.isUsed(run),
            total = st and st.total or nil, run = run, t = self.t, reduced = reducedMotion() })
        if ok then drawn = true else print("[ShopScene] ShopProps.drawDiceCup: " .. tostring(err)) end
    end
    if not drawn then
        local dr = D.rect
        local cup = Palette.lerp(Palette.RUST, Palette.INK, 0.35)
        Palette.set(Palette.INK)
        love.graphics.rectangle("fill", dr.x + dr.w * 0.2 - 1, dr.y + dr.h * 0.25 - 1, dr.w * 0.6 + 2, dr.h * 0.75 + 2)
        Palette.set(cup)
        love.graphics.rectangle("fill", dr.x + dr.w * 0.2, dr.y + dr.h * 0.25, dr.w * 0.6, dr.h * 0.75)
    end
    ShelfItem.drawPlate(D.plate, {
        { I18n.t("shop.dice_plate"), Palette.INK },
        { (st and st.used and st.total) and tostring(st.total) or "", Palette.INK },
    })
end

-- Pergaminho de inspeção: prego + rolo (9-slice) + papel liso + CardDetailPanel.
function ShopScene:_drawScroll()
    local L = self.L
    local S = L.scroll
    local nail = art("nail")
    local n = S.nail
    local frame = art("scroll_frame")
    if frame then
        local fw, fh = frame:getWidth(), frame:getHeight()
        local rollerA = math.floor(fh * 0.17)
        local footA = math.floor(fh * 0.21)
        local edge = math.floor(fw * 0.12)
        local kx = S.w / fw
        local kyTop = S.rollerH / rollerA
        local kyBot = S.footH / footA
        love.graphics.setColor(1, 1, 1, 1)
        local function q(x, y, w, h) return quad("scroll_" .. x .. "_" .. y, x, y, w, h, fw, fh) end
        love.graphics.draw(frame, q(0, 0, fw, rollerA), S.x, S.y, 0, kx, kyTop)
        local paperA = fh - rollerA - footA
        local bodyTop = S.y + S.rollerH
        local midH = S.h - S.rollerH - S.footH
        local ky = midH / paperA
        love.graphics.draw(frame, q(0, rollerA, edge, paperA), S.x, bodyTop, 0, kx, ky)
        love.graphics.draw(frame, q(fw - edge, rollerA, edge, paperA), S.x + S.w - edge * kx, bodyTop, 0, kx, ky)
        love.graphics.draw(frame, q(edge, rollerA, fw - edge * 2, paperA), S.x + edge * kx, bodyTop, 0, kx, ky)
        love.graphics.draw(frame, q(0, fh - footA, fw, footA), S.x, S.y + S.h - S.footH, 0, kx, kyBot)
    else
        Palette.set(Palette.INK)
        love.graphics.rectangle("fill", S.x - 1, S.y - 1, S.w + 2, S.h + 2)
        Palette.set(Palette.PARCHMENT)
        love.graphics.rectangle("fill", S.x, S.y, S.w, S.h)
    end
    if nail then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(nail, n.x, n.y, 0, n.w / nail:getWidth(), n.h / nail:getHeight())
    end
    -- papel quase liso sob o texto e o botão (grão da arte <= 6%)
    local paper = Palette.lerp(Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, 0.28)
    local B = S.body
    love.graphics.setColor(paper[1], paper[2], paper[3], 0.90)
    love.graphics.rectangle("fill", B.x - 6, B.y - 4, B.w + 12, (S.buy.y + S.buy.h) - B.y + 10)
    love.graphics.setColor(1, 1, 1, 1)
    if self.screen._drawDetailPanel then
        self.screen:_drawDetailPanel(S.body, true, S.artMaxH)
    end
end

function ShopScene:draw()
    if not self.L then self:layout() end
    local L = self.L
    local P = getProps()
    local ctx = { t = self.t, reduced = reducedMotion() }

    self:_drawPainting()
    self:_drawSign()
    self:_drawCards(self.outgoing or self.items)
    if self.outgoing then
        -- objetos saindo e entrando ao mesmo tempo (deslize do sino)
        self:_drawTable(self.outgoing)
        self:_drawTable(self.items)
    else
        self:_drawTable(self.items)
    end
    self:_drawScroll()
    if P and P.drawFront then
        local ok, err = pcall(P.drawFront, L, ctx)
        if not ok then print("[ShopScene] ShopProps.drawFront: " .. tostring(err)) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:drawFlies()
    for _, f in ipairs(self.flies) do
        love.graphics.setColor(1, 1, 1, f.alpha or 1)
        love.graphics.draw(f.img, f.x, f.y, f.rot or 0, f.scale, f.scale, f.ox or 0, f.oy or 0)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ShopScene
