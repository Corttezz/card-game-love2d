-- src/ui/shop/ShopScene.lua
-- O BALCÃO DO MERCADOR (Loja v3, docs/plan/shop-v3-balcao.md): a CENA da loja.
--
-- Camadas, do fundo pra frente:
--   parede de madeira escura (véu) → luz âmbar da lanterna (cone em degraus,
--   que "olha" pro objeto em hover) → vida de fundo (ShopProps: teia, poeira)
--   → placa com o título e o "?" das regras → ESTANTE DE CIMA (tábua + cartas
--   em pé nos suportes + etiquetas) → PRATELEIRA DE BAIXO (tábua + relíquias
--   apoiadas + pacote no gancho + etiquetas) → marcas de poeira dos vendidos
--   → BALCÃO (tampo + sino + copo de dados + livro-razão + rótulos a giz) →
--   lanterna → PERGAMINHO de inspeção (prego + rolo + CardDetailPanel) →
--   vida de frente (mariposa). Os objetos que VOAM na compra são desenhados
--   pela tela fora do slide (drawFlies), por cima da TopBar.
--
-- O que NÃO mora aqui: regra de economia (quem pode comprar, quanto custa o
-- sino, o que a compra faz) — isso é da CardRewardScreen/ShopSystem. A cena
-- recebe ofertas e avisos (onPurchased/onDenied/reroll) e só ANIMA.
--
-- Geometria: tudo vem de ShopLayout.layout() (puro, validado por
-- test_shop_layout). Recalculada em layout() — chamada no show e no resize.
--
-- Teclado/pad: cada objeto é NavCursor.target (a carta se registra sozinha
-- no Card:draw; relíquia/pacote aqui; sino/dados/livro pelos botões
-- invisíveis da tela, que moram nos retângulos do balcão). Ação principal
-- (Y) = livro-razão; X = sino.
--
-- Vida ambiente (lanterna com chama, copo de dados, mariposa, teia) é da
-- frente loja-vida: `src/ui/shop/ShopProps.lua`, chamado quando existe.
-- Sem ele, lanterna e copo são placeholders simples (e um aviso no boot).

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
local TextFit      = require("src.ui.TextFit")

local FLYQ    = "shop_fly"
local REROLLQ = "shop_reroll"

-- Quads cacheados por chave (newQuad por frame é alocação à toa).
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

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Assets grandes da cena (tábuas, balcão, sino, livro, pergaminho, prego,
-- gancho). Arquivo ausente AVISA uma vez e o desenho cai no procedural.
local artWarned = {}
local function art(name)
    local img = ImageCache.tryGet("assets/sprites/shop/" .. name .. ".png")
    if not img and not artWarned[name] then
        artWarned[name] = true
        print("[ShopScene] assets/sprites/shop/" .. name .. ".png ausente — desenho procedural")
    end
    return img
end

-- Vida ambiente (frente loja-vida). Módulo opcional: ausente = placeholder.
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
        print("[ShopScene] src/ui/shop/ShopProps.lua ausente — lanterna e copo de dados em placeholder")
    end
    return props
end
ShopScene._getProps = getProps

-- Primeiro código registrado (contrato Sfx.has: som novo entra quando o
-- arquivo chegar). Sem áudio nenhum, não avisa (headless).
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

-- Tilable em X com pontas: left | mid (esticado ou repetido) | right.
local function drawStrip(prefix, x, y, w, h, tile)
    local l, m, r = art(prefix .. "_left"), art(prefix .. "_mid"), art(prefix .. "_right")
    if not (l and m and r) then return false end
    local k = h / l:getHeight()
    local lw, rw = l:getWidth() * k, r:getWidth() * k
    love.graphics.draw(l, x, y, 0, k, k)
    love.graphics.draw(r, x + w - rw, y, 0, k, k)
    local midW = w - lw - rw
    if midW > 0 then
        if tile then
            local mw = m:getWidth() * k
            local mx = x + lw
            local n = math.ceil(midW / mw)
            for i = 0, n - 1 do
                local sx = mx + i * mw
                local remaining = (x + w - rw) - sx
                if remaining >= mw then
                    love.graphics.draw(m, sx, y, 0, k, k)
                else
                    love.graphics.draw(m, quad("strip_" .. prefix, 0, 0, remaining / k, m:getHeight(), m:getWidth(), m:getHeight()), sx, y, 0, k, k)
                end
            end
        else
            love.graphics.draw(m, x + lw, y, 0, midW / m:getWidth(), k)
        end
    end
    return true
