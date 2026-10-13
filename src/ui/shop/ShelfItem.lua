-- src/ui/shop/ShelfItem.lua
-- Um OBJETO na prateleira do Balcão do Mercador (Loja v3): a oferta do
-- ShopSystem + o retângulo que o ShopLayout lhe deu + a tábua onde apoia +
-- o estado de interação (hover, etiqueta balançando, vendido, poeira).
--
-- Três espécies, uma classe:
--   card   → a Card de sempre (tilt 3D no hover), em pé num suporte de madeira
--   relic  → a arte do UpgradeTile (halo + sombra de contato + sprite) SEM a placa
--   pack   → o sleeve do PackSleeve, PENDURADO num gancho sob a tábua de cima
--
-- Regras do plano (docs/plan/shop-v3-balcao.md §4):
--   repouso  = apoiado, sombra curta no pé, etiqueta pendurada por um barbante
--   hover    = levanta 4..6 px (juice do Moveable), etiqueta balança (pêndulo
--              amortecido ~0,6 s)
--   compra   = etiqueta arrancada (cai e some) + marca de poeira + VENDIDO a giz
--   sem ouro = etiqueta treme em vermelho 2x
--   reducedMotion remove o MOVIMENTO (levantar, balançar, tremer, cair); o
--   preço, o VENDIDO e o destaque de hover continuam (ui_layout_invariants §3).
--
-- Nada de economia aqui: quem decide se pode comprar é a tela; o item só
-- recebe `ctx.afford` pra pintar a etiqueta.

local ShelfItem = {}
ShelfItem.__index = ShelfItem

local Palette     = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local TextFit     = require("src.ui.TextFit")
local ImageCache  = require("src.ui.ImageCache")
local Moveable    = require("engine.Moveable")
local UpgradeTile = require("src.ui.UpgradeTile")
local I18n        = require("src.i18n.I18n")
local Config      = require("src.core.Config")

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Pêndulo da etiqueta: frequência ~1,25 Hz, amortecido em ~0,6 s.
local TAG_OMEGA2 = 62      -- (rad/s)^2
local TAG_DAMP   = 5.5
local DENY_TIME  = 0.45    -- dois tremores vermelhos

-- Assets miúdos (compartilhados por todos os itens). Carregados uma vez;
-- faltar arquivo AVISA e cai no desenho procedural (nunca mudo).
local ART = {}
local artWarned = {}
local function art(name)
    if ART[name] ~= nil then return ART[name] or nil end
    local img = ImageCache.tryGet("assets/sprites/shop/" .. name .. ".png")
    if not img then
        ART[name] = false
        if not artWarned[name] then
            artWarned[name] = true
            print("[ShelfItem] assets/sprites/shop/" .. name .. ".png ausente — desenho procedural")
        end
        return nil
    end
    ART[name] = img
    return img
end
ShelfItem.art = art
ShelfItem._frontQuads = setmetatable({}, { __mode = "k" })

-- Quem desenha a carta precisa do mesmo contrato da mão: Card:draw soma por
-- dentro BASE_LIFT (flutua 3 px) e uma ondulação de ±3 px em repouso. Um
-- objeto APOIADO não flutua — compensamos os dois pra o pé ficar no suporte.
local function cardInnerOffset(inst)
    local baseFloat = Config.Cards.BASE_LIFT or 0
    local ambientY = 0
    if not inst.isHovered and not inst.isDragging then
        ambientY = math.sin(love.timer.getTime() * 0.666 + (inst._ambientSeed or 0)) * 3
    end
    return ambientY - baseFloat
end

function ShelfItem.new(kind, offer, slot)
    local self = setmetatable({}, ShelfItem)
    self.kind = kind
    self.offer = offer
    self.slot = slot
    self.hover = 0          -- 0..1 interpolado
    self.hot = false        -- borda de entrada do hover
    -- Escala de entrada (0 = ainda não pousou). TABELA, não número: a tela
    -- reconstrói os itens no primeiro update (detector de resize) e a cada
    -- compra; o ease do EventManager precisa continuar apontando pro mesmo
    -- estado, senão anima um órfão e o objeto novo nunca aparece.
    self.entry = { v = 1 }
    self.sold = offer and offer.purchased or false
    self.tag = { angle = 0, vel = 0, deny = 0, torn = nil }
    Moveable.initJuice(self)
    return self
end

