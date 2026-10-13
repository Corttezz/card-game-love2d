-- src/ui/shop/ShelfItem.lua
-- Um OBJETO do Balcão do Mercador em perspectiva (Loja v3b): a oferta do
-- ShopSystem + a âncora do PÉ que o ShopLayout lhe deu (em coordenadas da
-- arte convertidas pra tela) + a placa de latão + o estado de interação.
--
-- Três espécies, uma classe:
--   card   → a carta num CAVALETE da borda do fundo, com perspectiva fixa
--            (shaders/card_perspective.glsl: a borda direita foge)
--   relic  → objeto NOVO sobre a mesa (assets/sprites/shop/objects/<id>.png)
--   pack   → fardo amarrado sobre a mesa (mesma pasta, pack_<kind>)
--
-- Regras (docs/plan/shop-v3-balcao.md §12):
--   repouso  = apoiado (pé na âncora), sombra de contato, placa de latão sob
--              o objeto: rótulo em cima (raridade / efeito / nome) e preço
--   hover    = levanta 8 px + brilho de borda; selecionado = brilho firme
--   compra   = objeto voa pro destino, marca de poeira + VENDIDO na placa
--   sem ouro = preço vermelho e a placa treme 2x
--   oferta do dia = brilho âmbar fixo + etiqueta vermelha (ShopProps.saleTag)
--   reducedMotion remove o MOVIMENTO; preço, VENDIDO e foco continuam.

local ShelfItem = {}
ShelfItem.__index = ShelfItem

local Palette     = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local TextFit     = require("src.ui.TextFit")
local ImageCache  = require("src.ui.ImageCache")
local Moveable    = require("engine.Moveable")
local UpgradeTile = require("src.ui.UpgradeTile")
local I18n        = require("src.i18n.I18n")

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local DENY_TIME = 0.45

-- ---------------------------------------------------------------------------
-- assets: objetos novos da mesa + miúdos. Faltar arquivo AVISA e cai no
-- desenho antigo (voucher do UpgradeTile / sleeve do PackSleeve).
-- ---------------------------------------------------------------------------
local ART = {}
local artWarned = {}
local function art(path, quiet)
    if ART[path] ~= nil then return ART[path] or nil end
    local img = ImageCache.tryGet(path)
    if not img then
        ART[path] = false
        if not quiet and not artWarned[path] then
            artWarned[path] = true
            print("[ShelfItem] " .. path .. " ausente — desenho de reserva")
        end
        return nil
    end
    ART[path] = img
    return img
end
ShelfItem.art = art

function ShelfItem.objectSprite(offer)
    if not offer then return nil end
    return art("assets/sprites/shop/objects/" .. tostring(offer.id) .. ".png")
end

-- ---------------------------------------------------------------------------
function ShelfItem.new(kind, offer, slot)
    local self = setmetatable({}, ShelfItem)
    self.kind = kind
    self.offer = offer
    self.slot = slot
    self.hover = 0
    self.hot = false
    self.selected = false
    self.entry = { v = 1 }       -- 0..1 entrada (tabela: sobrevive ao rebuild)
    self.slide = { x = 0 }       -- deslize de reposição (sino)
    self.sold = offer and offer.purchased or false
    self.deny = 0
    Moveable.initJuice(self)
    return self
end

function ShelfItem:exportFx()
    return { hover = self.hover, hot = self.hot, juice = self.juice, entry = self.entry,
             slide = self.slide, deny = self.deny, dustSeed = self.dustSeed }
end

function ShelfItem:importFx(fx)
    if not fx then return end
    self.hover, self.hot, self.juice = fx.hover, fx.hot, fx.juice
    self.entry = fx.entry or self.entry
    self.slide = fx.slide or self.slide
    self.deny = fx.deny or 0
    self.dustSeed = fx.dustSeed
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

