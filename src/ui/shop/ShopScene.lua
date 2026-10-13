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
local ShopPerspective = require("src.ui.shop.ShopPerspective")
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
        local entered = it:update(dt, it == hovered, mx, my)
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
    local f = L.lantern and L.lantern.flame
    if f then
        local warm = Palette.AGED_GOLD
        for i = 3, 1, -1 do
            love.graphics.setColor(warm[1], warm[2] * 0.85, warm[3] * 0.5, 0.05 * (level - 0.6))
            love.graphics.circle("fill", f.x, f.y, L.lantern.w * (0.6 + i * 0.5) * level)
        end
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

-- caixa (arte) da união das caixas de tela dadas, com folga
local function artBoxOf(L, rects, pad)
    local cv = L.cover
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, r in ipairs(rects) do
        x0 = math.min(x0, r.x); y0 = math.min(y0, r.y)
        x1 = math.max(x1, r.x + r.w); y1 = math.max(y1, r.y + r.h)
    end
    if x0 == math.huge then return nil end
    pad = pad or 6
    return { x = (x0 - cv.ox) / cv.s - pad, y = (y0 - cv.oy) / cv.s - pad,
             w = (x1 - x0) / cv.s + pad * 2, h = (y1 - y0) / cv.s + pad * 2 }
end

