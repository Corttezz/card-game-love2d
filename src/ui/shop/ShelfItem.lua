local Debug = require("src.core.Debug")

local ShelfItem = {}
ShelfItem.__index = ShelfItem

local Palette         = require("src.ui.Palette")
local FontManager     = require("src.ui.FontManager")
local TextFit         = require("src.ui.TextFit")
local ImageCache      = require("src.ui.ImageCache")
local Moveable        = require("engine.Moveable")
local UpgradeTile     = require("src.ui.UpgradeTile")
local I18n            = require("src.i18n.I18n")
local ShopLayout      = require("src.ui.shop.ShopLayout")
local ShopPerspective = require("src.ui.shop.ShopPerspective")

local floor = math.floor
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local DENY_TIME = 0.45

ShelfItem.HOVER_TIME = 0.18
function ShelfItem.ease(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local WOOD = {
    hi   = { 246 / 255, 196 / 255, 112 / 255 },
    lite = { 180 / 255, 110 / 255, 52 / 255 },
    mid  = { 112 / 255, 60 / 255, 33 / 255 },
    dark = { 60 / 255, 29 / 255, 21 / 255 },
    deep = { 18 / 255, 8 / 255, 10 / 255 },
}
ShelfItem.WOOD = WOOD
ShelfItem.OBJECT_SCALE = 1

local ART = {}
local artWarned = {}
local function art(path, quiet)
    if ART[path] ~= nil then return ART[path] or nil end
    local img = ImageCache.tryGet(path)
    if not img then
        ART[path] = false
        if not quiet and not artWarned[path] then
            artWarned[path] = true
            Debug.warn("[ShelfItem] " .. path .. " ausente")
        end
        return nil
    end
    if img.setFilter and img:getFilter() ~= "nearest" then img:setFilter("nearest", "nearest") end
    ART[path] = img
    return img
end
ShelfItem.art = art

function ShelfItem.new(kind, offer, slot)
    local self = setmetatable({}, ShelfItem)
    self.kind = kind
    self.offer = offer
    self.slot = slot
    self.hover = 0
    self.hoverT = 0
    self.hot = false
    self.selected = false
    self.entry = { v = 1 }
    self.slide = { x = 0 }
    self.sold = offer and offer.purchased or false
    self.deny = 0
    self.tag = { angle = 0, vel = 0 }
    self.tilt = { x = 0, y = 0, ox = 0, oy = 0 }
    Moveable.initJuice(self)
    return self
end

function ShelfItem:exportFx()
    return { hover = self.hover, hoverT = self.hoverT, hot = self.hot, juice = self.juice, entry = self.entry,
             slide = self.slide, deny = self.deny, dustSeed = self.dustSeed, tilt = self.tilt, tag = self.tag }
end

function ShelfItem:importFx(fx)
    if not fx then return end
    self.hover, self.hot, self.juice = fx.hover, fx.hot, fx.juice
    self.hoverT = fx.hoverT or fx.hover or 0
    self.entry = fx.entry or self.entry
    self.slide = fx.slide or self.slide
    self.deny = fx.deny or 0
    self.dustSeed = fx.dustSeed
    self.tilt = fx.tilt or self.tilt
    self.tag = fx.tag or self.tag
end

function ShelfItem:setGeometry(g)
    self.geom = g
    self.rect = g.rect
    self.foot = g.foot
    if self.card then self:_placeCard() end
end

function ShelfItem:_placeCard()
    local inst, r = self.card, self.rect
    if not (inst and inst.image) then return end
    local iw, ih = inst.image:getWidth(), inst.image:getHeight()
    local s = math.min(r.w / iw, r.h / ih)
    inst.baseScale, inst.currentScale, inst.targetScale = s, s, s
    inst.homeX = math.floor(r.x + (r.w - iw * s) / 2)
    inst.homeY = math.floor(self.foot - ih * s)
    inst.x, inst.y = inst.homeX, inst.homeY
    inst.layoutX, inst.layoutY = inst.homeX, inst.homeY
    inst.noHoverLift = true
    inst.isRewardCard = false
    inst.shopOffer = self.offer
end

function ShelfItem:setCard(inst)
    self.card = inst
    if inst then
        inst.shopOffer = self.offer
        self.offer.cardInstance = inst
        if self.rect then self:_placeCard() end
    end
end

function ShelfItem:entered() return clamp(self.entry.v or 1, 0, 1) end

function ShelfItem:cardCorners()
    local g = self.geom
    local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, reducedMotion() and 0 or self.hover, self:liftPx())
    local sx = (self.slide.x or 0) + (self.tilt and self.tilt.ox or 0)
    local sy = self.tilt and self.tilt.oy or 0
    return x0 + sx, y0 + sy, x1 + sx, y1 + sy, x2 + sx, y2 + sy, x3 + sx, y3 + sy
end

function ShelfItem:hit(mx, my)
    local r, p = self.rect, self.geom and self.geom.plate
    if not r or self.sold then return false end
    local x = mx - (self.slide.x or 0)
    if self.kind == "card" and self.geom.qw then
        local g = self.geom
        local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, 0, 0)
        local poly = { x0, y0 - (g.lift or 0) - 2, x1, y1 - (g.lift or 0) - 2, x2, y2 + 2, x3, y3 + 2 }
        if ShopLayout.pointInPoly(x, my, poly) then return true end
    elseif x >= r.x and x <= r.x + r.w and my >= r.y - (self.geom.lift or 0) and my <= r.y + r.h then
        return true
    end
    if p and x >= p.x and x <= p.x + p.w and my >= p.y and my <= p.y + p.h then return true end
    return false
end

function ShelfItem:center()
    local r = self.rect
    return r.x + r.w / 2 + (self.slide.x or 0), r.y + r.h / 2