-- Hit-test: objeto + placa (clicar na placa também seleciona).
function ShelfItem:hit(mx, my)
    local r, p = self.rect, self.geom and self.geom.plate
    if not r or self.sold then return false end
    local x = mx - (self.slide.x or 0)
    if x >= r.x and x <= r.x + r.w and my >= r.y - (self.geom.lift or 0) and my <= r.y + r.h then return true end
    if p and x >= p.x and x <= p.x + p.w and my >= p.y and my <= p.y + p.h then return true end
    return false
end

function ShelfItem:center()
    local r = self.rect
    return r.x + r.w / 2 + (self.slide.x or 0), r.y + r.h / 2
end

-- ---------------------------------------------------------------------------
function ShelfItem:update(dt, hovered)
    local reduced = reducedMotion()
    local target = (hovered and not self.sold) and 1 or 0
    local entered = false
    if target == 1 and not self.hot then
        self.hot = true
        entered = true
        if not reduced then Moveable.juice_up(self, 0.06, 0.02) end
    elseif target == 0 then
        self.hot = false
    end
    if reduced then self.hover = target
    else self.hover = self.hover + (target - self.hover) * math.min(1, dt * 12) end
    Moveable.updateJuice(self, dt)
    if self.deny > 0 then self.deny = math.max(0, self.deny - dt) end
    return entered
end

function ShelfItem:liftPx()
    if reducedMotion() then return 0 end
    local maxLift = (self.geom and self.geom.lift) or 8
    return self.hover * maxLift - Moveable.hopOffset(self)
end

function ShelfItem:denyPurchase() self.deny = DENY_TIME end

function ShelfItem:markSold()
    self.sold = true
    if self.offer then self.offer.purchased = true end
    self.dustSeed = self.dustSeed or (self.slot * 17 + 3)
end

-- O que VOA na compra (imagem + origem + escala), ou nil (pacote abre tela).
function ShelfItem:flyPayload()
    local r = self.rect
    if self.kind == "card" and self.card and self.card.image then
        local inst = self.card
        return { img = inst.image, x = inst.homeX + (self.slide.x or 0), y = inst.homeY,
                 scale = inst.baseScale or 1, ox = 0, oy = 0 }
    end
    local sprite = ShelfItem.objectSprite(self.offer)
    if not sprite and self.kind == "relic" then sprite = UpgradeTile.spriteFor(self.offer.id, false, 0) end
    if not sprite then return nil end
    local sw, sh = sprite:getWidth(), sprite:getHeight()
    local s = r.w / sw
    return { img = sprite, x = self.geom.footX + (self.slide.x or 0), y = self.foot - sh * s / 2,
             scale = s, ox = sw / 2, oy = sh / 2 }
end