-- Estado de animação que sobrevive a um rebuild (resize/compra recriam os
-- itens a partir das ofertas; o balanço da etiqueta e a etiqueta caindo não
-- podem reiniciar por isso).
function ShelfItem:exportFx()
    return { hover = self.hover, hot = self.hot, tag = self.tag, juice = self.juice,
             entry = self.entry, dustSeed = self.dustSeed }
end

function ShelfItem:importFx(fx)
    if not fx then return end
    self.hover, self.hot, self.tag, self.juice = fx.hover, fx.hot, fx.tag, fx.juice
    self.entry = fx.entry or self.entry
    self.dustSeed = fx.dustSeed
end

-- ============================================================================
-- GEOMETRIA (vinda do ShopLayout; recalculada no resize)
-- ============================================================================
function ShelfItem:setGeometry(g)
    self.geom = g
    self.rect = g.rect
    self.foot = g.foot
    if self.card then self:_placeCard() end
end

-- A Card ocupa o retângulo inteiro do layout (o ShopLayout já respeita a
-- proporção 96x144). Âncora IMUTÁVEL em homeX/homeY: Card:draw grava x/y a
-- cada frame e partir deles acumularia offset (bug histórico da loja).
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

-- Hit-test no retângulo de REPOUSO (a puladinha do hover nunca tira o objeto
-- de baixo do mouse). O pacote pendurado usa o retângulo do sleeve.
function ShelfItem:hit(mx, my)
    local r = self.rect
    if not r or self.sold then return false end
    return mx >= r.x and mx <= r.x + r.w and my >= r.y - (self.geom.lift or 0) and my <= r.y + r.h
end

function ShelfItem:center()
    local r = self.rect
    return r.x + r.w / 2, r.y + r.h / 2
end

-- 0..1: quanto o objeto já pousou na prateleira.
function ShelfItem:entered()
    return clamp(self.entry.v or 1, 0, 1)
end

-- ============================================================================
-- UPDATE
-- ============================================================================
-- hovered: decidido pela cena (mouse, foco do NavCursor). Devolve true na
-- BORDA de entrada (a cena toca o som e avisa a lanterna).
function ShelfItem:update(dt, hovered)
    local reduced = reducedMotion()
    local target = (hovered and not self.sold) and 1 or 0
    local entered = false
    if target == 1 and not self.hot then
        self.hot = true
        entered = true
        if not reduced then
            Moveable.juice_up(self, 0.08, 0.02)
            -- impulso no barbante: a etiqueta balança quando o objeto sobe
            self.tag.vel = self.tag.vel + 2.6
        end
    elseif target == 0 then
        self.hot = false
    end
    if reduced then
        self.hover = target
    else
        self.hover = self.hover + (target - self.hover) * math.min(1, dt * 12)
    end
    Moveable.updateJuice(self, dt)

    -- pêndulo amortecido da etiqueta
    local tg = self.tag
    ShelfItem.stepPendulum(tg, dt)
    if tg.deny > 0 then tg.deny = math.max(0, tg.deny - dt) end
    if tg.torn then
        local t = tg.torn
        t.vy = t.vy + 520 * dt
        t.y = t.y + t.vy * dt
        t.x = t.x + t.vx * dt
        t.rot = t.rot + t.vrot * dt
        t.alpha = t.alpha - dt * 1.6
        if t.alpha <= 0 then tg.torn = nil end
    end
    return entered
end

-- Quanto o objeto está LEVANTADO neste frame (px, positivo = pra cima).
function ShelfItem:liftPx()
    if reducedMotion() then return 0 end
    local maxLift = clamp((self.geom and self.geom.lift or 6) * 0.42, 4, 6)
    return self.hover * maxLift - Moveable.hopOffset(self)
end

-- Sem ouro: a etiqueta treme em vermelho (2 tremores) — nada de toast.
function ShelfItem:deny()
    self.tag.deny = DENY_TIME
end

-- Compra: a etiqueta é arrancada e cai; o objeto deixa a marca de poeira.
function ShelfItem:markSold()
    self.sold = true
    if self.offer then self.offer.purchased = true end
    self.dustSeed = self.dustSeed or (self.slot * 17 + 3)
    local tg = self.tag
    if not reducedMotion() and self.geom then
        local ax, ay, len = self:_tagAnchor()
        tg.torn = { x = ax, y = ay + len, vx = 18, vy = -90, rot = tg.angle, vrot = 2.2, alpha = 1 }
    end
    tg.angle, tg.vel = 0, 0
end