end

ShelfItem.TILT_EASE = 12
ShelfItem.TILT_PARALLAX = 0
function ShelfItem:cardMouseUV(mx, my)
    local g = self.geom
    if not (g and g.frame and mx) then return nil end
    local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, 0, 0)
    local sx = self.slide.x or 0
    local r0, r1, r2 = ShopPerspective.homography(x0 + sx, y0, x1 + sx, y1, x2 + sx, y2, x3 + sx, y3)
    return ShopPerspective.unmapH(r0, r1, r2, mx, my)
end

function ShelfItem.warpUV(u, v, mx, my, hover, t, quad)
    local cx, cy = u - 0.5, v - 0.5
    local press = -(cx * mx + cy * my) * hover * 0.12
    local wob = math.sin(t * 2 + cx * 4) * 0.005 * hover + math.cos(t * 1.7 + cy * 4) * 0.005 * hover
    local k = press + wob
    if quad then k = k * (1 - v) end
    return u + cx * k, v + cy * k
end

function ShelfItem:updateTilt(dt, hovered, mx, my)
    local T = self.tilt
    local tx, ty, ox, oy = 0, 0, 0, 0
    if hovered and not reducedMotion() then
        local u, v = self:cardMouseUV(mx, my)
        if u then
            local Card = require("src.cards.base.Card")
            local ht = Card.hoverTilt(u, v)
            tx, ty = ht.uvX, ht.uvY
            ox, oy = ht.offsetX * ShelfItem.TILT_PARALLAX, ht.offsetY * ShelfItem.TILT_PARALLAX
        end
    end
    if reducedMotion() then T.x, T.y, T.ox, T.oy = 0, 0, 0, 0 return end
    local k = 1 - math.exp(-ShelfItem.TILT_EASE * dt)
    T.x = T.x + (tx - T.x) * k
    T.y = T.y + (ty - T.y) * k
    T.ox = T.ox + (ox - T.ox) * k
    T.oy = T.oy + (oy - T.oy) * k
end

ShelfItem.FLOAT_IDS = { health_upgrade = true, mana_upgrade = true }
ShelfItem.FLOAT_LIFT = 12
function ShelfItem:floats()
    if self.kind == "pack" then return true end
    return self.kind == "relic" and self.offer and ShelfItem.FLOAT_IDS[self.offer.id] or false
end

ShelfItem.HOVER_SFX = {
    health_upgrade = "shopPotionBubble", mana_upgrade = "shopCrystalHum",
    duplicate_card = "shopPressClunk", remove_card = "shopScissorsSnip",
    forge_card = "shopAnvilRing", interest_cap = "shopChestCoins",
    card_draw_upgrade = "shopBookFlip", joker_slot = "shopRelicTake",
}
ShelfItem.BUY_SFX = {
    health_upgrade = "shopPotionDrink", mana_upgrade = "shopCrystalShatter",
    duplicate_card = "shopPressClunk", remove_card = "shopScissorsSnip",
    forge_card = "shopAnvilRing", interest_cap = "shopChestCoins",
    card_draw_upgrade = "shopBookFlip", joker_slot = "shopRelicTake",
}
function ShelfItem:hoverSfx()
    if self.kind == "pack" then return { "shopPackLift", "hoverPack", "hoverCard" } end
    if self.kind == "relic" then
        local id = self.offer and self.offer.id
        return { ShelfItem.HOVER_SFX[id] or "hoverRelic", "hoverRelic", "hoverCard" }
    end
    return { "hoverCard" }
end
function ShelfItem:buySfx()
    if self.kind == "pack" then return { "shopPackOpenTear", "packSealBreak" } end
    if self.kind == "relic" then
        local id = self.offer and self.offer.id
        return { ShelfItem.BUY_SFX[id] or "shopRelicTake", "coinTotalThud", "purchaseConfirm" }
    end
    return { "coinTotalThud", "purchaseConfirm" }
end

function ShelfItem:update(dt, hovered, mx, my)
    local reduced = reducedMotion()
    local target = (hovered and not self.sold) and 1 or 0
    local entered = false
    if target == 1 and not self.hot then
        self.hot = true
        entered = true
        if not reduced then self.tag.vel = self.tag.vel + 2.4 end
    elseif target == 0 then
        self.hot = false
    end
    if hovered and mx and not reduced then
        local g = self.geom
        local tb = g and (g.tag and g.tag.box or (g.newTag and g.newTag.box))
        if tb and self._lastMx and mx >= tb.x and mx <= tb.x + tb.w and my and my >= tb.y and my <= tb.y + tb.h then
            self.tag.vel = self.tag.vel + (mx - self._lastMx) * 0.05
        end
    end
    self._lastMx = mx
    ShelfItem.stepPendulum(self.tag, dt)
    if reduced then self.hoverT = target
    else
        local step = dt / ShelfItem.HOVER_TIME
        if target > self.hoverT then self.hoverT = math.min(target, self.hoverT + step)
        else self.hoverT = math.max(target, self.hoverT - step) end
    end
    self.hover = ShelfItem.ease(self.hoverT)
    Moveable.updateJuice(self, dt)
    if self.kind == "card" then self:updateTilt(dt, target == 1, mx, my) end
    if self.deny > 0 then self.deny = math.max(0, self.deny - dt) end
    return entered
end

function ShelfItem:liftPx()
    if reducedMotion() then return 0 end
    local maxLift = (self.geom and self.geom.lift) or 0
    local lift = self.hover * maxLift
    if self:floats() and self.hover > 0 then
        local t = love.timer and love.timer.getTime() or 0
        lift = lift + self.hover * (ShelfItem.FLOAT_LIFT + 2 * math.sin(t * 2.6 + (self.slot or 0)))
    end
    return lift - Moveable.hopOffset(self)
