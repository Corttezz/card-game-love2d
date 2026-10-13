-- src/ui/shop/ShelfItem.lua
-- Um OBJETO do Balcão do Mercador em perspectiva (Loja v3c): a oferta do
-- ShopSystem + a âncora do PÉ que o ShopLayout lhe deu (coordenadas da arte
-- convertidas pra tela) + a etiqueta de preço + o estado de interação.
--
-- Três espécies, uma classe:
--   card   → a carta num CAVALETE da borda do fundo, PARALELA à borda: os
--            4 cantos saem de ShopLayout.cardQuad e o card_perspective.glsl
--            mapeia a carta inteira por homografia (perspectiva de verdade,
--            não o "press" de 6-8 graus). Hover: o lado direito afunda, o
--            esquerdo sobe e ela levanta um pouco.
--   relic  → a arte ANTIGA do voucher (assets/sprites/vouchers/<id>.png; a
--            animação de vouchers_anim/ entra no hover) EM PÉ sobre a mesa
--   pack   → a arte ANTIGA do pacote (assets/sprites/packs/<id>.png) em pé
--
-- Regras (queixa do dono 13/Out/2026, docs/plan/shop-v3-balcao.md §13):
--   * TUDO na diagonal da mesa: objeto (cisalhamento pelo slope até o ponto
--     de fuga, ShopPerspective), sombra, etiqueta, faixa, carta, cavalete.
--   * NADA flutua: o pé real da arte (perfil da silhueta) cai no tampo e a
--     sombra é de CONTATO (dither, colada na base), nunca elipse.
--   * Hover = o MESMO sprite (mesma pose, mesmo espelho, mesmo cisalhamento)
--     levantado 4-6 px com contorno claro de 1 px de arte. Nunca troca de
--     imagem (pose() é igual em repouso e hover; test_shop_scene trava).
--   * Preço = etiqueta pendurada (a das cartas). Nome/efeito = faixa de
--     pergaminho na diagonal SÓ no hover; sempre no pergaminho da direita.
--   reducedMotion remove o MOVIMENTO; preço, VENDIDO e foco continuam.

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

-- Hover (Loja "reta"): tempo LINEAR + easing simétrico. A volta percorre o
-- mesmo caminho da ida, quadro a quadro, sem salto no começo nem no fim (a
-- aproximação exponencial antiga saía com o passo maior no primeiro quadro).
ShelfItem.HOVER_TIME = 0.18
function ShelfItem.ease(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

-- madeira da cena v4 (a rampa de tools/shop_v4_compose.py)
local WOOD = {
    hi   = { 246 / 255, 196 / 255, 112 / 255 },
    lite = { 180 / 255, 110 / 255, 52 / 255 },
    mid  = { 112 / 255, 60 / 255, 33 / 255 },
    dark = { 60 / 255, 29 / 255, 21 / 255 },
    deep = { 18 / 255, 8 / 255, 10 / 255 },
}
ShelfItem.WOOD = WOOD
-- v4: o objeto entra na grade da cena em ESCALA INTEIRA (1 = pixel do
-- sprite = pixel da pintura). Só arte bem maior que o slot cai pra 1/n.
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
            print("[ShelfItem] " .. path .. " ausente")
        end
        return nil
    end
    ART[path] = img
    return img
end
ShelfItem.art = art

-- ---------------------------------------------------------------------------
function ShelfItem.new(kind, offer, slot)
    local self = setmetatable({}, ShelfItem)
    self.kind = kind
    self.offer = offer
    self.slot = slot
    self.hover = 0               -- 0..1 COM easing (o que se desenha)
    self.hoverT = 0              -- 0..1 linear no tempo (ida e volta pelo mesmo caminho)
    self.hot = false
    self.selected = false
    self.entry = { v = 1 }       -- 0..1 entrada (tabela: sobrevive ao rebuild)
    self.slide = { x = 0 }       -- deslize de reposição (sino)
    self.sold = offer and offer.purchased or false
    self.deny = 0
    self.tag = { angle = 0, vel = 0 }   -- etiqueta pendurada
    self.tilt = { x = 0, y = 0, ox = 0, oy = 0 }   -- tilt 3D do hover (carta)
    Moveable.initJuice(self)
    return self
end

-- Pêndulo amortecido (~1,25 Hz, assenta em ~0,6 s).
local TAG_OMEGA2, TAG_DAMP = 62, 5.5
function ShelfItem.stepPendulum(tg, dt)
    if reducedMotion() then tg.angle, tg.vel = 0, 0 return end
    local h = math.min(dt, 1 / 30)
    local acc = -TAG_OMEGA2 * math.sin(tg.angle) - TAG_DAMP * tg.vel
    tg.vel = tg.vel + acc * h
    tg.angle = tg.angle + tg.vel * h
    if math.abs(tg.angle) < 0.002 and math.abs(tg.vel) < 0.02 then tg.angle, tg.vel = 0, 0 end
end

function ShelfItem:exportFx()
    return { hover = self.hover, hoverT = self.hoverT, hot = self.hot, juice = self.juice, entry = self.entry,
             slide = self.slide, deny = self.deny, dustSeed = self.dustSeed, tag = self.tag, tilt = self.tilt }
end

function ShelfItem:importFx(fx)
    if not fx then return end
    self.hover, self.hot, self.juice = fx.hover, fx.hot, fx.juice
    self.hoverT = fx.hoverT or fx.hover or 0
    self.entry = fx.entry or self.entry
    self.slide = fx.slide or self.slide
    self.deny = fx.deny or 0
    self.dustSeed = fx.dustSeed
    self.tag = fx.tag or self.tag
    self.tilt = fx.tilt or self.tilt
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

-- Os 4 cantos da carta AGORA (hover + lift + deslize), px de tela.
function ShelfItem:cardCorners()
    local g = self.geom
    local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, reducedMotion() and 0 or self.hover, self:liftPx())
    -- parallax do tilt (a carta segue um pouco o cursor, como na mão)
    local sx = (self.slide.x or 0) + (self.tilt and self.tilt.ox or 0)
    local sy = self.tilt and self.tilt.oy or 0
    return x0 + sx, y0 + sy, x1 + sx, y1 + sy, x2 + sx, y2 + sy, x3 + sx, y3 + sy