-- ---------------------------------------------------------------------------
-- PLACA DE LATÃO (compartilhada: cartas, objetos, sino, copo)
--   lines = { { text, color }, { text, color } }
-- ---------------------------------------------------------------------------
function ShelfItem.drawPlate(p, lines, opts)
    opts = opts or {}
    local a = opts.alpha or 1
    local shake = opts.shakeX or 0
    local x, y, w, h = math.floor(p.x + shake), p.y, p.w, p.h
    -- sombra, borda escura, latão com luz em cima
    Palette.set(Palette.INK, 0.5 * a)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h)
    Palette.set(Palette.INK, a)
    love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2)
    local top = Palette.lerp(Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, 0.35)
    local bot = Palette.AGED_GOLD_DARK
    for row = 0, h - 1 do
        local c = Palette.lerp(top, bot, row / math.max(1, h - 1))
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle("fill", x, y + row, w, 1)
    end
    Palette.set(Palette.AGED_GOLD_LIGHT, 0.6 * a)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 1)
    Palette.set(Palette.AGED_GOLD_DARK, 0.9 * a)
    love.graphics.rectangle("fill", x + 1, y + h - 2, w - 2, 1)
    -- rebites nos cantos
    Palette.set(Palette.INK, 0.8 * a)
    for _, cx in ipairs({ x + 3, x + w - 4 }) do
        love.graphics.rectangle("fill", cx, y + 3, 1, 1)
        love.graphics.rectangle("fill", cx, y + h - 4, 1, 1)
    end
    -- texto gravado (sombra clara embaixo = baixo-relevo)
    local n = #lines
    local lineH = math.floor((h - 6) / math.max(1, n))
    for i, ln in ipairs(lines) do
        local txt = ln[1] or ""
        if txt ~= "" then
            local font, fitted = TextFit.fit(txt, clamp(lineH - 2, 7, 11), w - 8, 7)
            love.graphics.setFont(font)
            local tx = x + math.floor((w - font:getWidth(fitted)) / 2)
            local ty = y + 3 + (i - 1) * lineH + math.floor((lineH - font:getHeight()) / 2)
            Palette.set(Palette.AGED_GOLD_LIGHT, 0.45 * a)
            love.graphics.print(fitted, tx, ty + 1)
            local c = ln[2] or Palette.INK
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.print(fitted, tx, ty)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Linhas da placa deste item (rótulo + preço), já resolvidas pelo i18n.
function ShelfItem:plateLines(ctx)
    local offer = self.offer
    local lines = {}
    if self.kind == "card" then
        if offer.rarity then
            local TextCase = require("src.i18n.TextCase")
            local c = Palette.forRarity(offer.rarity)
            lines[1] = { TextCase.upper(I18n.t("rarity." .. offer.rarity, nil, offer.rarity)),
                         Palette.darken(c, (offer.rarity == "common" or offer.rarity == "basic") and 0.45 or 0.8) }
        else
            lines[1] = { "" }
        end
    elseif self.kind == "relic" then
        lines[1] = { UpgradeTile.effectLabel(offer) or offer.name or "?", Palette.INK }
    else
        lines[1] = { offer.name or "?", Palette.INK }
    end
    if self.sold then
        lines[2] = { I18n.t("reward.sold"), Palette.BLOOD_DARK }
    else
        local price = "$" .. tostring(offer.cost or 0)
        lines[2] = { price, (ctx.afford and self.deny <= 0) and Palette.INK or Palette.BLOOD }
    end
    return lines
end

function ShelfItem:drawPlateFor(ctx)
    local p = self.geom and self.geom.plate
    if not p then return end
    local shake = 0
    if self.deny > 0 and not reducedMotion() then
        local k = (DENY_TIME - self.deny) / DENY_TIME
        shake = math.sin(k * math.pi * 4) * 3 * (1 - k)
    end
    local alpha = (ctx.alpha or 1) * self:entered()
    local pr = { x = p.x + (self.slide.x or 0), y = p.y, w = p.w, h = p.h }
    ShelfItem.drawPlate(pr, self:plateLines(ctx), { alpha = alpha, shakeX = shake })
end

-- Suporte/cavalete de madeira (card_stand_N.png). `front` = lábio da frente.
function ShelfItem:drawStand(front, alpha)
    local st = self.geom and self.geom.stand
    if not st then return end
    local img = art("assets/sprites/shop/card_stand_" .. tostring(self.geom.standVariant or 1) .. ".png")
    local sx0 = self.slide.x or 0
    love.graphics.setColor(1, 1, 1, alpha or 1)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx, sy = st.w / iw, st.h / ih
        if front then
            local q = ShelfItem._frontQuads[img]
            if not q then
                q = love.graphics.newQuad(0, ih * 0.4, iw, ih * 0.6, iw, ih)
                ShelfItem._frontQuads[img] = q
            end
            love.graphics.draw(img, q, st.x + sx0, st.y + st.h * 0.4, 0, sx, sy)
        else
            love.graphics.draw(img, st.x + sx0, st.y, 0, sx, sy)
        end
    else
        local wood = Palette.lerp(Palette.RUST, Palette.INK, 0.5)
        Palette.set(wood, alpha)
        if front then love.graphics.rectangle("fill", st.x + sx0, st.y + st.h * 0.4, st.w, st.h * 0.6)
        else love.graphics.rectangle("fill", st.x + sx0, st.y, st.w, st.h) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end
