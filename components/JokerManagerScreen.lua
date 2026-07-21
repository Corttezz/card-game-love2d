-- components/JokerManagerScreen.lua
-- GERENCIADOR DE CORINGAS — tela cheia (Jul/2026). Mostra TODOS os coringas
-- possuídos na run (coleção + bancada) e deixa o jogador escolher quais 3
-- ficam ATIVOS. Nasceu do feedback: "posso comprar vários jokers e eles
-- somem; queria acessar todos e escolher os ativos, trocando ao longo da run".
--
-- Regras:
--   • Coleção ilimitada; até MAX_JOKER_SLOTS ativos (o resto na bancada).
--   • Clique num coringa alterna ativo/bancada (respeitando o teto).
--   • Ativos: moldura dourada + selo "ATIVO N". Bancada: esmaecido + "BANCADA".
--   • Hover mostra o tooltip completo. ESC / J / X fecha.
--
-- Abrir: clique no painel de coringas (topo-esquerdo do combate) OU tecla J.

local JokerManagerScreen = {}
JokerManagerScreen.__index = JokerManagerScreen

local FontManager     = require("src.ui.FontManager")
local Palette         = require("src.ui.Palette")
local HintBar         = require("src.ui.HintBar")
local SceneBackground = require("src.ui.SceneBackground")
local CardGridRender  = require("src.ui.CardGridRender")
local Sfx             = require("src.systems.Sfx")
local I18n            = require("src.i18n.I18n")

-- MESMAS métricas do DeckViewer/Coleção (feedback Jul/2026: "o gerenciador
-- não está parecido com o deck e a coleção") — carta, gaps e header iguais;
-- a única diferença de layout é a LINHA DE ESTADO sob cada carta (ATIVO n /
-- BANCADA), que é a informação própria desta tela.
local CARD_W, CARD_H = 128, 192
local GAP_X, GAP_Y   = 18, 22
local LABEL_H        = 20    -- linha de estado sob a carta
local TOP_OFFSET     = 118
local BOTTOM_PAD     = 46

function JokerManagerScreen:new()
    local instance = setmetatable({}, JokerManagerScreen)
    instance.visible = false
    instance.game = nil
    instance.instances = {}
    instance.scroll = 0
    instance.maxScroll = 0
    instance._openedAt = 0
    instance._cardRects = {}
    instance.cardInfo = require("src.ui.CardInfoDisplay"):new()
    return instance
end

function JokerManagerScreen:_build()
    self.instances = {}
    local rm = self.game and self.game.runManager
    if rm and rm.buildAllJokerInstances then
        self.instances = rm:buildAllJokerInstances()
    end
end

function JokerManagerScreen:show(game)
    self.visible = true
    self.game = game
    self.scroll = 0
    self._openedAt = love.timer.getTime()
    self:_build()
    Sfx.play("menuOpen")
end

function JokerManagerScreen:hide()
    self.visible = false
    self.instances = {}
    Sfx.play("menuClose")
end

function JokerManagerScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function JokerManagerScreen:isVisible() return self.visible end
function JokerManagerScreen:resize() self.scroll = 0 end
function JokerManagerScreen:update(dt) end

local function columnsFor(width)
    local cols = math.floor((width - 140 + GAP_X) / (CARD_W + GAP_X))
    return math.max(3, math.min(6, cols))
end

function JokerManagerScreen:_gridMetrics()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cols = columnsFor(sw)
    local totalW = cols * CARD_W + (cols - 1) * GAP_X
    local gx0 = math.floor((sw - totalW) / 2)
    local gridTop = TOP_OFFSET
    local gridH = sh - TOP_OFFSET - BOTTOM_PAD
    return cols, gx0, gridTop, gridH
end

function JokerManagerScreen:_closeRect()
    local sw = love.graphics.getWidth()
    return sw - 52, 24, 30, 30
end

function JokerManagerScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * 48))
    return true
end

function JokerManagerScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "j" then
        self:hide()
    end
    return true
end

function JokerManagerScreen:mousepressed(x, y, button)
    return self.visible
end

function JokerManagerScreen:_toggleAt(index)
    if not self.game or not self.game.setJokerActive then return end
    local rm = self.game.runManager
    local wasActive = rm and rm.isJokerActive and rm:isJokerActive(index)
    local ok, reason = self.game:setJokerActive(index, not wasActive)
    if ok then
        Sfx.play(wasActive and "cardDeselect" or "jokerActivate")
        self:_build()   -- refresh flags
    else
        if reason == "cap" then
            self.game:addMessage(I18n.t("joker_manager.cap_reached", {
                max = rm:getMaxJokerSlots(),
            }, "Máximo de coringas ativos atingido — desative um primeiro"),
                "warning")
        end
        Sfx.play("error")
    end