-- Devolve o objeto que VOA pro destino (imagem + origem + escala), pra cena
-- animar fora do slide. nil quando não há o que voar (pacote abre a tela).
function ShelfItem:flyPayload()
    local r = self.rect
    if self.kind == "card" and self.card and self.card.image then
        local inst = self.card
        return { img = inst.image, x = inst.homeX, y = inst.homeY,
                 scale = inst.baseScale or 1, ox = 0, oy = 0 }
    elseif self.kind == "relic" then
        local sprite = UpgradeTile.spriteFor(self.offer.id, false, 0)
        if not sprite then return nil end
        local sw, sh = sprite:getWidth(), sprite:getHeight()
        local s = math.min((r.w - 6) / sw, (r.h - 6) / sh)
        s = s >= 1 and math.floor(s * 4) / 4 or s
        return { img = sprite, x = r.x + r.w / 2, y = self.foot - sh * s / 2,
                 scale = s, ox = sw / 2, oy = sh / 2 }
    end
    return nil
end

-- ============================================================================
-- DRAW
-- ============================================================================
-- A etiqueta pendura do BEIRAL da tábua (não do objeto): o objeto levanta
-- no hover e ela fica, balançando com o impulso.
function ShelfItem:_tagAnchor()
    local g = self.geom.tag
    return g.ax, g.ay, g.len
end