ShelfItem._frontQuads = setmetatable({}, { __mode = "k" })

-- Brilho de borda (hover / seleção / oferta do dia): o sprite em dourado
-- deslocado 2 px nas direções, por baixo do sprite.
local function glowAround(drawable, x, y, sx, sy, color, a)
    if a <= 0.01 then return end
    love.graphics.setColor(color[1], color[2], color[3], a)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 } }) do
        love.graphics.draw(drawable, x + d[1] * 2, y + d[2] * 2, 0, sx, sy)
    end
end

-- ctx = { t, afford, alpha, reduced }
function ShelfItem:drawObject(ctx)
    if self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local r = self.rect
    local lift = self:liftPx()
    local s = Moveable.scaleFactor(self) * Moveable.swellFactor(self) * (0.7 + 0.3 * self:entered())
    local sx0 = self.slide.x or 0
    local cx = self.geom.footX + sx0
    local glowK = math.max(self.hover * 0.8, self.selected and 0.9 or 0)
    local sale = self.offer and self.offer.saleDiscount
    local glowColor = sale and Palette.lerp(Palette.AGED_GOLD_LIGHT, Palette.ORANGE, 0.5) or Palette.AGED_GOLD_LIGHT
    if sale then glowK = math.max(glowK, 0.55) end

    if self.kind == "card" then
        local inst = self.card
        if not (inst and inst.image) then return end
        local img = inst.image
        if (self.hover > 0.5 or self.selected) then
            local okCF, CardFrame = pcall(require, "src.ui.CardFrame")
            if okCF and CardFrame.liveImage then img = CardFrame.liveImage(inst) or img end
        end
        local iw, ih = img:getWidth(), img:getHeight()
        local cs = (inst.baseScale or 1) * s
        local w, h = iw * cs, ih * cs
        local x = cx - w / 2
        local y = self.foot - h - lift
        local dim = ctx.afford and 1 or 0.6
        local fade = 1 - clamp(inst.dissolve or 0, 0, 1)
        local a = alpha * fade
        -- sombra projetada no cavalete
        love.graphics.setColor(0, 0, 0, 0.35 * a)
        love.graphics.rectangle("fill", x + 4, y + 6, w, h)
        local CardMesh = require("src.ui.CardMesh")
        local shader = CardMesh.getShader()
        local tilt = self.geom.tilt or { 0, 0 }
        local amount = (self.geom.tiltAmount or 0.7) * (1 - 0.25 * self.hover)
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(cs, cs)
        if shader then
            local mesh = CardMesh.getMesh(iw, ih)
            mesh:setTexture(img)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, tilt, amount, ctx.t or 0, img)
            glowAround(mesh, 0, 0, 1, 1, glowColor, glowK * a * 0.7)
            love.graphics.setColor(dim, dim, dim, a)
            love.graphics.draw(mesh, 0, 0)
            love.graphics.setShader()
        else
            glowAround(img, 0, 0, 1, 1, glowColor, glowK * a * 0.7)
            love.graphics.setColor(dim, dim, dim, a)
            love.graphics.draw(img, 0, 0)
        end
        if inst.isNewDiscovery then
            local okDM, DM = pcall(require, "src.ui.DiscoveryMark")
            if okDM and DM.drawOnCard then
                pcall(DM.drawOnCard, inst, img, 0, 0, { 0, 0 }, self.hover, ctx.t or 0)
            end
        end
        love.graphics.pop()
        self._drawRect = { x = x, y = y, w = w, h = h }
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- objeto da mesa: sprite novo (ou reserva)
    local sprite = ShelfItem.objectSprite(self.offer)
    local fallbackPack = false
    if not sprite then
        if self.kind == "relic" then sprite = UpgradeTile.spriteFor(self.offer.id, false, 0)
        else fallbackPack = true end
    end
    local dim = ctx.afford and 1 or 0.6
    if sprite then
        local sw, sh = sprite:getWidth(), sprite:getHeight()
        local k = (r.w / sw) * s
        local dw, dh = sw * k, sh * k
        local x = cx - dw / 2
        local y = self.foot - dh - lift
        -- sombra de contato (encolhe ao levantar)
        love.graphics.setColor(0, 0, 0, 0.45 * alpha * (1 - lift / 16))
        love.graphics.ellipse("fill", cx, self.foot - 1, dw * 0.38, math.max(2, dh * 0.07))
        glowAround(sprite, x, y, k, k, glowColor, glowK * alpha * 0.7)
        love.graphics.setColor(dim, dim, dim, alpha)
        love.graphics.draw(sprite, x, y, 0, k, k)
        self._drawRect = { x = x, y = y, w = dw, h = dh }
    elseif fallbackPack then
        local okPS, PackSleeve = pcall(require, "src.ui.PackSleeve")
        if okPS and PackSleeve then
            local sw, sh = PackSleeve.getDimensions()
            local k = (r.w / sw) * 0.8 * s
            PackSleeve.drawAt(self.offer.id, self.offer.kind, math.floor(cx), math.floor(self.foot - sh * k / 2 - lift),
                k, alpha * dim, { hover = self.hover, key = "shelf_pack_" .. tostring(self.slot) })
        end
        self._drawRect = { x = r.x + sx0, y = r.y - lift, w = r.w, h = r.h }
    end
    -- etiqueta da oferta do dia (F4) presa no canto do objeto
    if sale then
        local okP, ShopProps = pcall(require, "src.ui.shop.ShopProps")
        if okP and ShopProps and ShopProps.saleTag and ShopProps.saleTag.draw then
            local tw = math.max(24, math.floor(r.w * 0.45))
            love.graphics.setColor(1, 1, 1, alpha)
            ShopProps.saleTag.draw(cx + r.w * 0.2, self.foot - r.h - lift - 4, tw / (ShopProps.saleTag.W or 24))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Marca de poeira no lugar do objeto + "VENDIDO" a giz (i18n reward.sold).