end

function JokerManagerScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return true end
    -- ignora o release do clique que abriu (mesmo padrão do DeckViewer)
    if love.timer.getTime() - (self._openedAt or 0) < 0.25 then
        return true
    end
    -- X fecha
    local cx, cy, cw, ch = self:_closeRect()
    if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
        self:hide()
        return true
    end
    -- clique num coringa → alterna ativo/bancada
    for _, r in ipairs(self._cardRects) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self:_toggleAt(r.index)
            return true
        end
    end
    return true
end

function JokerManagerScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    if not SceneBackground.draw("collection", sw, sh, 0.30) then
        love.graphics.setColor(0.05, 0.04, 0.03, 0.96)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    else
        love.graphics.setColor(0.04, 0.03, 0.02, 0.74)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    local rm = self.game and self.game.runManager
    local cap = (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots()) or 3
    local activeN = (rm and rm.getActiveJokerCount and rm:getActiveJokerCount()) or 0

    -- Header
    local tf = FontManager.getResponsiveFont(0.045, 32)
    love.graphics.setFont(tf)
    local title = I18n.t("joker_manager.title", nil, "CORINGAS")
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, math.floor((sw - tf:getWidth(title)) / 2), 22)

    local sub = I18n.t("joker_manager.active_count", { n = activeN, max = cap },
        activeN .. " / " .. cap .. " ativos")
    local sf = FontManager.getFont(14)
    love.graphics.setFont(sf)
    Palette.set(activeN >= cap and Palette.AGED_GOLD or Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, math.floor((sw - sf:getWidth(sub)) / 2), 66)

    local hintTop = I18n.t("joker_manager.subtitle", nil,
        "Clique pra ativar ou mandar pra bancada")
    local hf = FontManager.getFont(9)
    love.graphics.setFont(hf)
    Palette.set(Palette.RUST)
    love.graphics.print(hintTop, math.floor((sw - hf:getWidth(hintTop)) / 2), 92)

    -- X fechar
    do
        local cx, cy, cw, ch = self:_closeRect()
        local mx, my = love.mouse.getPosition()
        local hot = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
        Palette.set(hot and Palette.BLOOD or Palette.PANEL_FILL)
        love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)
        local xf = FontManager.getFont(14)
        love.graphics.setFont(xf)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.print("X", cx + (cw - xf:getWidth("X")) / 2, cy + (ch - xf:getHeight()) / 2)
    end

    -- Vazio
    if #self.instances == 0 then
        local ef = FontManager.getFont(14)
        love.graphics.setFont(ef)
        Palette.set(Palette.PARCHMENT)
        local msg = I18n.t("joker_manager.empty", nil,
            "Você ainda não tem coringas. Compre na loja ou ganhe em recompensas.")
        love.graphics.printf(msg, sw * 0.2, sh * 0.45, sw * 0.6, "center")
        HintBar.draw(I18n.t("joker_manager.hint", nil, "J ou ESC fecha"))
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- ===== Grid — render IDÊNTICO ao DeckViewer/Coleção (CardGridRender:
    -- warp 3D no hover + sombra direcional + ícone vivo + interpolação
    -- suave). A identidade DESTA tela fica nos rótulos ATIVO n / BANCADA
    -- e no alpha da bancada — sem molduras que a Coleção não usa. =====
    local cols, gx0, gridTop, gridH = self:_gridMetrics()
    local rowH = CARD_H + LABEL_H + GAP_Y
    local rows = math.ceil(#self.instances / cols)
    local contentH = rows * rowH
    self.maxScroll = math.max(0, contentH - gridH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end

    local dt = love.timer.getDelta()
    local mx, my = love.mouse.getPosition()
    local mouseInGrid = my >= gridTop and my <= gridTop + gridH
    self._cardRects = {}
    self._cardAnim = self._cardAnim or {}
    local ease = 1 - math.exp(-18 * dt)

    -- 1) alvos + hover na posição de GRID (estável) + numeração dos ativos
    local hovered, hx, hy = nil, 0, 0
    local targetX, targetY, slotOf = {}, {}, {}
    local slotNum = 0
    for i, inst in ipairs(self.instances) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local tx = gx0 + col * (CARD_W + GAP_X)
        local ty = gridTop + row * rowH - self.scroll
        targetX[i], targetY[i] = tx, ty
        if inst._active then
            slotNum = slotNum + 1
            slotOf[i] = slotNum
        end
        if ty + CARD_H > gridTop and ty < gridTop + gridH then
            self._cardRects[#self._cardRects + 1] =
                { index = inst._ownedIndex, x = tx, y = ty, w = CARD_W, h = CARD_H }
            if mouseInGrid and mx >= tx and mx < tx + CARD_W
                and my >= ty and my < ty + CARD_H then
                hovered, hx, hy = inst, tx, ty
            end
        end
    end

    -- 2) interpola posição + hover-scale (mesma receita da Coleção)
    for i, inst in ipairs(self.instances) do
        local anim = self._cardAnim[inst]
        if not anim then
            anim = { rx = targetX[i], ry = targetY[i], hs = 1.0 }
            self._cardAnim[inst] = anim
        end
        anim.rx = anim.rx + (targetX[i] - anim.rx) * ease
        anim.ry = anim.ry + (targetY[i] - anim.ry) * ease
        local targetHs = (inst == hovered) and 1.08 or 1.0
        anim.hs = anim.hs + (targetHs - anim.hs) * ease
    end

    local function computeMouseUV(anim)
        local ccx = anim.rx + CARD_W / 2
        local ccy = anim.ry + CARD_H / 2
        local uvx = (mx - ccx) / (CARD_W / 2)
        local uvy = (my - ccy) / (CARD_H / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        return { uvx, uvy }
    end
    local function hoverStr(hs) return math.max(0, math.min(1, (hs - 1.0) / 0.08)) end
    -- bancada esmaecida; hover devolve presença (convite ao clique)
    local function alphaOf(inst)
        if inst._active then return 1 end
        return inst == hovered and 0.92 or 0.58
    end

    -- rótulo de estado sob a carta (a informação própria desta tela)
    local function drawStateLabel(i, inst, x, y)
        local lf = FontManager.getFont(9)
        love.graphics.setFont(lf)
        local label
        if inst._active then
            label = I18n.t("joker_manager.active_slot", { n = slotOf[i] or 0 },
                "ATIVO " .. (slotOf[i] or 0))
            Palette.set(Palette.AGED_GOLD_LIGHT)
        else
            label = I18n.t("joker_manager.benched", nil, "BANCADA")
            Palette.set(Palette.PARCHMENT_DARK)
        end
        local lx = x + (CARD_W - lf:getWidth(label)) / 2
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print(label, lx + 1, y + CARD_H + 5)
        Palette.set(inst._active and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_DARK)
        love.graphics.print(label, lx, y + CARD_H + 4)
        -- filete dourado sob os ativos (selo discreto, não moldura)
        if inst._active then
            Palette.set(Palette.AGED_GOLD)
            love.graphics.rectangle("fill", x + 16, y + CARD_H + 16, CARD_W - 32, 2)
        end
    end

    -- 3) não-hovered no scissor; hovered por cima COM warp
    love.graphics.setScissor(0, gridTop, sw, gridH)
    for i, inst in ipairs(self.instances) do
        if inst ~= hovered then
            local anim = self._cardAnim[inst]
            if anim and anim.ry + CARD_H + LABEL_H >= gridTop
                and anim.ry <= gridTop + gridH then
                CardGridRender.draw(inst, anim.rx, anim.ry, CARD_W, CARD_H,
                    anim.hs, alphaOf(inst), { 0, 0 }, 0)
                drawStateLabel(i, inst, anim.rx, anim.ry)
            end
        end
    end
    love.graphics.setScissor()

    if hovered then
        local anim = self._cardAnim[hovered]
        if anim then
            CardGridRender.draw(hovered, anim.rx, anim.ry, CARD_W, CARD_H,
                anim.hs, alphaOf(hovered), computeMouseUV(anim), hoverStr(anim.hs))
            for i, inst in ipairs(self.instances) do
                if inst == hovered then drawStateLabel(i, inst, anim.rx, anim.ry) break end
            end
        end
    end

    -- Barra de scroll
    if self.maxScroll > 0 then
        local barX = sw - 12
        local frac = self.scroll / self.maxScroll
        local knobH = math.max(30, gridH * (gridH / (gridH + self.maxScroll)))
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.5)
        love.graphics.rectangle("fill", barX, gridTop, 6, gridH)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, gridTop + frac * (gridH - knobH), 6, knobH)
    end

    -- Tooltip completo
    if hovered then
        hovered.currentScale = scale
        self.cardInfo:draw(hovered, hx, hy - 8, {
            showRarity = true, showStats = true, showDescription = true,
        })
    end

    HintBar.draw(I18n.t("joker_manager.hint", nil,
        "Clique alterna ativo/bancada  ·  RODA rola  ·  J ou ESC fecha"))
    love.graphics.setColor(1, 1, 1, 1)
end

return JokerManagerScreen