end

-- Hit-test: carta = o quadrilátero dela; objeto = caixa + etiqueta.
function ShelfItem:hit(mx, my)
    local r, p = self.rect, self.geom and self.geom.plate
    if not r or self.sold then return false end
    local x = mx - (self.slide.x or 0)
    if self.kind == "card" and self.geom.qw then
        local g = self.geom
        local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, 0, 0)
        -- quadrilátero em repouso + a faixa de levantar (o hover não foge do mouse)
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

-- ---------------------------------------------------------------------------
-- HOVER DA CARTA (Loja v4, pedido do dono: "quando mexer nas pontas, a
-- carta ir mexendo junto"). A pose diagonal é a BASE; por cima dela entra o
-- tilt 3D da mão e das recompensas (Card.hoverTilt, a mesma conta): o mouse
-- vai pro espaço da carta pela inversa da homografia de REPOUSO (o alvo não
-- foge do cursor) e o card_perspective.glsl aplica o "press" antes da
-- homografia, então a diagonal fica e o canto sob o cursor afunda. Tilt e
-- parallax com amortecimento exponencial (entra e sai suave); reducedMotion
-- zera o movimento.
ShelfItem.TILT_EASE = 12          -- 1/s (≈ 90% em 0,19 s)
ShelfItem.TILT_PARALLAX = 0.5     -- fração do MOVE_RANGE da mão (px)
function ShelfItem:cardMouseUV(mx, my)
    local g = self.geom
    if not (g and g.frame and mx) then return nil end
    local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(g, 0, 0)
    local sx = self.slide.x or 0
    local r0, r1, r2 = ShopPerspective.homography(x0 + sx, y0, x1 + sx, y1, x2 + sx, y2, x3 + sx, y3)
    return ShopPerspective.unmapH(r0, r1, r2, mx, my)
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

function ShelfItem:update(dt, hovered, mx, my)
    local reduced = reducedMotion()
    local target = (hovered and not self.sold) and 1 or 0
    local entered = false
    if target == 1 and not self.hot then
        self.hot = true
        entered = true
        if not reduced then
            self.tag.vel = self.tag.vel + 2.4
        end
    elseif target == 0 then
        self.hot = false
    end
    if reduced then self.hoverT = target
    else
        local step = dt / ShelfItem.HOVER_TIME
        if target > self.hoverT then self.hoverT = math.min(target, self.hoverT + step)
        else self.hoverT = math.max(target, self.hoverT - step) end
    end
    self.hover = ShelfItem.ease(self.hoverT)
    Moveable.updateJuice(self, dt)
    if self.kind == "card" then self:updateTilt(dt, target == 1, mx, my) end
    ShelfItem.stepPendulum(self.tag, dt)
    if self.deny > 0 then self.deny = math.max(0, self.deny - dt) end
    return entered
end

-- Quanto o objeto está levantado (px de tela). Sem juice de escala: o hover
-- é o MESMO sprite, só mais alto.
function ShelfItem:liftPx()
    if reducedMotion() then return 0 end
    local maxLift = (self.geom and self.geom.lift) or 5
    return self.hover * maxLift - Moveable.hopOffset(self)
end

function ShelfItem:denyPurchase() self.deny = DENY_TIME end

function ShelfItem:markSold()
    self.sold = true
    if self.offer then self.offer.purchased = true end
    self.dustSeed = self.dustSeed or (self.slot * 17 + 3)
end

-- ---------------------------------------------------------------------------
-- POSE: o que define a aparência do objeto. Igual em repouso e em hover
-- (a trava de test_shop_scene compara as duas).
-- ---------------------------------------------------------------------------
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

-- Parâmetros de desenho do objeto EM PÉ em coordenadas da ARTE.
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

-- O que VOA na compra (imagem + origem + escala), ou nil (pacote abre tela).
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

-- ---------------------------------------------------------------------------
-- TEXTO NA DIAGONAL: tudo que é escrito sobre a mesa é cisalhado pelo mesmo
-- slope (as verticais da letra continuam verticais, como na pintura).
-- ---------------------------------------------------------------------------
local function withShear(x, y, slope, fn)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.shear(0, slope)
    fn()
    love.graphics.pop()
end
ShelfItem.withShear = withShear

-- Faixa (tinta ou pergaminho) cisalhada, com texto centralizado.
--   b = { x, y (topo à esquerda), w, h, slope }
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
        -- dois degraus (pixel art, sem gradiente contínuo)
        local half = floor(h / 2)
        love.graphics.setColor(top[1], top[2], top[3], a)
        love.graphics.rectangle("fill", 0, 0, w, half)
        love.graphics.setColor(bot[1], bot[2], bot[3], a)
        love.graphics.rectangle("fill", 0, half, w, h - half)
        Palette.set(paper and Palette.PARCHMENT_DARK or Palette.INK, 0.9 * a)
        love.graphics.rectangle("fill", 0, h - 1, w, 1)
        if paper then
            -- pontas enroladas (1 px mais escuro nas bordas)
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

-- ---------------------------------------------------------------------------
-- PIXEL ART NA GRADE DA CENA (v4): etiqueta, cordão, plaquinha e cavalete são
-- desenhados no canvas da ARTE (dentro de ShopPerspective.artPass) como
-- retângulos em DEGRAUS: a coluna x tem o topo em ShopLayout.lineY(y0, x),
-- a mesma fase das arestas pintadas (degraus de 8 px, todos iguais). O texto
-- sai depois, na grade da UI, cisalhado pela mesma inclinação.
-- ---------------------------------------------------------------------------
local function px(c, a, x, y, w, h)
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.rectangle("fill", x, y, w or 1, h or 1)
end
ShelfItem.px = px
local lineY = ShopLayout.lineY

-- Cordão de 1 px de arte (Bresenham) com sombra de tinta à direita.
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

-- Estilo da etiqueta: preço normal, sem ouro (tinta vermelha), oferta do dia.
local function tagStyle(afford, sale)
    if sale then return Palette.BLOOD, Palette.BLOOD_DARK, Palette.PARCHMENT_LIGHT end
    if afford then return Palette.PARCHMENT_LIGHT, Palette.PARCHMENT_DARK, Palette.INK end
    return Palette.PARCHMENT, Palette.PARCHMENT_DARK, Palette.BLOOD
end

-- Etiqueta (cartão + furo + cordão), px de ARTE. tg = ShopLayout.artTag;
-- dx = balanço/deslize (px de arte, inteiro), dy = levantar (px de arte);
-- tie = {x, y} de onde o cordão sai (nil = tg.cordX/cordY).
function ShelfItem.drawTagArt(tg, dx, dy, afford, sale, a, tie)
    local W, H = ShopLayout.TAG_W, ShopLayout.TAG_H
    local x0 = tg.x0 + dx
    local holeX = x0 + floor(W / 2)
    local holeY = lineY(tg.y0, holeX) - dy
    local cx, cy = tg.cordX + dx, tg.cordY - dy
    if tie then cx, cy = tie[1], tie[2] end
    ShelfItem.drawCordArt(cx, cy, holeX, holeY, a)
    local face, low = tagStyle(afford, sale)
    for x = x0, x0 + W - 1 do
        local top = lineY(tg.y0, x) - dy
        local edge = (x == x0 or x == x0 + W - 1)
        -- sombra curta no tampo (luz à esquerda: cai à direita/baixo)
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

-- Texto da etiqueta (grade da UI, cisalhado), por cima da arte.
function ShelfItem.drawTagText(L, tg, dx, dy, text, afford, sale, a, shakeX)
    local cv = L.cover
    local W, H = ShopLayout.TAG_W, ShopLayout.TAG_H
    local x0 = tg.x0 + dx
    local sx = cv.ox + (x0 + 1) * cv.s + (shakeX or 0)
    local sy = cv.oy + (lineY(tg.y0, x0 + 1) - dy + 1) * cv.s
    local w, h = (W - 2) * cv.s, (H - 3) * cv.s
    local font, fitted = TextFit.fit(text, 7, w - 1, 7)
    local _, _, ink = tagStyle(afford, sale)
    withShear(floor(sx), floor(sy), ShopLayout.K, function()
        love.graphics.setFont(font)
        Palette.set(ink, a)
        love.graphics.print(fitted, floor((w - font:getWidth(fitted)) / 2) + 1,
            floor((h - font:getHeight()) / 2) + 1)
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

-- balanço do pêndulo em px de arte (inteiro: a etiqueta anda na grade)
function ShelfItem.swingArt(angle)
    local s = ShopLayout.SWING
    return clamp(math.floor(math.sin(angle or 0) * 6 + 0.5), -s, s)
end

-- Rótulo de HOVER: faixa de pergaminho miúda, na diagonal, ancorada acima do
-- objeto. Nome/efeito; nada de texto parado em caixa embaixo dos objetos.
function ShelfItem.drawHoverName(text, cx, topY, slope, a, maxX, minX)
    if not text or text == "" or a <= 0.02 then return end
    local font = FontManager.getFont(9)
    local w = clamp(font:getWidth(text) + 12, 40, 220)
    local h = font:getHeight() + 7
    local x = cx - w / 2
    if maxX then x = math.min(x, maxX - w) end
    if minX then x = math.max(x, minX) end
    local y = topY - h - 4 - slope * (cx - x)   -- o centro da faixa fica sobre o objeto
    ShelfItem.drawBand({ x = x, y = y, w = w, h = h, slope = slope }, text, Palette.INK,
        { alpha = a, paper = true })
end

function ShelfItem:labelText()
    local offer = self.offer
    if self.kind == "relic" then return UpgradeTile.effectLabel(offer) or offer.name or "?" end
    if self.kind == "pack" then return offer.name or "?" end
    return nil
end

function ShelfItem:_shake()
    if self.deny > 0 and not reducedMotion() then
        local k = (DENY_TIME - self.deny) / DENY_TIME
        return math.sin(k * math.pi * 4) * 3 * (1 - k)
    end
    return 0
end

-- Placas no canvas da ARTE (chamado dentro do artPass): plaquinha de
-- raridade (carta), etiqueta + cordão (todas).
function ShelfItem:drawPlateArt(L, ctx)
    local g = self.geom
    if not g or self.sold then return end
    local cv = L.cover
    local alpha = (ctx.alpha or 1) * self:entered()
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    if self.kind == "card" and g.rarity and self.offer.rarity and ShelfItem.showsRarityPlate(self.offer.rarity) then
        ShelfItem.drawRarityPlateArt(g, self.offer.rarity, cv, sdx, alpha)
    end
    if not g.tag then return end
    local sale = self.offer and self.offer.saleDiscount and true or false
    local lift = (self.kind ~= "card") and floor(self:liftPx() / cv.s + 0.5) or 0
    local tie = nil
    if self.kind ~= "card" and self._tieArt then tie = { self._tieArt[1], self._tieArt[2] } end
    ShelfItem.drawTagArt(g.tag, sdx + ShelfItem.swingArt(self.tag.angle), lift,
        ctx.afford and self.deny <= 0, sale, alpha, tie)
end

-- Texto das placas (grade da UI, depois do artPass).
function ShelfItem:drawPlateText(L, ctx)
    local g = self.geom
    if not g or self.sold then return end
    local cv = L.cover
    local shake = self:_shake()
    local alpha = (ctx.alpha or 1) * self:entered()
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    if self.kind == "card" and g.rarity and self.offer.rarity and ShelfItem.showsRarityPlate(self.offer.rarity) then
        ShelfItem.drawRarityPlateText(g, self.offer.rarity, cv, sdx, alpha, shake)
    end
    if not g.tag then return end
    local sale = self.offer and self.offer.saleDiscount and true or false
    local lift = (self.kind ~= "card") and floor(self:liftPx() / cv.s + 0.5) or 0
    ShelfItem.drawTagText(L, g.tag, sdx + ShelfItem.swingArt(self.tag.angle), lift,
        "$" .. tostring(self.offer.cost or 0), ctx.afford and self.deny <= 0, sale, alpha, shake)
end

-- ---------------------------------------------------------------------------
-- PLAQUINHA DE RARIDADE (Loja "reta"): latão escuro pregado na frente do
-- trilho do cavalete, no MESMO frame da carta (shear(0, k) na origem da
-- borda). 4 tons de latão + contorno de tinta + 2 pregos; a raridade em
-- fonte pequena, na cor dela clareada até contraste >= 4,5:1 com o latão.
-- ---------------------------------------------------------------------------
ShelfItem.BRASS = {
    hi   = Palette.AGED_GOLD_LIGHT,
    rim  = Palette.AGED_GOLD,
    dark = Palette.AGED_GOLD_DARK,
    face = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.4),
}

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
function ShelfItem.rarityInk(rar)
    if inkCache[rar] then return inkCache[rar] end
    local c = Palette.forRarity(rar)
    local face = ShelfItem.BRASS.face
    for _ = 1, 40 do
        if ShelfItem.contrast(c, face) >= 4.6 then break end
        c = Palette.lighten(c, 0.08)
    end
    inkCache[rar] = c
    return c
end

function ShelfItem.showsRarityPlate(rar)
    if rar == "common" or rar == "basic" then return ShopLayout.PLATE_COMMON and true or false end
    return true
end

ShelfItem.PLATE_PAD = 3   -- px de ARTE de cada lado: contorno + prego + folga
function ShelfItem.rarityPlateFont(text, maxW, s)
    s = s or 2
    return TextFit.fit(text, 8, maxW - ShelfItem.PLATE_PAD * 2 * s, 7)
end

-- Geometria da plaquinha (px de ARTE) + fonte/texto. Pura: o teste mede.
function ShelfItem.rarityPlateArt(g, rar, cv)
    local R = g.rarity
    local text = I18n.t("rarity." .. rar, nil, rar)
    local font, fitted = ShelfItem.rarityPlateFont(text, R.maxW or R.w * cv.s, cv.s)
    local wArt = math.min(R.w, math.ceil(font:getWidth(fitted) / cv.s) + ShelfItem.PLATE_PAD * 2)
    local x0 = R.x0 + floor((R.w - wArt) / 2)
    return { x0 = x0, w = wArt, y0 = R.y0, h = R.h, font = font, text = fitted }
end

-- Caixa da plaquinha em px de TELA (x,y = canto de cima à esquerda).
function ShelfItem.rarityPlateBox(g, rar, cv)
    local P = ShelfItem.rarityPlateArt(g, rar, cv)
    local b = ShopLayout.stepBox(cv, P.x0, P.w, P.y0, P.h)
    b.slope, b.font, b.text = ShopLayout.K, P.font, P.text
    return b
end

-- Latão em 4 tons na grade: contorno de tinta, aresta de cima clara, face
-- escura, pé escuro, dois pregos.
function ShelfItem.drawRarityPlateArt(g, rar, cv, dx, alpha)
    local P = ShelfItem.rarityPlateArt(g, rar, cv)
    local B = ShelfItem.BRASS
    local a = alpha or 1
    local x0, x1 = P.x0 + (dx or 0), P.x0 + (dx or 0) + P.w - 1
    for x = x0, x1 do
        local top = lineY(P.y0, x)
        px(Palette.INK, 0.4 * a, x + 1, top + P.h, 1, 1)          -- sombra na face do degrau
        if x == x0 or x == x1 then
            px(Palette.INK, a, x, top, 1, P.h)
        else
            px(Palette.INK, a, x, top, 1, 1)
            px(B.hi, a, x, top + 1, 1, 1)
            px(B.face, a, x, top + 2, 1, P.h - 4)
            px(B.dark, a, x, top + P.h - 2, 1, 1)
            px(Palette.INK, a, x, top + P.h - 1, 1, 1)
        end
    end
    for _, x in ipairs({ x0 + 1, x1 - 1 }) do
        local mid = lineY(P.y0, x) + floor(P.h / 2)
        px(B.hi, a, x, mid, 1, 1)
    end
end

function ShelfItem.drawRarityPlateText(g, rar, cv, dx, alpha, shakeX)
    local P = ShelfItem.rarityPlateArt(g, rar, cv)
    local x0 = P.x0 + (dx or 0) + 2
    local sx = cv.ox + x0 * cv.s + (shakeX or 0)
    local sy = cv.oy + (lineY(P.y0, x0) + 2) * cv.s
    local w = (P.w - 4) * cv.s
    local h = (P.h - 4) * cv.s
    local a = alpha or 1
    withShear(floor(sx), floor(sy), ShopLayout.K, function()
        love.graphics.setFont(P.font)
        local tx = floor((w - P.font:getWidth(P.text)) / 2)
        local ty = floor((h - P.font:getHeight()) / 2) + 1
        Palette.set(Palette.INK, 0.9 * a)
        love.graphics.print(P.text, tx, ty + 1)
        local c = ShelfItem.rarityInk(rar)
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.print(P.text, tx, ty)
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Nome/efeito no hover (objetos da mesa). L = layout (limites).
function ShelfItem:drawHoverLabel(L, ctx)
    if self.kind == "card" or self.sold then return end
    local a = clamp(self.hover * 1.4 - 0.2, 0, 1) * (ctx.alpha or 1)
    if self.selected and self.hover < 0.05 then return end
    local r = self.rect
    local sx0 = self.slide.x or 0
    -- topo da silhueta DESENHADA (caixa da arte), não do slot
    local top = r.y - self:liftPx()
    local ab = self._artBox
    if ab and L.cover then top = L.cover.oy + (ab.y + 2) * L.cover.s end
    ShelfItem.drawHoverName(self:labelText(), self.geom.footX + sx0, top,
        self.geom.slope or 0, a, L.limitX, 8)
end

-- ---------------------------------------------------------------------------
-- CAVALETE da carta (v4, queixa do dono: "o suporte tem poucos pixels e faz
-- escadinha"). Pixel art própria na GRADE da cena, inclinação 1:8 na mesma
-- fase da aresta pintada do degrau (ShopLayout.lineY): degraus de 8 px todos
-- iguais. Trilho de madeira de RAIL_ART linhas (aresta clara de 1 px, dois
-- tons de face, pé escuro), contorno de tinta, dois batentes curtos nas
-- pontas segurando a carta, sombra de contato (dither) à direita no tampo do
-- degrau (a luz vem da esquerda). part "back" não desenha nada (a perna de
-- trás da v3 era uma diagonal livre: escadinha).
-- ---------------------------------------------------------------------------
function ShelfItem:drawStandArt(L, part, alpha)
    local g = self.geom
    if not (g and g.railX0) or part ~= "front" then return end
    local cv = L.cover
    local a = alpha or 1
    local sdx = floor((self.slide.x or 0) / cv.s + 0.5)
    local x0, x1 = g.railX0 + sdx, g.railX1 + sdx
    local E = ShopLayout.LINES.shelfEdge
    local R, P = ShopLayout.RAIL_ART, ShopLayout.POST_H
    local hov = reducedMotion() and 0 or self.hover
    -- sombra de contato no tampo do degrau, à direita do trilho
    for i = 1, 4 do
        local x = x1 + i
        local base = lineY(E, x)
        for y = base - R - 1, base - 1 do
            if ShopPerspective.dithered(x, y, 0.75 - i * 0.16) then
                px(Palette.INK, 0.8 * a, x, y, 1, 1)
            end
        end
    end
    local cardL, cardR = x0 + 3, x1 - 3
    for x = x0, x1 do
        local base = lineY(E, x)
        local top = base - R
        if x == x0 or x == x1 then
            px(Palette.INK, a, x, top - 1, 1, R + 1)
        else
            px(Palette.INK, a, x, top - 1, 1, 1)
            -- carta levantada: a sombra dela cai no topo do trilho
            -- trilho ESCURO (destaca do tampo claro do degrau): aresta de
            -- cima clara de 1 px, face em dois tons, pé de tinta
            local shaded = hov > 0.3 and x >= cardL and x <= cardR
            px(shaded and WOOD.mid or WOOD.hi, a, x, top, 1, 1)
            px(WOOD.mid, a, x, top + 1, 1, 1)
            px(WOOD.dark, a, x, top + 2, 1, R - 3)
            px(WOOD.deep, a, x, base - 1, 1, 1)
        end
    end
    -- batentes nas pontas (2 colunas fora da carta), em pé sobre o trilho
    for _, bx in ipairs({ x0 + 1, x1 - 2 }) do
        for x = bx, bx + 1 do
            local top = lineY(E, x) - R - P
            px(Palette.INK, a, x, top - 1, 1, 1)
            px((x == bx) and WOOD.lite or WOOD.mid, a, x, top, 1, P)
        end
        px(Palette.INK, a, bx - 1, lineY(E, bx - 1) - R - P, 1, P)
        px(Palette.INK, a, bx + 2, lineY(E, bx + 2) - R - P, 1, P)
    end
end

-- ---------------------------------------------------------------------------
-- CARTA no cavalete (px de tela, homografia)
-- ---------------------------------------------------------------------------
function ShelfItem:drawCard(ctx)
    if self.sold then return end
    local inst = self.card
    if not (inst and inst.image) then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local img = inst.image
    if (self.hover > 0.5 or self.selected) then
        local okCF, CardFrame = pcall(require, "src.ui.CardFrame")
        if okCF and CardFrame.liveImage then img = CardFrame.liveImage(inst) or img end
    end
    local x0, y0, x1, y1, x2, y2, x3, y3 = self:cardCorners()
    local dim = ctx.afford and 1 or 0.6
    local a = alpha * (1 - clamp(inst.dissolve or 0, 0, 1))
    -- sombra da carta na parede/estante atrás (deslocada pra direita: vela à
    -- esquerda); levantada, a carta se afasta da parede e a sombra abre
    local e = reducedMotion() and 0 or self.hover
    -- a sombra acompanha o tilt (canto apertado -> sombra pro lado oposto,
    -- como Card:draw com SHADOW_PRESS_SHIFT)
    local T = self.tilt or { x = 0, y = 0 }
    local sdx = 5 + 3 * e - T.x * 6 * e
    local sdy = 4 + 3 * e - T.y * 4 * e
    love.graphics.setColor(0, 0, 0, (0.32 - 0.08 * e) * a)
    love.graphics.polygon("fill", x0 + sdx, y0 + sdy, x1 + sdx, y1 + sdy, x2 + sdx, y2 + sdy - 2, x3 + sdx, y3 + sdy - 2)
    local CardMesh = require("src.ui.CardMesh")
    local shader = CardMesh.getShader()
    local glowK = math.max(self.hover * 0.8, self.selected and 0.9 or 0)
    if shader then
        local iw, ih = img:getWidth(), img:getHeight()
        local mesh = CardMesh.getMesh(iw, ih)
        mesh:setTexture(img)
        love.graphics.setShader(shader)
        -- tilt do hover POR CIMA da pose (o press do shader roda no espaço da
        -- carta, antes da homografia do quadrilátero)
        local T = self.tilt or { x = 0, y = 0 }
        local hv = reducedMotion() and 0 or self.hover
        CardMesh.setUniforms(shader, { T.x, T.y }, hv, ctx.t or 0, img)
        if glowK > 0.01 then
            local gc = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(gc[1], gc[2], gc[3], glowK * a * 0.7)
            for _, d in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
                local r0, r1, r2 = ShopPerspective.homography(x0 + d[1], y0 + d[2], x1 + d[1], y1 + d[2],
                    x2 + d[1], y2 + d[2], x3 + d[1], y3 + d[2])
                CardMesh.setQuad(shader, r0, r1, r2)
                love.graphics.draw(mesh, 0, 0)
            end
        end
        local r0, r1, r2 = ShopPerspective.homography(x0, y0, x1, y1, x2, y2, x3, y3)
        CardMesh.setQuad(shader, r0, r1, r2)
        love.graphics.setColor(dim, dim, dim, a)
        love.graphics.draw(mesh, 0, 0)
        shader:send("quadOn", 0)
        love.graphics.setShader()
    else
        -- sem shader: cisalhamento afim (mesma diagonal, sem o escorço da direita)
        local s = (y3 - y0) / img:getHeight()
        withShear(x0, y0, (y1 - y0) / math.max(1, x1 - x0), function()
            love.graphics.setColor(dim, dim, dim, a)
            love.graphics.draw(img, 0, 0, 0, (x1 - x0) / img:getWidth(), s)
        end)
    end
    if inst.isNewDiscovery then
        local okDM, DM = pcall(require, "src.ui.DiscoveryMark")
        if okDM and DM.drawBadge then
            local iw = img:getWidth()
            local sc = (x1 - x0) / iw
            withShear(x0, y0, (y1 - y0) / math.max(1, x1 - x0), function()
                love.graphics.scale(sc, sc)
                pcall(DM.drawBadge, 0, 0, iw, DM.reveal(inst.id), a)
            end)
        end
    end
    local minX, maxX = math.min(x0, x3), math.max(x1, x2)
    local minY, maxY = math.min(y0, y1), math.max(y2, y3)
    self._drawRect = { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
    inst._drawRect = self._drawRect
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- OBJETO da mesa (no canvas da ARTE): sombra de contato + sprite em pé.
-- ---------------------------------------------------------------------------
function ShelfItem:drawObjectArt(L, ctx)
    if self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local o = self:uprightParams(L, self.hover > 0.5 or self.selected, ctx.t or 0)
    if not o then return end
    o.alpha = alpha
    local dim = ctx.afford and 1 or 0.6
    o.color = { dim, dim, dim }
    local sale = self.offer and self.offer.saleDiscount
    o.outline = math.max(self.hover, self.selected and 1 or 0, sale and 0.7 or 0)
    o.outlineColor = (self.selected and Palette.AGED_GOLD_LIGHT)
        or (sale and Palette.lerp(Palette.AGED_GOLD_LIGHT, Palette.ORANGE, 0.5))
        or Palette.PARCHMENT_LIGHT
    ShopPerspective.drawContactShadow(o, L.art.tableMask, alpha)
    ShopPerspective.drawUpright(o)
    self._artBox = ShopPerspective.uprightBox(o)
    local tx, ty = ShopPerspective.tiePoint(o, 0.32)
    self._tieArt = { floor(tx), floor(ty) }
    self._tie = { L.cover.ox + tx * L.cover.s, L.cover.oy + ty * L.cover.s }
end

-- Marca de poeira no lugar do objeto (arte, na diagonal) — o "VENDIDO" a giz
-- vem depois, na grade da UI (drawSoldText).
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
    local baseY = (self.kind == "card") and (g.foot - g.qh * 0.45) or (g.foot - r.h * 0.35)
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

-- Arte do objeto no PERGAMINHO: o MESMO sprite (mesma animação, mesmo
-- espelho), frontal (sem o cisalhamento da mesa), escala inteira.
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