end

function ShelfItem:denyPurchase() self.deny = DENY_TIME end

function ShelfItem:markSold()
    self.sold = true
    if self.offer then self.offer.purchased = true end
    self.dustSeed = self.dustSeed or (self.slot * 17 + 3)
end

function ShelfItem:pose()
    if self.kind == "card" then
        return { src = "card:" .. tostring(self.offer and self.offer.id), flip = false,
                 slope = self.geom and self.geom.slope or 0 }
    end
    local pz = ShopPerspective.poseFor(self.kind, self.offer)
    local _, src = ShopPerspective.spriteFor(self.kind, self.offer, false, 0)
    local slope = (self.geom and self.geom.slope or 0) * (pz.shear or 1)
    return { src = src, flip = pz.flip and true or false, slope = slope, size = pz.size or 1 }
end

function ShelfItem:uprightParams(L, animate, t)
    local pose = self:pose()
    local img, src = ShopPerspective.spriteFor(self.kind, self.offer, animate, t)
    if not img then return nil end
    local prof = ShopPerspective.profile(src, img)
    if not prof then return nil end
    local cv = L.cover
    local g = self.geom
    local fx = (g.footX + (self.slide.x or 0) - cv.ox) / cv.s
    local fy = (g.foot - cv.oy) / cv.s
    local sizeArt = (g.size or g.rect.w) / cv.s * (pose.size or 1) * ShelfItem.OBJECT_SCALE
    local cw, ch = prof.x1 - prof.x0 + 1, prof.y1 - prof.y0 + 1
    local m = math.max(cw, ch, 1)
    local s = (m <= sizeArt * 1.35) and 1 or 1 / math.ceil(m / sizeArt)
    return { img = img, prof = prof, fx = fx, fy = fy, s = s, k = pose.slope, flip = pose.flip,
             lift = self:liftPx() / cv.s }
end

function ShelfItem:flyPayload()
    local r = self.rect
    if self.kind == "card" and self.card and self.card.image then
        local inst = self.card
        local x0, y0 = self:cardCorners()
        local img = inst.image
        local s = self.geom.qh / img:getHeight()
        return { img = img, x = x0, y = y0, scale = s, ox = 0, oy = 0 }
    end
    local img = ShopPerspective.spriteFor(self.kind, self.offer, false, 0)
    if not img then return nil end
    local sw, sh = img:getWidth(), img:getHeight()
    local s = r.w / math.max(sw, sh)
    local pose = self:pose()
    return { img = img, x = self.geom.footX + (self.slide.x or 0), y = self.foot - sh * s / 2,
             scale = s, ox = sw / 2, oy = sh / 2, flip = pose.flip }
end

local function withShear(x, y, slope, fn)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.shear(0, slope)
    fn()
    love.graphics.pop()
end
ShelfItem.withShear = withShear

function ShelfItem.drawBand(b, text, color, opts)
    opts = opts or {}
    local a = opts.alpha or 1
    local shake = opts.shakeX or 0
    local paper = opts.paper
    withShear(floor(b.x + shake), floor(b.y), b.slope or 0, function()
        local w, h = b.w, b.h
        Palette.set(Palette.INK, 0.45 * a)
        love.graphics.rectangle("fill", 1, 2, w, h)
        Palette.set(Palette.INK, a)
        love.graphics.rectangle("fill", -1, -1, w + 2, h + 2)
        local top = paper and Palette.PARCHMENT_LIGHT or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)
        local bot = paper and Palette.PARCHMENT or Palette.INK
        local half = floor(h / 2)
        love.graphics.setColor(top[1], top[2], top[3], a)
        love.graphics.rectangle("fill", 0, 0, w, half)
        love.graphics.setColor(bot[1], bot[2], bot[3], a)
        love.graphics.rectangle("fill", 0, half, w, h - half)
        Palette.set(paper and Palette.PARCHMENT_DARK or Palette.INK, 0.9 * a)
        love.graphics.rectangle("fill", 0, h - 1, w, 1)
        if paper then
            Palette.set(Palette.PARCHMENT_DARK, a)
            love.graphics.rectangle("fill", 0, 0, 1, h)
            love.graphics.rectangle("fill", w - 1, 0, 1, h)
        end
        if text and text ~= "" then
            local font, fitted = TextFit.fit(text, clamp(h - 6, 7, 11), w - 6, 7)
            love.graphics.setFont(font)
            local tx = floor((w - font:getWidth(fitted)) / 2)
            local ty = floor((h - font:getHeight()) / 2) + 1
            if not paper then
                Palette.set(Palette.INK, 0.9 * a)
                love.graphics.print(fitted, tx, ty + 1)
            end
            local c = color or Palette.INK
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.print(fitted, tx, ty)
        end
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

local function px(c, a, x, y, w, h)
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.rectangle("fill", x, y, w or 1, h or 1)
end
ShelfItem.px = px
local lineY = ShopLayout.lineY

ShelfItem.BRASS = {
    hi   = Palette.AGED_GOLD_LIGHT,
    rim  = Palette.AGED_GOLD_DARK,
    dark = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.35),
    face = Palette.lerp(Palette.AGED_GOLD, Palette.AGED_GOLD_DARK, 0.2),
}
ShelfItem.BRASS_DENY = {
    hi   = Palette.AGED_GOLD_DARK,
    rim  = Palette.INK,
    dark = Palette.INK,
    face = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.5),
}
function ShelfItem.plaqueFace(afford)
    return (afford == false) and ShelfItem.BRASS_DENY.face or ShelfItem.BRASS.face
end