-- Suporte de madeira da carta (parte de trás = atrás da carta; o lábio da
-- frente cobre o pé). `front` escolhe qual metade desenhar.
function ShelfItem:drawStand(front, alpha)
    local st = self.geom and self.geom.stand
    if not st then return end
    local img = art("card_stand_" .. tostring(self.geom.standVariant or 1))
    love.graphics.setColor(1, 1, 1, alpha or 1)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx, sy = st.w / iw, st.h / ih
        if front then
            -- o LÁBIO da frente (60% de baixo da arte) cobre a base da carta:
            -- é ele que diz "apoiada", não flutuando
            local q = ShelfItem._frontQuads[img]
            if not q then
                q = love.graphics.newQuad(0, ih * 0.4, iw, ih * 0.6, iw, ih)
                ShelfItem._frontQuads[img] = q
            end
            love.graphics.draw(img, q, st.x, st.y + st.h * 0.4, 0, sx, sy)
        else
            love.graphics.draw(img, st.x, st.y, 0, sx, sy)
        end
    else
        local wood = Palette.lerp(Palette.RUST, Palette.INK, 0.5)
        if front then
            Palette.set(wood, alpha)
            love.graphics.rectangle("fill", st.x, st.y + st.h * 0.4, st.w, st.h * 0.6)
        else
            Palette.set(Palette.INK, alpha)
            love.graphics.rectangle("fill", st.x - 1, st.y - 1, st.w + 2, st.h + 2)
            Palette.set(wood, alpha)
            love.graphics.rectangle("fill", st.x, st.y, st.w, st.h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ctx = { t, afford = bool, alpha = 0..1, hoverK = 0..1 (cena), reduced }
function ShelfItem:drawObject(ctx)
    if self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local r = self.rect
    local lift = self:liftPx()
    local s = Moveable.scaleFactor(self) * Moveable.swellFactor(self)
        * (0.6 + 0.4 * self:entered())
    local cx = r.x + r.w / 2

    if self.kind == "card" then
        local inst = self.card
        if not (inst and inst.image) then return end
        inst.saleDim = not ctx.afford
        local extra = cardInnerOffset(inst)
        local iw, ih = inst.image:getWidth(), inst.image:getHeight()
        local baseS = inst.baseScale or 1
        local cs = (inst.currentScale or baseS) * s
        local w, h = iw * cs, ih * cs
        -- âncora centro-X + PÉ: crescer só empurra o topo pra cima
        local x = inst.homeX + (iw * baseS - w) / 2
        local y = self.foot - h - lift - extra
        if alpha < 0.999 then love.graphics.setColor(1, 1, 1, alpha) end
        local prevScale = inst.currentScale
        inst.currentScale = cs
        inst:draw(x, y, false, true)
        inst.currentScale = prevScale
        self._drawRect = { x = x + (inst.offsetHoverX or 0), y = self.foot - h - lift, w = w, h = h }
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    if self.kind == "relic" then
        -- MESMA composição do UpgradeTile.drawArt (halo + sombra + sprite),
        -- com o chão no pé da tábua: restY = rect.y + rect.h - 3.
        local h = r.h * s
        UpgradeTile.drawArt(self.offer, { x = cx - r.w * s / 2, y = self.foot + 3 - h, w = r.w * s, h = h }, {
            alpha = alpha * (ctx.afford and 1 or 0.55),
            glow = 0.3 + 0.7 * self.hover,
            bob = lift, time = ctx.t, animate = true,
        })
        self._drawRect = { x = r.x, y = r.y - lift, w = r.w, h = r.h }
        return
    end

    if self.kind == "pack" then
        local okPS, PackSleeve = pcall(require, "src.ui.PackSleeve")
        if not okPS or not PackSleeve then return end
        local sw, sh = PackSleeve.getDimensions()
        if not sw or sw <= 0 then return end
        local scale = math.min(r.w / sw, r.h / sh) * s
        -- pendurado: balança no gancho junto com a etiqueta (ângulo menor)
        local rot = reducedMotion() and 0 or self.tag.angle * 0.35
        local cy = r.y + r.h / 2
        PackSleeve.drawAt(self.offer.id, self.offer.kind, math.floor(cx), math.floor(cy), scale,
            alpha * (ctx.afford and 1 or 0.6),
            { hover = self.hover, rotation = rot, key = "shelf_pack_" .. tostring(self.slot) })
        self._drawRect = { x = r.x, y = r.y, w = r.w, h = r.h }
        return
    end
end

-- Uma etiqueta pendurada (barbante de 1 px + cartão + texto) desenhada em
-- (x0, y0) = ponto onde o barbante prende, girada `rot`. Compartilhada pelo
-- balcão (sino "$4", livro "+$3"): a MESMA etiqueta das prateleiras.
--   g    = { len, w, h }
--   opts = { afford = bool, denyK = 0..1, sale = bool, basePrice = n, text = "$N" }
local function drawTagCard(g, x0, y0, rot, a, opts)
    opts = opts or {}
    local afford = opts.afford ~= false
    local denyK = opts.denyK or 0
    love.graphics.push()
    love.graphics.translate(x0, y0)
    love.graphics.rotate(rot)
    -- barbante
    Palette.set(Palette.PARCHMENT_DARK, a)
    love.graphics.rectangle("fill", 0, 0, 1, g.len)
    -- cartão (oferta do dia: a etiqueta vermelha torta da loja-vida, F4)
    local sale = opts.sale
    local img = art("price_tag")
    local tx, ty = -math.floor(g.w / 2), g.len
    local saleDrawn = false
    if sale then
        local okP, ShopProps = pcall(require, "src.ui.shop.ShopProps")
        if okP and ShopProps and ShopProps.saleTag and ShopProps.saleTag.draw then
            love.graphics.push()
            love.graphics.translate(0, ty)
            love.graphics.rotate(-0.1)
            love.graphics.translate(0, -ty)
            local tint = afford and 1 or 0.75
            love.graphics.setColor(tint, tint, tint, a)
            ShopProps.saleTag.draw(tx, ty, g.w / (ShopProps.saleTag.W or 24))
            saleDrawn = true
        end
    end
    if saleDrawn then
        -- (o pop vem depois do preço, que roda junto com a etiqueta torta)
    elseif img then
        local tint = afford and 1 or 0.75
        love.graphics.setColor(tint, tint * (denyK > 0 and 0.55 or 1), tint * (denyK > 0 and 0.55 or 1), a)
        love.graphics.draw(img, tx, ty, 0, g.w / img:getWidth(), g.h / img:getHeight())
    else
        Palette.set(Palette.INK, a)
        love.graphics.rectangle("fill", tx - 1, ty - 1, g.w + 2, g.h + 2)
        Palette.set(afford and Palette.PARCHMENT_LIGHT or Palette.PARCHMENT, a)
        love.graphics.rectangle("fill", tx, ty, g.w, g.h)
    end
    -- texto
    local txt = opts.text or ""
    local font, fitted = TextFit.fit(txt, clamp(math.floor(g.h * 0.55), 8, 14), g.w - 4, 7)
    love.graphics.setFont(font)
    local col = (afford and denyK <= 0) and Palette.INK or Palette.BLOOD
    if saleDrawn and afford and denyK <= 0 then col = Palette.PARCHMENT_LIGHT end
    Palette.set(col, a)
    love.graphics.print(fitted, tx + math.floor((g.w - font:getWidth(fitted)) / 2),
        ty + math.floor((g.h - font:getHeight()) / 2) + 1)
    -- preço cheio riscado, miúdo, no canto de cima (só quando cabe)
    if sale and opts.basePrice and g.h >= 20 then
        local small = FontManager.getFont(7)
        local base = "$" .. tostring(opts.basePrice)
        love.graphics.setFont(small)
        local bw = small:getWidth(base)
        local bx, by = tx + g.w - bw - 2, ty + 1
        Palette.set(Palette.INK, a * 0.8)
        love.graphics.print(base, bx, by)
        love.graphics.rectangle("fill", bx - 1, by + math.floor(small:getHeight() / 2), bw + 2, 1)
    end
    if saleDrawn then love.graphics.pop() end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end
ShelfItem.drawTagCard = drawTagCard

-- Pêndulo amortecido de uma etiqueta (estado em `tg` = { angle, vel }).
function ShelfItem.stepPendulum(tg, dt)
    if reducedMotion() then tg.angle, tg.vel = 0, 0 return end
    local h = math.min(dt, 1 / 30)
    local acc = -TAG_OMEGA2 * math.sin(tg.angle) - TAG_DAMP * tg.vel
    tg.vel = tg.vel + acc * h
    tg.angle = tg.angle + tg.vel * h
    if math.abs(tg.angle) < 0.002 and math.abs(tg.vel) < 0.02 then tg.angle, tg.vel = 0, 0 end
end

-- Etiqueta pendurada: barbante de 1 px + cartão + preço. Treme vermelha no
-- deny; some (e cai) depois da compra.
function ShelfItem:drawTag(ctx)
    local g = self.geom and self.geom.tag
    if not g then return end
    local tg = self.tag
    local alpha = (ctx.alpha or 1) * self:entered()
    local opts = { afford = ctx.afford, sale = self.offer and self.offer.saleDiscount,
                   basePrice = self.offer and self.offer.basePrice,
                   text = "$" .. tostring(self.offer and self.offer.cost or 0) }
    local function drawCard(x0, y0, rot, a, denyK)
        opts.denyK = denyK
        drawTagCard(g, x0, y0, rot, a, opts)
    end

    if tg.torn then
        local t = tg.torn
        drawCard(t.x, t.y - g.len, t.rot, clamp(t.alpha, 0, 1) * alpha, 0)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    if self.sold then return end

    local ax, ay = self:_tagAnchor()
    local rot = tg.angle
    local denyK = tg.deny > 0 and (tg.deny / DENY_TIME) or 0
    if denyK > 0 and not reducedMotion() then
        -- dois tremores: seno de 2 períodos no tempo do deny
        local k = (DENY_TIME - tg.deny) / DENY_TIME
        ax = ax + math.sin(k * math.pi * 4) * 3 * (1 - k)
    end
    drawCard(ax, ay, rot, alpha, denyK)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Rótulo ANCORADO no objeto, na banda sob a tábua, à esquerda da etiqueta:
-- carta = raridade (+ AFINIDADE); relíquia = efeito curto do UpgradeTile
-- ("+1 SLOT"); pacote = nome. Sem isso o jogador não sabe o que é o livro
-- de $22 sem passar o mouse.
function ShelfItem:drawLabel(ctx)
    local lb = self.geom and self.geom.label
    if not lb or self.sold then return end
    local alpha = (ctx.alpha or 1) * self:entered()
    if alpha <= 0.01 then return end
    local offer = self.offer
    if self.kind == "card" then
        local size = clamp(math.floor(lb.h * 0.32), 7, 9)
        local y = lb.y
        if offer.rarity then
            local TextCase = require("src.i18n.TextCase")
            local txt = TextCase.upper(I18n.t("rarity." .. offer.rarity, nil, offer.rarity))
            local font, fitted = TextFit.fit(txt, size, lb.w)
            love.graphics.setFont(font)
            local c = Palette.forRarity(offer.rarity)
            FontManager.drawWithOutline(fitted, lb.x, y, { c[1], c[2], c[3], alpha }, 0.85 * alpha)
            y = y + font:getHeight() + 3
        end
        if offer.affinity then
            local txt = I18n.t("reward.affinity_badge")
            local font, fitted = TextFit.fit(txt, size - 1, lb.w)
            love.graphics.setFont(font)
            local c = Palette.AGED_GOLD_LIGHT
            FontManager.drawWithOutline(fitted, lb.x, y, { c[1], c[2], c[3], alpha }, 0.85 * alpha)
        end
    elseif self.kind == "relic" then
        local txt = UpgradeTile.effectLabel(offer) or offer.name or "?"
        local h = math.min(15, lb.h)
        local ShopEngraving = require("src.ui.ShopEngraving")
        local th = UpgradeTile.theme(offer)
        -- placa gravada quando o texto cabe inteiro (a placa reserva 26px
        -- pras pontas); senão texto contornado em até duas linhas — nunca
        -- "+1 ..." truncado
        local _, fitted = TextFit.fit(txt, 8, lb.w - 26)
        if fitted == txt then
            love.graphics.setColor(1, 1, 1, alpha)
            ShopEngraving.effectStrip(lb.x, lb.y + math.floor((lb.h - h) / 2), lb.w, h, txt,
                { accent = th.accent, alpha = alpha, seed = ShopEngraving.seedOf(offer.id) })
        else
            ShelfItem.drawWrapped(txt, lb, th.text or Palette.PARCHMENT_LIGHT, alpha)
        end
    else
        ShelfItem.drawWrapped(offer.name or "?", lb, Palette.PARCHMENT_LIGHT, alpha)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Texto contornado em até DUAS linhas dentro do rect (quebra em espaço; o
-- que não couber na segunda linha é elidido). Fonte 7..9 pela altura.
function ShelfItem.drawWrapped(txt, lb, color, alpha)
    local size = clamp(math.floor(lb.h * 0.3), 7, 9)
    local font = FontManager.getFont(size)
    local lines = {}
    if font:getWidth(txt) <= lb.w then
        lines[1] = txt
    else
        local cur = ""
        for word in tostring(txt):gmatch("%S+") do
            local try = (cur == "") and word or (cur .. " " .. word)
            if font:getWidth(try) <= lb.w or cur == "" then
                cur = try
            else
                lines[#lines + 1] = cur
                cur = word
                if #lines == 1 then break end
            end
        end
        -- resto (inclusive o que sobrou depois da quebra) vai pra última linha
        local rest = tostring(txt):sub(#table.concat(lines, " ") + 1):gsub("^%s+", "")
        if #lines == 0 then rest = txt end
        if rest ~= "" then
            local _, fitted = TextFit.fit(rest, size, lb.w, size)
            lines[#lines + 1] = fitted
        end
    end
    local lh = font:getHeight() + 2
    local y0 = lb.y + math.floor((lb.h - #lines * lh) / 2)
    love.graphics.setFont(font)
    for i, l in ipairs(lines) do
        FontManager.drawWithOutline(l, lb.x, y0 + (i - 1) * lh,
            { color[1], color[2], color[3], alpha }, 0.85 * alpha)
    end
end

-- Marca de poeira no lugar do objeto + "VENDIDO" a giz (i18n reward.sold).
function ShelfItem:drawDust(ctx)
    if not self.sold then return end
    local r = self.rect
    local alpha = ctx.alpha or 1
    local img = art("dust_mark")
    local cx = r.x + r.w / 2
    local footY = self.geom.hanging and (r.y + r.h) or self.foot
    local dw = r.w * 0.9
    local dh = math.max(10, r.h * 0.22)
    if img then
        love.graphics.setColor(1, 1, 1, 0.75 * alpha)
        love.graphics.draw(img, cx - dw / 2, footY - dh * 0.8, 0, dw / img:getWidth(), dh / img:getHeight())
    else
        Palette.set(Palette.PARCHMENT_DARK, 0.35 * alpha)
        love.graphics.ellipse("fill", cx, footY - 2, dw * 0.45, dh * 0.3)
    end
    -- giz: texto claro, levemente torto, sem caixa
    local txt = I18n.t("reward.sold")
    local font, fitted = TextFit.fit(txt, clamp(math.floor(r.w * 0.13), 9, 16), r.w - 8)
    love.graphics.setFont(font)
    love.graphics.push()
    love.graphics.translate(cx, r.y + r.h * 0.55)
    love.graphics.rotate(-0.18)
    local tw, th = font:getWidth(fitted), font:getHeight()
    Palette.set(Palette.INK, 0.6 * alpha)
    love.graphics.print(fitted, -tw / 2 + 1, -th / 2 + 1)
    Palette.set(Palette.PARCHMENT_LIGHT, 0.85 * alpha)
    love.graphics.print(fitted, -tw / 2, -th / 2)
    -- risco de giz sob a palavra
    love.graphics.rectangle("fill", -tw / 2 - 2, th / 2 + 1, tw + 4, 1)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return ShelfItem