function ShelfItem:drawDust(ctx)
    if not self.sold then return end
    local r = self.rect
    local alpha = ctx.alpha or 1
    local img = art("assets/sprites/shop/dust_mark.png", true)
    local cx = self.geom.footX + (self.slide.x or 0)
    local dw = r.w * 0.95
    local dh = math.max(10, r.w * 0.28)
    if img then
        love.graphics.setColor(1, 1, 1, 0.7 * alpha)
        love.graphics.draw(img, cx - dw / 2, self.foot - dh * 0.8, 0, dw / img:getWidth(), dh / img:getHeight())
    else
        Palette.set(Palette.PARCHMENT_DARK, 0.35 * alpha)
        love.graphics.ellipse("fill", cx, self.foot - 2, dw * 0.45, dh * 0.3)
    end
    local txt = I18n.t("reward.sold")
    local font, fitted = TextFit.fit(txt, clamp(math.floor(r.w * 0.13), 8, 14), r.w)
    love.graphics.setFont(font)
    love.graphics.push()
    love.graphics.translate(cx, self.foot - r.h * 0.45)
    love.graphics.rotate(-0.18)
    local tw, th = font:getWidth(fitted), font:getHeight()
    Palette.set(Palette.INK, 0.6 * alpha)
    love.graphics.print(fitted, -tw / 2 + 1, -th / 2 + 1)
    Palette.set(Palette.PARCHMENT_LIGHT, 0.85 * alpha)
    love.graphics.print(fitted, -tw / 2, -th / 2)
    love.graphics.rectangle("fill", -tw / 2 - 2, th / 2 + 1, tw + 4, 1)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return ShelfItem