-- Cartas nos cavaletes: carta (homografia, tela) → trilho, batentes, sombra
-- de contato, plaquinha e etiqueta (arte, na grade da cena) → texto das
-- placas (UI, cisalhado na mesma inclinação).
function ShopScene:_drawCards(list)
    local NavCursor = require("src.ui.NavCursor")
    local L = self.L
    local cards, rects = {}, {}
    for _, it in ipairs(list) do
        if it.rect and it.kind == "card" then
            cards[#cards + 1] = it
            local sx = it.slide.x or 0
            local r = it.rect
            rects[#rects + 1] = { x = r.x + sx - 12, y = r.y - 16, w = r.w + 30, h = r.h + 30 }
            local g = it.geom
            if g and g.plate then rects[#rects + 1] = { x = g.plate.x + sx - 8, y = g.plate.y, w = g.plate.w + 24, h = g.plate.h + 4 } end
        end
    end
    if #cards == 0 then return end
    local box = artBoxOf(L, rects, 4)
    for k = #cards, 1, -1 do
        local it = cards[k]
        it:drawCard(self:_itemCtx(it))
        if not it.sold then
            local r = it.rect
            NavCursor.target(it.card or ("offer:" .. it.slot), r.x + (it.slide.x or 0), r.y, r.w, r.h)
        end
    end
    ShopPerspective.artPass(L, box, function()
        for _, it in ipairs(cards) do
            if it.sold then it:drawDustArt(L)
            else
                it:drawStandArt(L, "front", it:entered())
                it:drawPlateArt(L, self:_itemCtx(it))
            end
        end
    end)
    for _, it in ipairs(cards) do
        it:drawPlateText(L, self:_itemCtx(it))
        it:drawSoldText({ alpha = 1 })
    end
end

-- Contato de um objeto simples (copo, dados): faixa dither colada na base.
local function contactBand(L, fx, fy, halfW, slope, alpha)
    local prof = { x0 = 0, x1 = math.max(1, math.floor(halfW * 2)) - 1, y0 = 0, y1 = 0, bottom = {} }
    for x = prof.x0, prof.x1 do prof.bottom[x] = 0 end
    ShopPerspective.drawContactShadow({ prof = prof, fx = fx, fy = fy, s = 1, k = slope, flip = false },
        L.art.tableMask, alpha)
end

-- Tudo que está sobre a mesa, numa passada só na resolução da ARTE,
-- ordenado pelo pé (fundo → frente); depois, na grade da UI, as etiquetas,
-- o VENDIDO a giz e o nome do objeto em hover (por cima de tudo).
function ShopScene:_drawTable(list)
    local NavCursor = require("src.ui.NavCursor")
    local L = self.L
    local order, rects = {}, {}
    for _, it in ipairs(list) do
        if it.rect and it.kind ~= "card" then
            order[#order + 1] = { foot = it.foot, item = it }
            local r = it.rect
            rects[#rects + 1] = { x = r.x + (it.slide.x or 0) - 16, y = r.y - 24, w = r.w + 60, h = r.h + 36 }
            if it.geom and it.geom.plaque then
                local b = it.geom.plaque.box
                rects[#rects + 1] = { x = b.x + (it.slide.x or 0) - 8, y = b.y - 8, w = b.w + 16, h = b.h + 12 }
            end
        end
    end
    order[#order + 1] = { foot = L.bell.foot, bell = true }
    order[#order + 1] = { foot = L.dice.foot, dice = true }
    for _, o in ipairs({ L.bell, L.dice }) do
        local r = o.rect
        rects[#rects + 1] = { x = r.x - 16, y = r.y - 24, w = r.w + 90, h = r.h + 36 }
        if o.plaque then rects[#rects + 1] = { x = o.plaque.box.x - 8, y = o.plaque.box.y - 8, w = o.plaque.box.w + 16, h = o.plaque.box.h + 12 } end
    end
    table.sort(order, function(a, b) return a.foot < b.foot end)
    local box = artBoxOf(L, rects, 4)
    ShopPerspective.artPass(L, box, function()
        for _, e in ipairs(order) do
            if e.item then
                local it = e.item
                it:drawDustArt(L)
                it:drawObjectArt(L, self:_itemCtx(it))
                it:drawPlateArt(L, self:_itemCtx(it))
            elseif e.bell then
                self:_drawBellArt()
                self:_drawBellPlaqueArt()
            elseif e.dice then
                self:_drawDiceArt()
            end
        end
    end)
    for _, e in ipairs(order) do
        if e.item then
            local it = e.item
            it:drawPlateText(L, self:_itemCtx(it))
            it:drawSoldText({ alpha = 1 })
            if not it.sold then
                local r = it.rect
                NavCursor.target("offer:" .. it.slot, r.x + (it.slide.x or 0), r.y, r.w, r.h)
            end
        elseif e.bell then
            self:_drawBellPlaqueText()
        end
    end
    for _, e in ipairs(order) do
        if e.item then e.item:drawHoverLabel(L, { alpha = 1 }) end
    end
    self:_drawCounterLabels()
end

function ShopScene:_bellCost()
    local sc = self.screen
    local eco = sc.game and sc.game.economySystem
    local cost = sc.shopSystem and sc.shopSystem.getRefreshCost and sc.shopSystem:getRefreshCost() or 0
    return cost, (not eco) or eco:canAfford(cost)
end

-- Sino: a arte de sempre (objects/bell.png), em pé na diagonal, contato na
-- base; sem ouro, apagado. Hover = mesmo sprite + contorno (v5: sem
-- levantar). Escala 1 da grade (v5: era 0,755 do sprite: pixel fracionário
-- ao lado de objetos em escala 1; um sino de balcão ~ 40% da altura da
-- carta, que é o que o sprite dá em escala 1).
function ShopScene:_drawBellArt()
    local L = self.L
    local B = L.bell
    local cv = L.cover
    local _, canRing = self:_bellCost()
    local img, src = ShopPerspective.spriteFor("bell")
    if not img then return end
    local prof = ShopPerspective.profile(src, img)
    if not prof then return end
    local pz = ShopPerspective.poseFor("bell")
    local lift = reducedMotion() and 0 or (self.bell.hover * ShopLayout.LIFT - Moveable.hopOffset(self.bell))
    local o = {
        img = img, prof = prof,
        fx = (B.footX - cv.ox) / cv.s, fy = (B.foot - cv.oy) / cv.s,
        s = 1,
        k = B.slope * (pz.shear or 1), flip = pz.flip, lift = lift / cv.s,
        outline = self.bell.hover,
        color = canRing and { 1, 1, 1 } or { 0.55, 0.5, 0.45 },
    }
    ShopPerspective.drawContactShadow(o, L.art.tableMask, 1)
    ShopPerspective.drawUpright(o)
end

-- plaquinha do sino (o mesmo latão das ofertas), na grade da arte
function ShopScene:_bellPlaque()
    local B = self.L.bell
    if not B.plaque then return nil end
    local cost, canRing = self:_bellCost()
    return ShelfItem.plaqueArt(B.plaque, "$" .. tostring(cost), nil, self.L.cover), canRing
end

function ShopScene:_drawBellPlaqueArt()
    local Q = self:_bellPlaque()
    if Q then ShelfItem.drawPlaqueArt(Q, 0, { alpha = 1 }) end
end

function ShopScene:_drawBellPlaqueText()
    local Q, canRing = self:_bellPlaque()
    if Q then ShelfItem.drawPlaqueText(self.L, Q, 0, ShelfItem.priceInk(canRing, false), 1, 0) end
end

-- Copo de dados (ShopProps) na resolução da arte, com contato na base e os
-- dados jogados ao longo da diagonal.
function ShopScene:_drawDiceArt()
    local L, sc = self.L, self.screen
    local D = L.dice
    local cv = L.cover
    local P = getProps()
    local run = sc._run and sc:_run() or nil
    local ScribeDice = require("src.systems.ScribeDice")
    local st = ScribeDice.state(run)
    local fx, fy = (D.footX - cv.ox) / cv.s, (D.foot - cv.oy) / cv.s
    local lift = reducedMotion() and 0 or (self.dice.hover * ShopLayout.LIFT) / cv.s
    local hArt = D.rect.h / cv.s
    -- +1: a última linha do frame do copo é vazia (base real na linha 30 de 32)
    local artRect = { x = fx - hArt / 2, y = fy + 1 - hArt - lift, w = hArt, h = hArt }
    -- o copo (frame 32 px, corpo de 22) encosta na mesa pela base inteira
    local lying = st and st.used and st.dice
    contactBand(L, fx, fy, lying and 15 or 11, D.slope, 1)
    -- dados À FRENTE do copo (ShopLayout.TABLE.dice.diceAt): jogados, os
    -- dois; parado, um de enfeite (o copo sozinho lia como caneca sem preço)
    local at = ShopLayout.TABLE.dice.diceAt
    for i = 1, (lying and 2 or 1) do
        local p = at[i]
        contactBand(L, fx + p[1], fy + p[2] + D.slope * p[1], 8, D.slope, 1)
    end
    local drawn = false
    if P and P.drawDiceCup then
        local ok, err = pcall(P.drawDiceCup, artRect, { hover = self.dice.hover, used = ScribeDice.isUsed(run),
            total = st and st.total or nil, run = run, t = self.t, reduced = reducedMotion(),
            slope = D.slope, outline = self.dice.hover * 0.8, silhouette = ShopPerspective.silhouette(),
            dicePos = ShopLayout.TABLE.dice.diceAt, idleDie = 5 })
        if ok then drawn = true else print("[ShopScene] ShopProps.drawDiceCup: " .. tostring(err)) end
    end
    if not drawn then
        local cup = Palette.lerp(Palette.RUST, Palette.INK, 0.35)
        Palette.set(cup)
        love.graphics.rectangle("fill", math.floor(fx - 5), math.floor(fy - 12 - lift), 10, 12)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Nome do sino / copo SÓ no hover (faixa de pergaminho na diagonal).
function ShopScene:_drawCounterLabels()
    local L = self.L
    local lift = ShopLayout.LIFT
    if self.bell.hover > 0.05 then
        ShelfItem.drawHoverName(I18n.t("shop.bell_plate"), L.bell.footX, L.bell.rect.y - lift * self.bell.hover,
            L.bell.slope, math.min(1, self.bell.hover * 1.4), L.limitX, 8)
    end
    if self.dice.hover > 0.05 then
        ShelfItem.drawHoverName(I18n.t("shop.dice_plate"), L.dice.footX, L.dice.rect.y,
            L.dice.slope, math.min(1, self.dice.hover * 1.4), L.limitX, 8)
    end
end

-- ============================================================================
-- PERGAMINHO (Loja v3c, queixa do dono: "o papel parece fora dos rolos; não
-- está coeso com o ambiente"). UM rolo só, pixel art procedural no TAMANHO
-- DE PIXEL DA PINTURA (cover-fit arredondado):
--   * o papel começa ENROLADO no rolo de cima e termina enrolado no de baixo:
--     os rolos são cilindros do MESMO papel, com a mesma largura; só as
--     pontas do bastão de madeira (com a ponteira) saem pros lados;
--   * cordão do prego da parede até as duas pontas do bastão de cima;
--   * papel na luz da cena: bordas mais escuras em degraus (dither), a
--     lanterna (à esquerda, no alto) aquece o canto de cima-esquerda, o canto
--     de baixo-direita cai na sombra; grão fixo;
--   * COMPRAR é uma FITA vermelha com selo de cera, no rodapé DO papel.
-- Cache por tamanho (o papel é estático: 1 draw por quadro).
-- ============================================================================
local scrollCache = { key = nil, canvas = nil }

local function scrollPx(L)
    return math.max(1, math.floor(L.cover.s + 0.5))
end

-- geometria do rolo em CÉLULAS (px de arte)
function ShopScene.scrollCells(S, px)
    local W, H = math.floor(S.w / px), math.floor(S.h / px)
    local knob = math.max(4, math.floor(W * 0.06))
    local roll = math.max(6, math.floor(S.rollerH / px))
    return { W = W, H = H, knob = knob, roll = roll,
             x0 = knob, x1 = W - knob - 1,          -- papel (inclusive)
             top = roll, bot = H - roll - 1 }       -- papel plano (inclusive)
end

local function hash01(x, y)
    local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return n - math.floor(n)
end

local function buildScroll(S, px)
    local C = ShopScene.scrollCells(S, px)
    local ok, canvas = pcall(love.graphics.newCanvas, C.W, C.H)
    if not ok then return nil, C end
    canvas:setFilter("nearest", "nearest")
    local P = Palette
    local warm = { 1.0, 0.94, 0.82 }                      -- luz âmbar da cena
    local function tint(c, k)
        return { c[1] * warm[1] * k, c[2] * warm[2] * k, c[3] * warm[3] * k }
    end
    local paperL, paperM, paperD = P.PARCHMENT_LIGHT, P.PARCHMENT, P.PARCHMENT_DARK
    local woodHi, woodMid, woodDark, woodDeep = ShelfItem.WOOD.lite, ShelfItem.WOOD.mid,
        ShelfItem.WOOD.dark, ShelfItem.WOOD.deep
    local brass, brassD = P.AGED_GOLD, P.AGED_GOLD_DARK
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 0)
    local function cell(c, x, y, w, h, a)
        love.graphics.setColor(c[1], c[2], c[3], a or 1)
        love.graphics.rectangle("fill", x, y, w or 1, h or 1)
    end
    local dith = ShopPerspective.dithered
    -- ===== papel plano =====
    local lx, ly = C.x0 - C.W * 0.3, C.top - C.H * 0.15     -- lanterna (fora, à esquerda no alto)
    local R = math.sqrt(C.W * C.W + C.H * C.H)
    for y = C.top, C.bot do
        for x = C.x0, C.x1 do
            local d = math.min(x - C.x0, C.x1 - x)          -- distância da borda lateral
            local dy = math.min(y - C.top, C.bot - y)
            -- luz: degraus da distância até a lanterna
            local l = 1 - math.sqrt((x - lx) ^ 2 + (y - ly) ^ 2) / R
            local base = tint(paperL, 0.96)
            if l > 0.62 then base = tint(paperL, 1.0)
            elseif l > 0.56 and dith(x, y, (l - 0.56) / 0.06) then base = tint(paperL, 1.0) end
            -- bordas mais escuras em degraus (papel velho); o lado direito,
            -- longe da lanterna, um degrau a mais
            local far = (x - C.x0) / math.max(1, C.x1 - C.x0)
            if d == 0 then base = tint(paperD, 0.6)
            elseif d == 1 then base = tint(paperD, 0.82)
            elseif d == 2 then base = tint(paperM, 0.86)
            elseif d <= 4 and dith(x, y, far > 0.5 and 0.6 or 0.35) then base = tint(paperM, 0.9) end
            if dy == 0 then base = tint(paperD, 0.55) end
            -- grão fixo
            local g = hash01(x, y)
            if g > 0.94 then base = { base[1] * 0.93, base[2] * 0.93, base[3] * 0.93 } end
            cell(base, x, y)
        end
    end
    -- sombra do rolo de cima no papel (o papel SAI de dentro dele)
    for x = C.x0, C.x1 do
        cell(tint(paperD, 0.6), x, C.top, 1, 1, 0.9)
        if dith(x, C.top + 1, 0.5) then cell(tint(paperD, 0.75), x, C.top + 1, 1, 1, 0.8) end
        cell(tint(paperD, 0.62), x, C.bot, 1, 1, 0.9)
    end
    -- ===== rolos (cilindro do MESMO papel, mesma largura) + bastão =====
    local function roller(y0)
        local h = C.roll
        local rodT = math.max(3, math.floor(h * 0.45))
        local rodY = y0 + math.floor((h - rodT) / 2)
        -- bastão: ponta esquerda e direita (fora do papel) com ponteira de latão
        for _, side in ipairs({ { 0, C.x0 - 1 }, { C.x1 + 1, C.W - 1 } }) do
            local a0, a1 = side[1], side[2]
            for x = a0, a1 do
                local tip = (x == 0 or x == C.W - 1)
                cell(woodDeep, x, rodY - 1, 1, rodT + 2)
                if not tip then
                    cell(woodHi, x, rodY, 1, 1)
                    cell(woodMid, x, rodY + 1, 1, math.max(1, rodT - 2))
                    cell(woodDark, x, rodY + rodT - 1, 1, 1)
                end
            end
            -- ponteira (bola de latão um pouco mais alta que o bastão)
            local bw = math.max(2, C.knob - 1)
            local bx = (a0 == 0) and 0 or (C.W - bw)
            cell(woodDeep, bx, rodY - 2, bw, rodT + 4)
            cell(brass, bx, rodY - 1, bw, rodT + 2)
            cell(brassD, bx, rodY + rodT, bw, 1)
            cell(P.AGED_GOLD_LIGHT, bx + (a0 == 0 and 0 or bw - 1), rodY - 1, 1, 2)
        end
        -- cilindro de papel: degraus de luz por linha (claro no meio)
        for i = 0, h - 1 do
            local t = (i + 0.5) / h
            local k
            local c
            if t < 0.12 or t > 0.9 then c = tint(paperD, 0.45)
            elseif t < 0.26 then c = tint(paperD, 0.75)
            elseif t < 0.4 then c = tint(paperM, 0.92)
            elseif t < 0.55 then c = tint(paperL, 1.0)
            elseif t < 0.72 then c = tint(paperM, 0.85)
            else c = tint(paperD, 0.62) end
            cell(c, C.x0, y0 + i, C.x1 - C.x0 + 1, 1)
            cell(tint(paperD, 0.55), C.x0, y0 + i, 1, 1)
            cell(tint(paperD, 0.55), C.x1, y0 + i, 1, 1)
        end
        -- volta do papel: a borda enrolada (espiral) nas pontas
        for i = 1, h - 2 do
            if i % 2 == 0 then
                cell(tint(paperD, 0.7), C.x0 + 1, y0 + i, 1, 1)
                cell(tint(paperD, 0.7), C.x1 - 1, y0 + i, 1, 1)
            end
        end
        -- contorno
        cell(woodDeep, C.x0, y0 - 1, C.x1 - C.x0 + 1, 1, 0.9)
        cell(woodDeep, C.x0, y0 + h, C.x1 - C.x0 + 1, 1, 0.6)
    end
    roller(0)
    roller(C.H - C.roll)
    love.graphics.pop()
    return canvas, C
end

function ShopScene:_drawScroll()
    local L = self.L
    local S = L.scroll
    local px = scrollPx(L)
    local key = S.w .. "x" .. S.h .. "@" .. px .. ":" .. S.rollerH
    if scrollCache.key ~= key then
        scrollCache.key = key
        scrollCache.canvas, scrollCache.cells = buildScroll(S, px)
    end
    local C = scrollCache.cells or ShopScene.scrollCells(S, px)
    local ox = S.x + math.floor((S.w - C.W * px) / 2)
    local oy = S.y
    -- cordão do prego até as duas pontas do bastão de cima
    local n = S.nail
    local nx, ny = n.x + n.w / 2, n.y + n.h - 2
    local rodY = oy + (math.floor((C.roll - math.max(2, math.floor(C.roll * 0.4))) / 2)) * px
    for _, ex in ipairs({ ox + px, ox + (C.W - 1) * px }) do
        Palette.set(Palette.INK, 0.8)
        love.graphics.setLineWidth(math.max(2, px))
        love.graphics.setLineStyle("rough")
        love.graphics.line(nx, ny, ex, rodY)
        Palette.set(Palette.PARCHMENT_DARK, 0.9)
        love.graphics.setLineWidth(math.max(1, px - 1))
        love.graphics.line(nx, ny, ex, rodY)
    end
    love.graphics.setLineWidth(1)
    -- sombra do rolo na parede (deslocada pra direita-baixo: luz à esquerda)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", ox + (C.x0 + 2) * px, oy + 3 * px, (C.x1 - C.x0 + 1) * px, (C.H - 2) * px)
    if scrollCache.canvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(scrollCache.canvas, ox, oy, 0, px, px)
    else
        Palette.set(Palette.PARCHMENT)
        love.graphics.rectangle("fill", S.x, S.y, S.w, S.h)
    end
    local nail = art("nail")
    if nail then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(nail, n.x, n.y, 0, n.w / nail:getWidth(), n.h / nail:getHeight())
    end
    if self.screen._drawDetailPanel then
        self.screen:_drawDetailPanel(S.body, true, S.artMaxH, ShopScene.portrait)
    end
    self:_drawBuyRibbon()
end

-- COMPRAR = fita vermelha atravessada no rodapé do papel, com selo de cera à
-- esquerda (o Button da tela vira hitbox invisível: clique, teclado e pad
-- continuam nele). Sem ouro: fita desbotada e selo apagado.
function ShopScene:_drawBuyRibbon()
    local L = self.L
    local S = L.scroll
    local b = self.screen.buyButton
    local r = S.buy
    local px = scrollPx(L)
    local disabled = b and b.disabled
    local hot = b and b.hover and not disabled
    local lift = (hot and not reducedMotion()) and px or 0
    local x, y, w, h = r.x, r.y - lift, r.w, r.h
    local red = disabled and Palette.lerp(Palette.BLOOD_DARK, Palette.PARCHMENT_DARK, 0.45) or Palette.BLOOD
    local redD = disabled and Palette.lerp(Palette.BLOOD_DARK, Palette.INK, 0.4) or Palette.BLOOD_DARK
    local redL = hot and Palette.lighten(Palette.BLOOD, 0.25) or Palette.lerp(Palette.BLOOD, Palette.PARCHMENT_LIGHT, 0.18)
    local notch = 2 * px
    -- sombra no papel
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", x + px, y + 2 * px, w, h)
    -- fita: corpo + rabos em V nas pontas (degraus de pixel)
    local rows = math.floor(h / px)
    for i = 0, rows - 1 do
        local yy = y + i * px
        local t = i / math.max(1, rows - 1)
        local cut = math.floor((1 - math.abs(t - 0.5) * 2) * notch / px + 0.5) * px  -- V no meio
        local c = (i == 0) and redL or ((i >= rows - 1) and redD or red)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", x + cut, yy, w - cut * 2, px)
    end
    Palette.set(Palette.INK, 0.7)
    love.graphics.rectangle("fill", x + notch, y - px, w - notch * 2, px)
    love.graphics.rectangle("fill", x + notch, y + rows * px, w - notch * 2, px)
    -- selo de cera à esquerda, sobre a fita
    local sr = math.floor(h * 0.55)
    local scx, scy = x + notch + sr, y + h / 2
    local wax = disabled and Palette.lerp(Palette.BLOOD_DARK, Palette.INK, 0.5) or Palette.lerp(Palette.BLOOD, Palette.ORANGE, 0.12)
    local step = px
    for yy = -sr, sr, step do
        for xx = -sr, sr, step do
            local d = math.sqrt(xx * xx + yy * yy)
            -- borda irregular da cera (pingos)
            local edge = sr - ((math.floor((xx + yy) / step) % 3 == 0) and step or 0)
            if d <= edge then
                local c = wax
                if d > edge - step * 1.1 then c = Palette.BLOOD_DARK
                elseif d > sr * 0.62 and d < sr * 0.62 + step * 1.2 then
                    c = (xx + yy < 0) and Palette.lerp(wax, Palette.PARCHMENT_LIGHT, 0.35) or Palette.BLOOD_DARK
                elseif d < sr * 0.3 then c = Palette.BLOOD_DARK
                elseif xx + yy < -sr * 0.7 then c = Palette.lerp(wax, Palette.PARCHMENT_LIGHT, 0.3) end
                love.graphics.setColor(c[1], c[2], c[3], 1)
                love.graphics.rectangle("fill", math.floor(scx + xx), math.floor(scy + yy), step, step)
            end
        end
    end
    -- texto gravado na fita
    local txt = (b and b.text) or I18n.t("reward.detail_buy", nil, "COMPRAR")
    local tx0 = scx + sr + 2 * px
    local tw = x + w - notch - tx0 - 2 * px
    local font, fitted = require("src.ui.TextFit").fit(txt, math.max(10, math.floor(h * 0.42)), tw, 8)
    love.graphics.setFont(font)
    local tx = math.floor(tx0 + (tw - font:getWidth(fitted)) / 2)
    local ty = math.floor(y + (h - font:getHeight()) / 2) + 1
    Palette.set(Palette.INK, 0.8)
    love.graphics.print(fitted, tx + 1, ty + 1)
    Palette.set(disabled and Palette.PARCHMENT or Palette.PARCHMENT_LIGHT, disabled and 0.7 or 1)
    love.graphics.print(fitted, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Retrato do objeto no pergaminho: o MESMO sprite (e o mesmo espelho) da
-- mesa. A queixa "na bancada está de um jeito e, quando passo o mouse, fica
-- de outro" era o pergaminho desenhando a arte com pedestal e halo do
-- UpgradeTile ao lado do objeto novo da mesa.
function ShopScene.portrait(payload, x, y, w, h, alpha)
    local offer = payload and payload.offer
    if not offer then return false end
    local kind = (payload.kind == "pack") and "pack" or "relic"
    return ShelfItem.drawPortrait(kind, offer, x, y, w, h, alpha)
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
        love.graphics.draw(f.img, f.x, f.y, f.rot or 0, f.flip and -f.scale or f.scale, f.scale, f.ox or 0, f.oy or 0)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ShopScene