local function lum(c)
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
function ShelfItem.contrast(a, b)
    local la, lb = lum(a), lum(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

local inkCache = {}
function ShelfItem.inkOnBrass(key, c, face, lighten)
    if inkCache[key] then return inkCache[key] end
    face = face or ShelfItem.BRASS.face
    for _ = 1, 40 do
        if ShelfItem.contrast(c, face) >= 4.6 then break end
        c = lighten and Palette.lighten(c, 0.08) or Palette.darken(c, 0.9)
    end
    inkCache[key] = c
    return c
end

function ShelfItem.priceInk(afford, sale)
    if not afford then
        return ShelfItem.inkOnBrass("deny", Palette.lighten(Palette.BLOOD, 0.35), ShelfItem.BRASS_DENY.face, true)
    end
    return ShelfItem.inkOnBrass("price", Palette.INK)
end

function ShelfItem.showsGem(rar)
    return rar ~= nil and rar ~= "common" and rar ~= "basic"
end

function ShelfItem.plaqueArt(pq, text, rar, cv)
    local P = ShopLayout.PLAQUE
    local gem = ShelfItem.showsGem(rar) and (P.gem + 1) or 0
    local maxText = math.max(4, (pq.w - P.padX * 2 - gem)) * cv.s
    local font, fitted = TextFit.fit(text, P.font, maxText, P.fontMin)
    local w = math.min(pq.w, math.ceil(font:getWidth(fitted) / cv.s) + P.padX * 2 + gem)
    local x0 = math.floor(pq.cx - w / 2 + 0.5)
    return { x0 = x0, w = w, y0 = pq.y0, h = pq.h, font = font, text = fitted, gem = gem,
             kind = pq.kind }
end

function ShelfItem.plaqueBox(pq, text, rar, cv)
    local Q = ShelfItem.plaqueArt(pq, text, rar, cv)
    local b = ShopLayout.stepBox(cv, Q.x0, Q.w, Q.y0, Q.h)
    b.font, b.text, b.art = Q.font, Q.text, Q
    return b
end

function ShelfItem.drawPlaqueArt(Q, dx, st)
    dx = dx or 0
    local B = (st.afford == false) and ShelfItem.BRASS_DENY or ShelfItem.BRASS
    local a = st.alpha or 1
    local x0, x1 = Q.x0 + dx, Q.x0 + dx + Q.w - 1
    local rim = st.selected and Palette.AGED_GOLD_LIGHT or Palette.INK
    local object = (Q.kind == "object")
    for x = x0, x1 do
        local top = lineY(Q.y0, x - dx)
        if object then
            px(Palette.INK, 0.55 * a, x + 1, top + Q.h, 1, 1)
            if ShopPerspective.dithered(x, top + Q.h + 1, 0.4) then
                px(Palette.INK, 0.35 * a, x + 1, top + Q.h + 1, 1, 1)
            end
            px(B.rim, a, x, top - 1, 1, 1)
        else
            px(Palette.INK, 0.45 * a, x + 1, top + Q.h, 1, 1)
        end
        if x == x0 or x == x1 then
            px(rim, a, x, top, 1, Q.h)
        else
            px(rim, a, x, top, 1, 1)
            px(B.hi, a, x, top + 1, 1, 1)
            px(B.face, a, x, top + 2, 1, Q.h - 4)
            px(B.dark, a, x, top + Q.h - 2, 1, 1)
            px(rim, a, x, top + Q.h - 1, 1, 1)
        end
    end
    if not object then
        for _, x in ipairs({ x0 + 1, x1 - 1 }) do
            px(B.hi, a, x, lineY(Q.y0, x - dx) + math.floor(Q.h / 2), 1, 1)
        end
    end
    if Q.gem > 0 and st.rar then
        local P = ShopLayout.PLAQUE
        local gx = x0 + P.padX
        local mid = lineY(Q.y0, gx - dx) + math.floor(Q.h / 2)
        local c = Palette.forRarity(st.rar)
        local hi = Palette.lighten(c, 0.35)
        local lo = Palette.darken(c, 0.6)
        for _, q in ipairs({ { -1, 0 }, { 3, 0 }, { 1, -2 }, { 1, 2 }, { 0, -1 }, { 2, -1 }, { 0, 1 }, { 2, 1 } }) do
            px(Palette.INK, a, gx + q[1], mid + q[2], 1, 1)
        end
        px(hi, a, gx + 1, mid - 1, 1, 1)
        px(c, a, gx, mid, 1, 1); px(hi, a, gx + 1, mid, 1, 1); px(c, a, gx + 2, mid, 1, 1)
        px(lo, a, gx + 1, mid + 1, 1, 1)
    end
    if st.sale then
        local top = lineY(Q.y0, x0 - dx)
        px(Palette.BLOOD, a, x0, top, 2, 1)
        px(Palette.BLOOD, a, x0, top + 1, 1, 1)
    end
end

function ShelfItem.drawPlaqueText(L, Q, dx, ink, alpha, shakeX)
    dx = dx or 0
    local cv = L.cover
    local P = ShopLayout.PLAQUE
    local tx0 = Q.x0 + dx + P.padX + Q.gem
    local sx = cv.ox + tx0 * cv.s + (shakeX or 0)
    local sy = cv.oy + (lineY(Q.y0, tx0 - dx) + 1) * cv.s
    local w = (Q.w - P.padX * 2 - Q.gem) * cv.s
    local h = (Q.h - 2) * cv.s
    local a = alpha or 1
    withShear(floor(sx), floor(sy), ShopLayout.K, function()
        love.graphics.setFont(Q.font)
        local tx = floor((w - Q.font:getWidth(Q.text)) / 2) + 1
        local ty = floor((h - Q.font:getHeight()) / 2) + 1
        Palette.set(Q.deny and Palette.INK or ShelfItem.BRASS.hi, 0.55 * a)
        love.graphics.print(Q.text, tx, ty + 1)
        love.graphics.setColor(ink[1], ink[2], ink[3], a)
        love.graphics.print(Q.text, tx, ty)
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

function ShelfItem:priceText()
    return "$" .. tostring(self.offer and self.offer.cost or 0)
end

function ShelfItem:_plaque(cv)
    local g = self.geom
    if not (g and g.plaque) then return nil end
    local rar = (self.kind == "card") and self.offer and self.offer.rarity or nil
    return ShelfItem.plaqueArt(g.plaque, self:priceText(), rar, cv), rar
end

function ShelfItem:_shake()
    if self.deny > 0 and not reducedMotion() then
        local k = (DENY_TIME - self.deny) / DENY_TIME
        return math.sin(k * math.pi * 4) * 3 * (1 - k)
    end
    return 0
end

local TAG_OMEGA2, TAG_DAMP = 62, 5.5
function ShelfItem.stepPendulum(tg, dt)
    if reducedMotion() then tg.angle, tg.vel = 0, 0 return end
    local h = math.min(dt, 1 / 30)
    local acc = -TAG_OMEGA2 * math.sin(tg.angle) - TAG_DAMP * tg.vel
    tg.vel = tg.vel + acc * h
    tg.angle = tg.angle + tg.vel * h
    if math.abs(tg.angle) < 0.002 and math.abs(tg.vel) < 0.02 then tg.angle, tg.vel = 0, 0 end
end
function ShelfItem.drawCordArt(x0, y0, x1, y1, a)
    x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
    local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
    local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
    local err = dx + dy
    local pts, ink = {}, {}
    local x, y = x0, y0
    for _ = 1, 400 do
        pts[#pts + 1] = { x + 0.5, y + 0.5 }
        ink[#ink + 1] = { x + 1.5, y + 0.5 }
        if x == x1 and y == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x = x + sx end
        if e2 <= dx then err = err + dx; y = y + sy end
    end
    local c = Palette.INK
    love.graphics.setColor(c[1], c[2], c[3], 0.6 * (a or 1))
    love.graphics.points(ink)
    c = Palette.PARCHMENT_DARK
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
    love.graphics.points(pts)
end

function ShelfItem.tagStyle(afford, sale)
    if sale then return Palette.BLOOD, Palette.BLOOD_DARK, Palette.PARCHMENT_LIGHT end
    if afford then return Palette.PARCHMENT_LIGHT, Palette.PARCHMENT_DARK, Palette.INK end
    return Palette.PARCHMENT, Palette.PARCHMENT_DARK, Palette.BLOOD
end

function ShelfItem.drawTagArt(tg, dx, dy, afford, sale, a, tie)
    local W, H = tg.w or ShopLayout.TAG_W, tg.h or ShopLayout.TAG_H
    local x0 = tg.x0 + dx
    local holeX = x0 + floor(W / 2)
    local holeY = lineY(tg.y0, holeX) - dy
    if tie and tg.edge then
        ShelfItem.drawCordArt(tie[1], tie[2], tg.edge.x, tg.edge.y, a)
        ShelfItem.drawCordArt(tg.edge.x, tg.edge.y, holeX, holeY, a)
    elseif tg.ceiling then
        ShelfItem.drawCordArt(tg.cordX + dx, tg.cordY, holeX, holeY, a)
    else
        local cx, cy = tg.cordX, tg.cordY - dy
        if tie then cx, cy = tie[1], tie[2] end
        ShelfItem.drawCordArt(cx, cy, holeX, holeY, a)
    end
    local face, low = ShelfItem.tagStyle(afford, sale)
    for x = x0, x0 + W - 1 do
        local top = lineY(tg.y0, x) - dy
        local edge = (x == x0 or x == x0 + W - 1)
        px(Palette.INK, 0.45 * a, x + 1, top + H, 1, 1)
        if edge then
            px(Palette.INK, a, x, top, 1, H)
        else
            px(Palette.INK, a, x, top, 1, 1)
            px(face, a, x, top + 1, 1, H - 3)
            px(low, a, x, top + H - 2, 1, 1)
            px(Palette.INK, a, x, top + H - 1, 1, 1)
        end
    end
    px(Palette.INK, 0.9 * a, holeX, holeY + 1, 1, 1)
end

function ShelfItem.drawTagText(L, tg, dx, dy, text, afford, sale, a, shakeX, line2, a2)
    local cv = L.cover
    local W, H0 = tg.w or ShopLayout.TAG_W, ShopLayout.TAG_H
    local x0 = tg.x0 + dx
    local sx = cv.ox + (x0 + 1) * cv.s + (shakeX or 0)
    local sy = cv.oy + (lineY(tg.y0, x0 + 1) - dy + 1) * cv.s
    local w, h = (W - 2) * cv.s, (H0 - 3) * cv.s
    local font, fitted = TextFit.fit(text, 8, w - 1, 7)
    local _, _, ink = ShelfItem.tagStyle(afford, sale)
    withShear(floor(sx), floor(sy), ShopLayout.K, function()
        love.graphics.setFont(font)
        Palette.set(ink, a)
        love.graphics.print(fitted, floor((w - font:getWidth(fitted)) / 2) + 1,
            floor((h - font:getHeight()) / 2) + 1)
        if line2 and (tg.h or H0) > H0 + 4 then
            local f2, t2 = TextFit.fit(line2, 8, w - 1, 7)
            local h2 = ((tg.h or H0) - H0 - 1) * cv.s
            love.graphics.setFont(f2)
            Palette.set(Palette.INK, (a2 or a))
            love.graphics.print(t2, floor((w - f2:getWidth(t2)) / 2) + 1,
                (H0 - 2) * cv.s + floor((h2 - f2:getHeight()) / 2))
        end
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

ShelfItem.LABEL_ROWS = 8
function ShelfItem.grownTag(tg, label, k, cv)
    if not label or label == "" or k <= 0.02 then return tg end
    local W0, H0 = tg.w or ShopLayout.TAG_W, ShopLayout.TAG_H
    local f = TextFit.fit(label, 8, 88 * cv.s, 7)
    local need = math.ceil(f:getWidth(label) / cv.s) + 4
    local W = math.max(W0, math.min(92, need))
    local W1 = W0 + math.floor((W - W0) * k + 0.5)
    local holeX = tg.x0 + math.floor(W0 / 2)
    local g = {}
    for kk, v in pairs(tg) do g[kk] = v end
    g.w = W1
    g.h = H0 + math.floor(ShelfItem.LABEL_ROWS * k + 0.5)
    g.x0 = holeX - math.floor(W1 / 2)
    return g
end

function ShelfItem.swingArt(angle)
    local s = ShopLayout.SWING
    return clamp(math.floor(math.sin(angle or 0) * 6 + 0.5), -s, s)
end

function ShelfItem.newTagFor(tg, cv)
    local txt = I18n.t("unlocks.new_badge", nil, "NOVA")
    local f = TextFit.fit(txt, 8, 60 * cv.s, 7)
    local need = math.ceil(f:getWidth(txt) / cv.s) + 5
    local W0 = tg.w or ShopLayout.TAG_W
    if need <= W0 then return tg end
    local g = {}
    for k, v in pairs(tg) do g[k] = v end
    g.w = need
    g.x0 = tg.x0 + math.floor(W0 / 2) - math.floor(need / 2)
    return g
end

function ShelfItem:isNew()
    return self.kind == "card" and self.card and self.card.isNewDiscovery and true or false
end

function ShelfItem:drawPlateArt(L, ctx)
    if self.sold then return end
    local cv = L.cover
    local g = self.geom
    local alpha = (ctx.alpha or 1) * self:entered()
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    local afford = ctx.afford and self.deny <= 0
    local sale = self.offer and self.offer.saleDiscount and true or false
    if self.kind == "card" then
        local Q, rar = self:_plaque(cv)
        if Q then
            ShelfItem.drawPlaqueArt(Q, sdx, { selected = self.selected, sale = sale, alpha = alpha, rar = rar, afford = afford })
        end
        if self:isNew() and g.newTag then
            ShelfItem.drawTagArt(ShelfItem.newTagFor(g.newTag, cv), sdx + ShelfItem.swingArt(self.tag.angle), 0, true, true, alpha)
        end
    elseif g.tag then
        local lift = floor(self:liftPx() / cv.s + 0.5)
        local tie = self._tieArt and { self._tieArt[1], self._tieArt[2] - lift } or nil
        local tg = ShelfItem.grownTag(g.tag, self:labelText(), self:labelK(), cv)
        ShelfItem.drawTagArt(tg, sdx + ShelfItem.swingArt(self.tag.angle), 0, afford, sale, alpha, tie)
    end
end

function ShelfItem:labelK()
    if self.kind == "card" or self.sold then return 0 end
    return math.max(self.hover, self.selected and 1 or 0)
end

function ShelfItem:drawPlateText(L, ctx)
    if self.sold then return end
    local cv = L.cover
    local g = self.geom
    local alpha = (ctx.alpha or 1) * self:entered()
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    local afford = ctx.afford and self.deny <= 0
    local sale = self.offer and self.offer.saleDiscount and true or false
    if self.kind == "card" then
        local Q = self:_plaque(cv)
        if Q then
            Q.deny = not afford
            ShelfItem.drawPlaqueText(L, Q, sdx, ShelfItem.priceInk(afford, sale), alpha, self:_shake())
        end
        if self:isNew() and g.newTag then
            ShelfItem.drawTagText(L, ShelfItem.newTagFor(g.newTag, cv), sdx + ShelfItem.swingArt(self.tag.angle), 0,
                I18n.t("unlocks.new_badge", nil, "NOVA"), true, true, alpha, 0)
        end
    elseif g.tag then
        local k = self:labelK()
        local tg = ShelfItem.grownTag(g.tag, self:labelText(), k, cv)
        ShelfItem.drawTagText(L, tg, sdx + ShelfItem.swingArt(self.tag.angle), 0,
            self:priceText(), afford, sale, alpha, self:_shake(), self:labelText(), alpha * clamp((k - 0.6) / 0.4, 0, 1))
    end
end

function ShelfItem.drawHoverName(text, cx, topY, slope, a, maxX, minX)
    if not text or text == "" or a <= 0.02 then return end
    local font = FontManager.getFont(9)
    local w = clamp(font:getWidth(text) + 12, 40, 220)
    local h = font:getHeight() + 7
    local x = cx - w / 2
    if maxX then x = math.min(x, maxX - w) end
    if minX then x = math.max(x, minX) end
    local y = topY - h - 4 - slope * (cx - x)
    ShelfItem.drawBand({ x = x, y = y, w = w, h = h, slope = slope }, text, Palette.INK,
        { alpha = a, paper = true })
end

function ShelfItem:labelText()
    local offer = self.offer
    if self.kind == "relic" then return UpgradeTile.effectLabel(offer) or offer.name or "?" end
    if self.kind == "pack" then return offer.name or "?" end
    return nil
end

function ShelfItem:drawHoverLabel(L, ctx)
    if true then return end
    if self.kind == "card" or self.sold then return end
    local a = clamp(self.hover * 1.4 - 0.2, 0, 1) * (ctx.alpha or 1)
    if self.selected and self.hover < 0.05 then return end
    local r = self.rect
    local sx0 = self.slide.x or 0
    local top = r.y - self:liftPx()
    local ab = self._artBox
    if ab and L.cover then top = L.cover.oy + (ab.y + 2) * L.cover.s end
    ShelfItem.drawHoverName(self:labelText(), self.geom.footX + sx0, top,
        self.geom.slope or 0, a, L.limitX, 8)
end

function ShelfItem:drawStandArt(L, part, alpha)
    local g = self.geom
    if not (g and g.railX0) or part ~= "front" then return end
    local cv = L.cover
    local a = alpha or 1
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    local x0, x1 = g.railX0 + sdx, g.railX1 + sdx
    local E = ShopLayout.LINES.shelfEdge
    local R, P = ShopLayout.RAIL_ART, ShopLayout.POST_H
    for i = 1, 3 do
        local x = x1 + i
        local base = lineY(E, x)
        for y = base - 2, base - 1 do
            if ShopPerspective.dithered(x, y, 0.85 - i * 0.22) then
                px(Palette.INK, 0.85 * a, x, y, 1, 1)
            end
        end
    end
    local edgeC = self.selected and Palette.AGED_GOLD_LIGHT or WOOD.hi
    local TOP = 2
    for x = x0, x1 do
        local base = lineY(E, x)
        local top = base - R
        if x == x0 or x == x1 then
            px(Palette.INK, a, x, top - 1, 1, R + 1)
        else
            px(Palette.INK, a, x, top - 1, 1, 1)
            px(edgeC, a, x, top, 1, 1)
            px(WOOD.lite, a, x, top + 1, 1, TOP - 1)
            px(WOOD.mid, a, x, top + TOP, 1, 1)
            px(WOOD.dark, a, x, top + TOP + 1, 1, R - TOP - 2)
            px(WOOD.deep, a, x, base - 1, 1, 1)
        end
    end
    for x = x0 + 4, x1 - 4 do
        local top = lineY(E, x) - R
        px(WOOD.mid, a, x, top + 1, 1, 1)
    end
    for _, bx in ipairs({ x0 + 1, x1 - 3 }) do
        for x = bx, bx + 2 do
            local top = lineY(E, x) - R - P
            px(Palette.INK, a, x, top - 1, 1, 1)
            px(WOOD.hi, a, x, top, 1, 1)
            px((x == bx) and WOOD.lite or WOOD.mid, a, x, top + 1, 1, P - 1)
        end
        px(Palette.INK, a, bx - 1, lineY(E, bx - 1) - R - P, 1, P)
        px(Palette.INK, a, bx + 3, lineY(E, bx + 3) - R - P, 1, P)
    end
end

ShelfItem.CARD_SHADOW = { w = 3, top = 4, density = { 0.75, 0.5, 0.28 }, alpha = 0.85 }
function ShelfItem:drawCardShadowArt(L, alpha)
    if self.sold then return end
    local g = self.geom
    if not (g and g.frame) then return end
    local cv = L.cover
    local S = ShelfItem.CARD_SHADOW
    local a = (alpha or 1) * self:entered() * S.alpha
    local _, _, x1, y1, x2, y2 = ShopLayout.cardQuad(g, 0, 0)
    local sdx = (self.slide.x or 0)
    local rx = floor((x1 + sdx - cv.ox) / cv.s)
    local topA = (y1 - cv.oy) / cv.s
    local baseA = (y2 - cv.oy) / cv.s
    for i = 1, S.w do
        local x = rx + i
        local yt = floor(topA + S.top + i * ShopLayout.K)
        local yb = floor(baseA - 1 + i * ShopLayout.K)
        for y = yt, yb do
            if ShopPerspective.dithered(x, y, S.density[i]) then px(Palette.INK, a, x, y, 1, 1) end
        end
    end
end

function ShelfItem:drawCard(ctx)
    if self.sold then return end
    local inst = self.card
    if not (inst and inst.image) then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local img = inst.image
    do
        local okCF, CardFrame = pcall(require, "src.ui.CardFrame")
        if okCF and CardFrame.displayImage then img = CardFrame.displayImage(inst) or img end
    end
    local x0, y0, x1, y1, x2, y2, x3, y3 = self:cardCorners()
    local dim = ctx.afford and 1 or 0.8
    local a = alpha * (1 - clamp(inst.dissolve or 0, 0, 1))
    local CardMesh = require("src.ui.CardMesh")
    local shader = CardMesh.getShader()
    local glowK = self.selected and 0.85 or (self.hover * 0.55)
    local glowC = self.selected and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
    if shader then
        local iw, ih = img:getWidth(), img:getHeight()
        local mesh = CardMesh.getMesh(iw, ih)
        mesh:setTexture(img)
        love.graphics.setShader(shader)
        local T = self.tilt or { x = 0, y = 0 }
        local hv = reducedMotion() and 0 or self.hover
        CardMesh.setUniforms(shader, { T.x, T.y }, hv, ctx.t or 0, img)
        if glowK > 0.01 then
            local gc = glowC
            local d0 = math.max(2, math.floor((self.geom.frame and self.geom.frame.s or 2) + 0.5))
            shader:send("silhouette", 1)
            love.graphics.setColor(gc[1], gc[2], gc[3], glowK * a)
            local rings = self.selected and { d0 * 2, d0 } or { d0 }
            for ri, dd in ipairs(rings) do
                if self.selected and ri == 2 then
                    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], glowK * a)
                else
                    love.graphics.setColor(gc[1], gc[2], gc[3], glowK * a)
                end
                for _, d in ipairs({ { dd, 0 }, { -dd, 0 }, { 0, dd }, { 0, -dd } }) do
                    local r0, r1, r2 = ShopPerspective.homography(x0 + d[1], y0 + d[2], x1 + d[1], y1 + d[2],
                        x2 + d[1], y2 + d[2], x3 + d[1], y3 + d[2])
                    CardMesh.setQuad(shader, r0, r1, r2)
                    love.graphics.draw(mesh, 0, 0)
                end
            end
            shader:send("silhouette", 0)
        end
        local r0, r1, r2 = ShopPerspective.homography(x0, y0, x1, y1, x2, y2, x3, y3)
        CardMesh.setQuad(shader, r0, r1, r2)
        love.graphics.setColor(dim, dim, dim, a)
        love.graphics.draw(mesh, 0, 0)
        shader:send("quadOn", 0)
        love.graphics.setShader()
    else
        local s = (y3 - y0) / img:getHeight()
        withShear(x0, y0, (y1 - y0) / math.max(1, x1 - x0), function()
            love.graphics.setColor(dim, dim, dim, a)
            love.graphics.draw(img, 0, 0, 0, (x1 - x0) / img:getWidth(), s)
        end)
    end
    if inst.isNewDiscovery then
        local okDM, DM = pcall(require, "src.ui.DiscoveryMark")
        if okDM and DM.reveal then DM.reveal(inst.id) end
    end
    local minX, maxX = math.min(x0, x3), math.max(x1, x2)
    local minY, maxY = math.min(y0, y1), math.max(y2, y3)
    self._drawRect = { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
    inst._drawRect = self._drawRect
    love.graphics.setColor(1, 1, 1, 1)
end

function ShelfItem:drawShadowArt(L, ctx)
    if self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local o = self:uprightParams(L, self.hover > 0.5 or self.selected, ctx.t or 0)
    if not o then return end
    ShopPerspective.drawObjectShadow(o, L.art.tableMask, alpha)
end

function ShelfItem:shadowScreenRect(L)
    if self.sold then return nil end
    local o = self:uprightParams(L, false, 0)
    if not o then return nil end
    local b = ShopPerspective.castShadowBox(o)
    if not b then return nil end
    local cv = L.cover
    return { x = cv.ox + b.x * cv.s, y = cv.oy + b.y * cv.s, w = b.w * cv.s, h = b.h * cv.s }
end

function ShelfItem:drawObjectArt(L, ctx)
    if self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local o = self:uprightParams(L, self.hover > 0.5 or self.selected, ctx.t or 0)
    if not o then return end
    o.alpha = alpha
    local dim = ctx.afford and 1 or 0.8
    local amb = ShopLayout.ambientAt((self.geom.footX - L.cover.ox) / L.cover.s, (self.geom.foot - L.cover.oy) / L.cover.s)
    o.color = { dim * amb[1], dim * amb[2], dim * amb[3] }
    local sale = self.offer and self.offer.saleDiscount
    o.outline = math.max(self.hover * 0.8, self.selected and 1 or 0, sale and 0.7 or 0)
    o.outlineColor = (self.selected and Palette.AGED_GOLD_LIGHT)
        or (sale and Palette.lerp(Palette.AGED_GOLD_LIGHT, Palette.ORANGE, 0.5))
        or Palette.PARCHMENT_LIGHT
    ShopPerspective.drawUpright(o)
    self._artBox = ShopPerspective.uprightBox(o)
    local tx, ty = ShopPerspective.tiePoint(o, 0.06)
    self._tieArt = { floor(tx), floor(ty + (o.lift or 0)) }
end

function ShelfItem:drawDustArt(L)
    if not self.sold then return end
    local cv = L.cover
    local g = self.geom
    local img = art("assets/sprites/shop/dust_mark.png", true)
    local fx = (g.footX + (self.slide.x or 0) - cv.ox) / cv.s
    local fy = (g.foot - cv.oy) / cv.s
    local wArt = (self.kind == "card" and g.qw or g.rect.w) / cv.s
    if self.kind == "card" then fy = (g.stand.y + g.stand.h - cv.oy) / cv.s end
    if img then
        local dw = wArt * 0.95
        local dh = math.max(4, wArt * 0.22)
        withShear(floor(fx), floor(fy), g.slope or 0, function()
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.draw(img, -dw / 2, -dh * 0.8, 0, dw / img:getWidth(), dh / img:getHeight())
        end)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShelfItem:drawSoldText(ctx)
    if not self.sold then return end
    local g = self.geom
    local r = self.rect
    local alpha = ctx.alpha or 1
    local cx = g.footX + (self.slide.x or 0)
    local baseY = (self.kind == "card") and (g.foot - 12) or (g.foot - 10)
    local txt = I18n.t("reward.sold")
    local font, fitted = TextFit.fit(txt, clamp(floor(r.w * 0.13), 8, 14), r.w)
    love.graphics.setFont(font)
    local tw, th = font:getWidth(fitted), font:getHeight()
    withShear(cx, baseY, g.slope or 0, function()
        Palette.set(Palette.INK, 0.6 * alpha)
        love.graphics.print(fitted, -tw / 2 + 1, -th / 2 + 1)
        Palette.set(Palette.PARCHMENT_LIGHT, 0.85 * alpha)
        love.graphics.print(fitted, -tw / 2, -th / 2)
        love.graphics.rectangle("fill", -tw / 2 - 2, th / 2 + 1, tw + 4, 1)
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

function ShelfItem.drawPortrait(kind, offer, x, y, w, h, alpha)
    local animate = (kind == "relic")
    local img = ShopPerspective.spriteFor(kind, offer, animate, love.timer.getTime())
    if not img then return false end
    local pz = ShopPerspective.poseFor(kind, offer)
    local iw, ih = img:getWidth(), img:getHeight()
    local k = math.min(w / iw, h / ih)
    if k >= 1 then k = math.floor(k) end
    local dx = floor(x + w / 2)
    local dy = floor(y + (h - ih * k) / 2)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, dx, dy, 0, pz.flip and -k or k, k, iw / 2, 0)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

return ShelfItem