end

-- ============================================================================
-- CONSTRUÇÃO
-- ============================================================================
function ShopScene.new(screen)
    local self = setmetatable({}, ShopScene)
    self.screen = screen
    self.items = {}
    self.bySlot = {}
    self.outgoing = nil
    self.shelfSlide = 0
    self.t = 0
    self.light = { dx = 0, target = 0, timer = 0 }
    self.bell = { ringing = 0 }
    self.ledgerHover = 0
    self.diceHover = 0
    self.bellHover = 0
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

-- (Re)constrói os itens a partir das ofertas. O estado de animação por slot
-- (balanço da etiqueta, etiqueta caindo, hover) sobrevive ao rebuild — a tela
-- reconstrói a cada compra e a cada resize.
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
end

-- Instâncias de carta vivas (a tela espelha em cardInstances: dissolve da
-- saída, selo de descoberta, testes).
function ShopScene:cardInstances()
    local out = {}
    for _, it in ipairs(self.items) do
        if it.card and not it.sold then out[#out + 1] = it.card end
    end
    return out
end

-- Posições por slot no formato histórico da tela (x, y, w, h, row, kind):
-- tools e testes antigos leem cardPositions.
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
    self.shelfSlide = 0
end

-- ============================================================================
-- UPDATE
-- ============================================================================
function ShopScene:_mouseLocal()
    local mx, my = love.mouse.getPosition()
    my = my - (self.screen.slideOffsetY or 0)
    return mx, my
end

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ShopScene:update(dt)
    if not self.L then self:layout() end
    self.t = self.t + dt
    local L = self.L
    local mx, my = self:_mouseLocal()
    local sx = mx - self.shelfSlide     -- os objetos vivem dentro do slide da estante
    local sliding = math.abs(self.shelfSlide) > 1 or math.abs(self.screen.slideOffsetY or 0) > 1
    local blocked = self.screen._closing or self.outgoing ~= nil

    -- hover das cartas (tilt 3D é da própria Card)
    local hovered = nil
    for _, it in ipairs(self.items) do
        if it.card and not it.sold and it.rect then
            it.card:updateMouse(sx, my, dt, not blocked)
            if it.card.isHovered and not hovered then hovered = it end
        end
    end
    if not hovered and not blocked then
        for _, it in ipairs(self.items) do
            if it.kind ~= "card" and it:hit(sx, my) then hovered = it break end
        end
    end
    self.hovered = hovered

    for _, it in ipairs(self.items) do
        local entered = it:update(dt, it == hovered)
        if entered and not sliding then
            local codes = (it.kind == "pack") and { "hoverPack", "hoverCard" }
                or (it.kind == "relic") and { "hoverRelic", "hoverCard" } or nil
            if codes then playFirst(codes, { pitch = 0.95 + (math.random() * 2 - 1) * 0.18 }) end
        end
    end
    for _, it in ipairs(self.outgoing or {}) do it:update(dt, false) end

    -- a luz "olha" pro objeto em degraus (estado com alvo, perseguição a 4/s)
    local lt = self.light
    if hovered and hovered.rect then
        local cx = hovered.rect.x + hovered.rect.w / 2
        local fx = L.lantern.x + L.lantern.w / 2
        local steps = clamp(math.floor((cx - fx) / (L.leftW * 0.5) * ShopLayout.LIGHT_STEPS + 0.5),
            -ShopLayout.LIGHT_STEPS, ShopLayout.LIGHT_STEPS)
        lt.target = steps * ShopLayout.LIGHT_STEP
    else
        lt.target = 0
    end
    lt.timer = lt.timer + dt
    if lt.timer >= 0.25 then
        lt.timer = 0
        if lt.dx < lt.target then lt.dx = math.min(lt.target, lt.dx + ShopLayout.LIGHT_STEP)
        elseif lt.dx > lt.target then lt.dx = math.max(lt.target, lt.dx - ShopLayout.LIGHT_STEP) end
    end
    if reducedMotion() then lt.dx = lt.target end

    -- balcão: hover dos três objetos
    local C = L.counter
    local function lerpHover(cur, on)
        if reducedMotion() then return on and 1 or 0 end
        return cur + ((on and 1 or 0) - cur) * math.min(1, dt * 12)
    end
    local overBell = not blocked and inRect(C.bell, mx, my)
    local overDice = not blocked and self.screen.diceButton ~= nil and inRect(C.dice, mx, my)
    local overLedger = not blocked and inRect(C.ledger, mx, my)
    self.bellHover = lerpHover(self.bellHover, overBell)
    self.diceHover = lerpHover(self.diceHover, overDice)
    self.ledgerHover = lerpHover(self.ledgerHover, overLedger)
    self.hoverCounter = (overBell and "bell") or (overDice and "dice") or (overLedger and "ledger") or nil
    if self.bell.ringing > 0 then self.bell.ringing = math.max(0, self.bell.ringing - dt) end

    for i = #self.flies, 1, -1 do
        if self.flies[i]._done then table.remove(self.flies, i) end
    end

    local P = getProps()
    if P and P.update then
        local run = self.screen._run and self.screen:_run() or nil
        local hx, hy
        if hovered and hovered.rect then hx, hy = hovered.rect.x + hovered.rect.w / 2, hovered.rect.y + hovered.rect.h / 2 end
        local ok, err = pcall(P.update, dt, L, { t = self.t, reduced = reducedMotion(), hoverX = hx, hoverY = hy,
            run = run, cupHover = self.diceHover })
        if not ok then print("[ShopScene] ShopProps.update: " .. tostring(err)) end
    end
end

-- ============================================================================
-- EVENTOS (chamados pela tela)
-- ============================================================================
-- Destino do voo por tipo de compra (espaço da UI, fora do slide).
function ShopScene:_flyTarget(offer, kind)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local tb = _G.topBar
    if kind == "card" then
        local cd = self.screen.cardDatabase and self.screen.cardDatabase:getCard(offer.id)
        if cd and cd.type == "joker" then
            return math.floor(sw * 0.10), 26, 0.18       -- quadro de coringas (topo-esquerda da batalha)
        end
        if tb and tb._layout then
            local ok, Lt = pcall(tb._layout, tb)
            if ok and Lt and Lt.deck then return Lt.deck.x + 24, 26, 0.12 end
        end
        return 205, 6, 0.12
    elseif kind == "relic" then
        return 60, sh - 70, 0.4                           -- painel do jogador (canto inferior esquerdo)
    end
    return sw / 2, sh / 2, 0.3
end

function ShopScene:onPurchased(offer)
    local it = offer and self.bySlot[offer._slot]
    if not it then return end
    local payload = it:flyPayload()
    it:markSold()
    playFirst({ "coinTotalThud", "purchaseConfirm" })
    playFirst({ "sceneWoodKnock" }, { pitch = 1.1, volume = 0.5 })
    if payload and not reducedMotion() then
        local tx, ty, ts = self:_flyTarget(offer, it.kind)
        payload.x = payload.x + self.shelfSlide
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

-- Sem ouro: etiqueta treme vermelha, ouro da TopBar pisca. Sem toast.
function ShopScene:onDenied(offer)
    local it = offer and self.bySlot[offer._slot]
    if it then it:deny() end
    local tb = _G.topBar
    if tb then
        if tb.flashGold then tb:flashGold(-1)
        else tb._goldFlash = { dir = -1, t = 0.6 } end
    end
end

-- Sino: as prateleiras deslizam pra fora (esquerda) e voltam repostas, um
-- objeto por vez. Os DADOS já trocaram (a tela regenerou as ofertas antes de
-- chamar); aqui só a coreografia. reducedMotion = troca na hora.
function ShopScene:reroll(newOffers)
    self.bell.ringing = 0.9
    EventManager.clear(REROLLQ)
    if reducedMotion() or not self.L then
        self.outgoing = nil
        self.shelfSlide = 0
        self:setOffers(newOffers)
        return
    end
    self.outgoing = self.items
    self.items, self.bySlot = {}, {}      -- setOffers não herda fx dos que estão saindo
    self:setOffers(newOffers)
    for _, it in ipairs(self.items) do it.entry.v = 0 end
    local off = -(self.L.leftW + 260)
    self.shelfSlide = 0
    EventManager.parallelEase(self, "shelfSlide", off, 0.34, "ease_in", REROLLQ)
    EventManager.parallel(0.36, function()
        self.outgoing = nil
        self.shelfSlide = off
        EventManager.parallelEase(self, "shelfSlide", 0, 0.40, "ease_out", REROLLQ)
    end, REROLLQ)
    for i, it in ipairs(self.items) do
        local entry = it.entry
        EventManager.parallel(0.72 + (i - 1) * 0.06, function()
            EventManager.parallelEase(entry, "v", 1, 0.26, "back_out", REROLLQ)
            Moveable.juice_up(it, 0.10, 0.03)
            playFirst({ "cardShelfPlace", "cardDraw" }, { pitch = 0.94 + (i - 1) * 0.04 })
        end, REROLLQ)
    end
end

-- Entrada da loja: os objetos pousam um a um (mesma cadência do sino).
function ShopScene:enter()
    if reducedMotion() then
        for _, it in ipairs(self.items) do it.entry.v = 1 end
        return
    end
    for i, it in ipairs(self.items) do
        local entry = it.entry
        entry.v = 0
        EventManager.parallel(0.40 + (i - 1) * 0.07, function()
            EventManager.parallelEase(entry, "v", 1, 0.26, "back_out", REROLLQ)
            Moveable.juice_up(it, 0.10, 0.03)
            playFirst({ "cardShelfPlace", "cardDraw" }, { pitch = 0.94 + (i - 1) * 0.04 })
        end, REROLLQ)
    end
end

function ShopScene:isBusy()
    return self.outgoing ~= nil or math.abs(self.shelfSlide) > 1
end

-- Item sob um ponto (coordenadas da UI, já sem o slide da tela).
function ShopScene:itemAt(mx, my)
    if self.outgoing or self.screen._closing then return nil end
    local sx = mx - self.shelfSlide
    for _, it in ipairs(self.items) do
        if it.card and not it.sold and it.card.isHovered then return it end
    end
    for _, it in ipairs(self.items) do
        if not it.sold and it.rect and it:hit(sx, my) then return it end
    end
    return nil
end

-- ============================================================================
-- DRAW
-- ============================================================================
function ShopScene:_drawWall()
    local L = self.L
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local base = Palette.darken(Palette.INK, 0.6)
    Palette.set(base)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- tábuas verticais discretas (véu, não textura): linha mais escura a cada ~56px
    Palette.set(Palette.INK, 0.35)
    local step = 56
    for x = L.wall.x % step, w, step do
        love.graphics.rectangle("fill", x, 0, 1, h)
    end
    Palette.set(Palette.RUST, 0.04)
    for x = (L.wall.x + 28) % step, w, step do
        love.graphics.rectangle("fill", x, 0, 2, h)
    end
    -- vinheta lateral
    local band = math.floor(w * 0.08)
    for i = 0, 6 do
        love.graphics.setColor(0, 0, 0, 0.06)
        love.graphics.rectangle("fill", 0, 0, band * (1 - i / 7), h)
        love.graphics.rectangle("fill", w - band * (1 - i / 7), 0, band * (1 - i / 7), h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_flameAnchor()
    local L = self.L
    local P = getProps()
    if P and P.flameAnchor then
        local ok, x, y = pcall(P.flameAnchor, L.lantern)
        if ok and x and y then return x, y end
    end
    return L.lantern.x + L.lantern.w / 2, L.lantern.y + L.lantern.h * 0.6
end

-- Cone de luz âmbar na parede, em degraus de alpha (nunca disco liso),
-- deslocado em passos na direção do objeto em hover.
function ShopScene:_drawLight()
    local L = self.L
    local fx, fy = self:_flameAnchor()
    local P = getProps()
    local dx, level = self.light.dx, 1
    if P and P.lookDx then
        local ok, v = pcall(P.lookDx, L.lantern)
        if ok and type(v) == "number" then dx = v end
    end
    if P and P.lightLevel then
        local ok, v = pcall(P.lightLevel)
        if ok and type(v) == "number" then level = v end
    end
    -- FEIXE: trapézios aninhados saindo da chama, abrindo pra esquerda sobre
    -- as estantes (a lanterna fica entre a prateleira e o pergaminho). Quatro
    -- degraus de alpha — posterizado como o light_dither, nunca um disco liso
    -- (o dono tirou "as bolas de luz" do salão do chefe). O deslocamento em
    -- passos (dx) move a boca do feixe, não a chama.
    local warm = Palette.AGED_GOLD
    local by = L.counter.y + 4
    local reach = L.leftW * (0.95 + 0.05 * level)
    local right = L.lantern.w * 1.6 * level
    for i = 4, 1, -1 do
        local k = i / 4
        love.graphics.setColor(warm[1], warm[2] * 0.9, warm[3] * 0.55, 0.035)
        love.graphics.polygon("fill",
            fx - 5, fy, fx + 5, fy,
            fx + right * k, by,
            fx - reach * k + dx * 3, by)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_drawSign()
    local L = self.L
    local s = L.sign
    local font = FontManager.getFont(math.max(13, math.floor(love.graphics.getHeight() / 80)))
    love.graphics.setFont(font)
    local title = I18n.t("reward.shop_title")
    local tw = font:getWidth(title)
    local tx = math.floor(s.x + (s.w - tw) / 2)
    local ty = math.floor(s.y + (s.h - font:getHeight()) / 2)
    FontManager.drawWithOutline(title, tx, ty, Palette.AGED_GOLD_LIGHT, 0.9)
    local midY = ty + math.floor(font:getHeight() / 2)
    local lineW = math.min(120, math.floor(s.w * 0.12))
    Palette.set(Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("fill", tx - 16 - lineW, midY, lineW, 1)
    love.graphics.rectangle("fill", tx + tw + 16, midY, lineW, 1)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.rectangle("fill", tx - 16 - lineW - 3, midY - 1, 3, 3)
    love.graphics.rectangle("fill", tx + tw + 16 + lineW, midY - 1, 3, 3)

    -- "?" das regras de oferta (pity, afinidade, raridade por ato): logo
    -- depois do filete da direita (geometria derivada do texto; o rect vai
    -- pro layout pra validação e hit-test).
    local HelpBadge = require("src.ui.HelpBadge")
    local r = 9
    local cx = math.min(tx + tw + 16 + lineW + 16, s.x + s.w - r - 4)
    local cy = midY
    local h = { x = cx - r - 3, y = cy - r - 3, w = r * 2 + 6, h = r * 2 + 6 }
    L.help = h
    local mx, my = self:_mouseLocal()
    local hot = inRect(h, mx, my)
    HelpBadge.draw(cx, cy, r, hot)
    require("src.ui.NavCursor").target("rules", h.x, h.y, h.w, h.h)
    if hot then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my + (self.screen.slideOffsetY or 0))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_drawBoard(prefix, b)
    if drawStrip(prefix, b.x, b.y, b.w, b.h, false) then return end
    local wood = Palette.lerp(Palette.RUST, Palette.INK, 0.55)
    for i = 1, 3 do
        Palette.set(Palette.INK, 0.2 - i * 0.05)
        love.graphics.rectangle("fill", b.x + 2, b.y + b.h + i * 2, b.w - 4, 2)
    end
    Palette.set(wood)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    Palette.set(Palette.lerp(Palette.RUST, Palette.AGED_GOLD_DARK, 0.5))
    love.graphics.rectangle("fill", b.x, b.y, b.w, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_itemCtx(it)
    local afford = true
    local eco = self.screen.game and self.screen.game.economySystem
    if eco and it.offer and (it.offer.cost or 0) > 0 then afford = eco:canAfford(it.offer.cost) end
    return { t = self.t, afford = afford, alpha = 1, reduced = reducedMotion() }
end

function ShopScene:_drawShelves(list)
    local L = self.L
    local NavCursor = require("src.ui.NavCursor")
    local cards, relics, packs = {}, {}, {}
    for _, it in ipairs(list) do
        if it.rect then
            if it.kind == "card" then cards[#cards + 1] = it
            elseif it.kind == "relic" then relics[#relics + 1] = it
            else packs[#packs + 1] = it end
        end
    end

    -- ===== estante de cima =====
    self:_drawBoard("shelf_top", L.board1)
    for _, it in ipairs(cards) do
        if not it.sold then it:drawStand(false, 1) end
        it:drawDust({ alpha = 1 })
    end
    for _, it in ipairs(cards) do it:drawObject(self:_itemCtx(it)) end
    for _, it in ipairs(cards) do
        if not it.sold then it:drawStand(true, 1) end
        it:drawTag(self:_itemCtx(it))
    end

    -- ===== gancho (sob a tábua de cima) + prateleira de baixo =====
    local hook = art("hook")
    local hk = L.pack.hook
    if hook then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hook, hk.x, hk.y, 0, hk.w / hook:getWidth(), hk.h / hook:getHeight())
    else
        Palette.set(Palette.STEEL)
        love.graphics.rectangle("fill", hk.x + hk.w / 2 - 1, hk.y, 2, hk.h - 3)
        love.graphics.rectangle("fill", hk.x + hk.w / 2 - 1, hk.y + hk.h - 4, 5, 2)
    end
    self:_drawBoard("shelf_bottom", L.board2)
    for _, it in ipairs(relics) do it:drawDust({ alpha = 1 }) end
    for _, it in ipairs(packs) do it:drawDust({ alpha = 1 }) end
    for _, it in ipairs(relics) do
        it:drawObject(self:_itemCtx(it))
        if not it.sold then
            NavCursor.target("offer:" .. it.slot, it.rect.x, it.rect.y, it.rect.w, it.rect.h)
        end
    end
    for _, it in ipairs(packs) do
        it:drawObject(self:_itemCtx(it))
        if not it.sold then
            NavCursor.target("offer:" .. it.slot, it.rect.x, it.rect.y, it.rect.w, it.rect.h)
        end
    end
    for _, it in ipairs(relics) do it:drawTag(self:_itemCtx(it)) end
    for _, it in ipairs(packs) do it:drawTag(self:_itemCtx(it)) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Rótulo a giz na frente do balcão, sob o objeto (informação ANCORADA).
function ShopScene:_chalkLabel(text, cx, color, maxW)
    local C = self.L.counter
    local font, fitted = TextFit.fit(text, clamp(math.floor(C.labelH * 0.5), 7, 10), maxW)
    love.graphics.setFont(font)
    local tw = font:getWidth(fitted)
    local y = C.labelY + math.floor((C.labelH - font:getHeight()) / 2)
    Palette.set(Palette.INK, 0.7)
    love.graphics.print(fitted, math.floor(cx - tw / 2) + 1, y + 1)
    Palette.set(color or Palette.PARCHMENT_LIGHT, 0.9)
    love.graphics.print(fitted, math.floor(cx - tw / 2), y)
end

function ShopScene:_drawCounter()
    local L = self.L
    local C = L.counter
    local sc = self.screen
    -- tampo + frente
    local top = C.plank.y
    if not drawStrip("counter", C.x, top, C.w, C.y + C.h - top, true) then
        local wood = Palette.lerp(Palette.RUST, Palette.INK, 0.5)
        Palette.set(Palette.darken(wood, 0.6))
        love.graphics.rectangle("fill", C.x, C.plank.y + C.plank.h, C.w, C.frontH)
        Palette.set(wood)
        love.graphics.rectangle("fill", C.x, C.plank.y, C.w, C.plank.h)
        Palette.set(Palette.lerp(Palette.RUST, Palette.AGED_GOLD_DARK, 0.5))
        love.graphics.rectangle("fill", C.x, C.plank.y, C.w, 1)
    end

    local eco = sc.game and sc.game.economySystem
    local mx, my = self:_mouseLocal()

    -- ===== sino (novas ofertas) =====
    local bellR = C.bell
    local cost = sc.shopSystem and sc.shopSystem.getRefreshCost and sc.shopSystem:getRefreshCost() or 0
    local canRing = (not eco) or eco:canAfford(cost)
    local bell = art("bell")
    local frame = 1
    if self.bell.ringing > 0 and not reducedMotion() then
        local seq = { 2, 3, 2, 4, 3, 2, 1 }
        frame = seq[math.min(#seq, 1 + math.floor((0.9 - self.bell.ringing) * 12))] or 1
    end
    local lift = -self.bellHover * 2
    if bell then
        local fw, fh = bell:getWidth() / 4, bell:getHeight()
        local k = bellR.w / fw
        if canRing then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.55, 0.5, 0.45, 0.8) end
        love.graphics.draw(bell, quad("bell", (frame - 1) * fw, 0, fw, fh, bell:getWidth(), bell:getHeight()),
            bellR.x, bellR.y + lift, 0, k, k)
    else
        Palette.set(canRing and Palette.AGED_GOLD or Palette.STEEL)
        love.graphics.ellipse("fill", bellR.x + bellR.w / 2, bellR.y + bellR.h * 0.55 + lift, bellR.w * 0.4, bellR.h * 0.35)
    end
    -- preço do sino a giz (o nome vai no tooltip; "Novas ofertas" inteiro não
    -- cabe sob um objeto de 40px sem atropelar o vizinho)
    self:_chalkLabel("$" .. tostring(cost), bellR.x + bellR.w / 2,
        canRing and Palette.PARCHMENT_LIGHT or Palette.lighten(Palette.BLOOD, 0.3),
        math.max(24, C.dice.x - bellR.x - 6))

    -- ===== copo de dados =====
    if sc.diceButton then
        local dr = C.dice
        local P = getProps()
        local drawn = false
        if P and P.drawDiceCup then
            local run = sc._run and sc:_run() or nil
            local ScribeDice = require("src.systems.ScribeDice")
            local st = ScribeDice.state(run)
            local ok, err = pcall(P.drawDiceCup, dr, { hover = self.diceHover, used = ScribeDice.isUsed(run),
                total = st and st.total or nil, run = run, t = self.t, reduced = reducedMotion() })
            if ok then drawn = true else print("[ShopScene] ShopProps.drawDiceCup: " .. tostring(err)) end
        end
        if not drawn then
            -- placeholder: copo de couro deitado com dois pontinhos
            local cup = Palette.lerp(Palette.RUST, Palette.INK, 0.35)
            Palette.set(Palette.INK)
            love.graphics.rectangle("fill", dr.x + dr.w * 0.2 - 1, dr.y + dr.h * 0.25 - 1 - self.diceHover * 2, dr.w * 0.6 + 2, dr.h * 0.75 + 2)
            Palette.set(cup)
            love.graphics.rectangle("fill", dr.x + dr.w * 0.2, dr.y + dr.h * 0.25 - self.diceHover * 2, dr.w * 0.6, dr.h * 0.75)
            Palette.set(Palette.PARCHMENT_LIGHT)
            love.graphics.rectangle("fill", dr.x + dr.w * 0.22, dr.y + dr.h * 0.25 - self.diceHover * 2, dr.w * 0.56, 2)
        end
    end

    -- ===== livro-razão (seguir viagem) =====
    local lr = C.ledger
    local ledger = art("ledger")
    local open = self.ledgerHover > 0.5
    if ledger then
        local fw, fh = ledger:getWidth() / 2, ledger:getHeight()
        local k = math.min(lr.w / fw, lr.h / fh)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(ledger, quad("ledger", open and fw or 0, 0, fw, fh, ledger:getWidth(), ledger:getHeight()), lr.x + (lr.w - fw * k) / 2, lr.y + lr.h - fh * k - self.ledgerHover * 2, 0, k, k)
    else
        Palette.set(Palette.INK)
        love.graphics.rectangle("fill", lr.x - 1, lr.y - 1, lr.w + 2, lr.h + 2)
        Palette.set(Palette.lerp(Palette.BLOOD_DARK, Palette.RUST, 0.4))
        love.graphics.rectangle("fill", lr.x, lr.y, lr.w, lr.h)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.rectangle("fill", lr.x + 2, lr.y + lr.h - 4, lr.w - 4, 2)
    end
    if sc.skipButton then
        -- rótulo centrado no LIVRO, empurrado pra esquerda se bater na ponta
        -- do balcão; nunca invade a zona do copo de dados
        local zoneX0 = C.dice.x + C.dice.w + 8
        local zoneW = C.x + C.w - 6 - zoneX0
        local txt = sc.skipButton.text or ""
        local font = TextFit.fit(txt, clamp(math.floor(C.labelH * 0.5), 7, 10), zoneW)
        local tw = font:getWidth(txt)
        local cx = math.min(lr.x + lr.w / 2, C.x + C.w - 6 - tw / 2)
        cx = math.max(cx, zoneX0 + tw / 2)
        self:_chalkLabel(txt, cx, Palette.AGED_GOLD_LIGHT, zoneW)
    end

    -- tooltips dos objetos do balcão (foco = hover)
    if self.hoverCounter then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            local ctx = { n = cost, bonus = (sc.modeConfig and sc.modeConfig.skipBonus) or 0 }
            StatusTooltip.show("shop_" .. self.hoverCounter, mx, my + (sc.slideOffsetY or 0), ctx)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopScene:_drawLantern()
    local L = self.L
    local P = getProps()
    if P and P.drawLantern then
        local ok, err = pcall(P.drawLantern, L.lantern, { t = self.t, lookDx = self.light.dx, reduced = reducedMotion() })
        if ok then return end
        print("[ShopScene] ShopProps.drawLantern: " .. tostring(err))
    end
    -- placeholder: armação escura + vidro âmbar + chama em 3 degraus
    local r = L.lantern
    local gx, gy, gw, gh = r.x + r.w * 0.2, r.y + r.h * 0.25, r.w * 0.6, r.h * 0.5
    Palette.set(Palette.INK)
    love.graphics.rectangle("fill", gx - 2, gy - 2, gw + 4, gh + 4)
    love.graphics.rectangle("fill", r.x + r.w * 0.45, r.y, r.w * 0.1, r.h * 0.25)
    local step = reducedMotion() and 1 or (1 + math.floor(self.t * 6) % 3)
    local flame = Palette.lerp(Palette.AGED_GOLD, Palette.PARCHMENT_LIGHT, 0.3 * step)
    Palette.set(Palette.lerp(Palette.RUST, Palette.AGED_GOLD, 0.5), 0.6)
    love.graphics.rectangle("fill", gx, gy, gw, gh)
    Palette.set(flame)
    love.graphics.rectangle("fill", gx + gw * 0.35, gy + gh * (0.55 - 0.1 * step), gw * 0.3, gh * (0.3 + 0.1 * step))
    love.graphics.setColor(1, 1, 1, 1)
end

-- Pergaminho de inspeção: prego + rolo (9-slice) + o CardDetailPanel da tela
-- dentro do miolo (tinta sobre pergaminho).
function ShopScene:_drawScroll()
    local L = self.L
    local S = L.scroll
    local nail = art("nail")
    local n = S.nail
    local frame = art("scroll_frame")
    if frame then
        -- 9-slice: os rolos (cilindros horizontais) esticam só em X e têm a
        -- altura que o layout reservou (rollerH / footH); o papel do meio
        -- estica nos dois eixos; as bordas do papel só em Y.
        local fw, fh = frame:getWidth(), frame:getHeight()
        local rollerA = math.floor(fh * 0.17)   -- rolo de cima na arte
        local footA = math.floor(fh * 0.21)     -- rolo de baixo + borla
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
        Palette.set(Palette.PARCHMENT_DARK)
        love.graphics.rectangle("fill", S.x, S.y, S.w, 10)
        love.graphics.rectangle("fill", S.x, S.y + S.h - 10, S.w, 10)
    end
    if nail then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(nail, n.x, n.y, 0, n.w / nail:getWidth(), n.h / nail:getHeight())
    else
        Palette.set(Palette.STEEL)
        love.graphics.rectangle("fill", n.x + 2, n.y, n.w - 4, n.h)
    end
    love.graphics.setColor(1, 1, 1, 1)
    if self.screen._drawDetailPanel then
        self.screen:_drawDetailPanel(S.body, true)
    end
end

function ShopScene:draw()
    if not self.L then self:layout() end
    local L = self.L
    local P = getProps()
    local ctx = { t = self.t, reduced = reducedMotion() }

    self:_drawWall()
    self:_drawLight()
    if P and P.drawBack then
        local ok, err = pcall(P.drawBack, L, ctx)
        if not ok then print("[ShopScene] ShopProps.drawBack: " .. tostring(err)) end
    end
    self:_drawSign()

    love.graphics.push()
    love.graphics.translate(math.floor(self.shelfSlide), 0)
    self:_drawShelves(self.outgoing or self.items)
    love.graphics.pop()

    self:_drawCounter()
    self:_drawLantern()
    self:_drawScroll()

    if P and P.drawFront then
        local ok, err = pcall(P.drawFront, L, ctx)
        if not ok then print("[ShopScene] ShopProps.drawFront: " .. tostring(err)) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Objetos voando pro destino: chamado pela tela FORA do slide (por cima da
-- TopBar, que é o destino da carta).
function ShopScene:drawFlies()
    for _, f in ipairs(self.flies) do
        love.graphics.setColor(1, 1, 1, f.alpha or 1)
        love.graphics.draw(f.img, f.x, f.y, f.rot or 0, f.scale, f.scale, f.ox or 0, f.oy or 0)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ShopScene
