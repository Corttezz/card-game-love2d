-- components/DeckViewerScreen.lua
-- DECK VIEWER GLOBAL — tela CHEIA (não-modal) do deck da run, no estilo da
-- aba de Coleção. Pesquisa (StS mods): "ver o deck inteiro numa tela ampla,
-- passar o mouse pra ver descrição/nível de forja" é o QoL mais pedido do
-- gênero. Reescrito Jul/2026 (feedback: "ocupar praticamente a tela inteira,
-- tipo a aba de coleção, não um modal").
--
-- Abrir: clique no deck da TopBar OU tecla D (combate). ESC/D/X fecha.
-- Mostra o deck COM forja aplicada (valor verde + gemas), grid rolável,
-- hover levanta a carta + moldura dourada + tooltip completo.

local DeckViewerScreen = {}
DeckViewerScreen.__index = DeckViewerScreen

local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local HintBar      = require("src.ui.HintBar")
local SceneBackground = require("src.ui.SceneBackground")
local CardDatabase = require("src.systems.CardDatabase")
local Sfx          = require("src.systems.Sfx")
local I18n         = require("src.i18n.I18n")

-- dimensões da carta renderizada (mesmas da Coleção pra coerência visual)
local CARD_W, CARD_H = 128, 192
local GAP_X, GAP_Y   = 18, 22
local TOP_OFFSET     = 118   -- espaço pro título + contagens
local BOTTOM_PAD     = 46

function DeckViewerScreen:new()
    local instance = setmetatable({}, DeckViewerScreen)
    instance.visible = false
    instance.game = nil
    instance.instances = {}
    instance.counts = { total = 0 }
    instance.scroll = 0
    instance.maxScroll = 0
    instance._openedAt = 0
    instance._cardRects = {}
    -- Tooltip completo no hover (StS-style: descrição + raridade + forja)
    instance.cardInfo = require("src.ui.CardInfoDisplay"):new()
    -- Modal de inspeção completo (igual à aba de Coleção): clicar numa carta
    -- abre a carta grande + painel detalhado, navegável por setas.
    instance.inspectModal = require("src.ui.CardInspectModal"):new()
    return instance
end

-- Ordena por tipo (attack→defense→effect→joker) e custo dentro do tipo.
local TYPE_ORDER = { attack = 1, defense = 2, effect = 3, joker = 4 }

function DeckViewerScreen:_build()
    self.instances = {}
    self.counts = { total = 0, attack = 0, defense = 0, effect = 0, joker = 0 }
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if not run then return end

    local list = {}
    for _, entry in ipairs(run.currentDeck or {}) do
        -- currentDeck guarda id string OU {id, edition, seal} (booster com
        -- edition/seal). Normaliza pro id — senão a carta some do visualizador.
        local id = type(entry) == "table" and entry.id or entry
        local cd = id and CardDatabase:getCard(id)
        if cd then
            table.insert(list, { id = id, cd = cd })
        end
    end
    table.sort(list, function(a, b)
        local ta = TYPE_ORDER[a.cd.type] or 9
        local tb = TYPE_ORDER[b.cd.type] or 9
        if ta ~= tb then return ta < tb end
        local ca = a.cd.cost or 0
        local cb = b.cd.cost or 0
        if ca ~= cb then return ca < cb end
        return (a.cd.name or a.id) < (b.cd.name or b.id)
    end)

    for _, e in ipairs(list) do
        local ok, inst = pcall(function()
            return CardDatabase:createCardInstance(e.cd)
        end)
        if ok and inst then
            inst._deckViewerId = e.id
            local lvl = run.upgraded and run.upgraded[e.id] or 0
            if lvl > 0 and self.game.runManager.applyUpgradesToInstance then
                -- stats + valor verde + gemas na própria moldura (CardFrame re-render)
                self.game.runManager:applyUpgradesToInstance(inst, lvl)
            end
            table.insert(self.instances, inst)
            self.counts.total = self.counts.total + 1
            local t = e.cd.type or "effect"
            self.counts[t] = (self.counts[t] or 0) + 1
        end
    end
end

function DeckViewerScreen:show(game)
    self.visible = true
    self.game = game
    self.scroll = 0
    self._openedAt = love.timer.getTime()
    -- garante que o modal de inspeção não reaparece de uma abertura anterior
    self.inspectModal.card = nil
    self.inspectModal.anim = 0
    self:_build()
    Sfx.play("menuOpen")
end

function DeckViewerScreen:hide()
    self.visible = false
    self.instances = {}
    Sfx.play("menuClose")
end

function DeckViewerScreen:toggle(game)
    if self.visible then self:hide() else self:show(game) end
end

function DeckViewerScreen:isVisible() return self.visible end

function DeckViewerScreen:resize() self.scroll = 0 end

function DeckViewerScreen:update(dt) end

-- ===== Layout helpers (tudo dinâmico da window size) =====

local function columnsFor(width)
    local cols = math.floor((width - 120 + GAP_X) / (CARD_W + GAP_X))
    return math.max(3, math.min(7, cols))
end

function DeckViewerScreen:_gridMetrics()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cols = columnsFor(sw)
    local totalW = cols * CARD_W + (cols - 1) * GAP_X
    local gx0 = math.floor((sw - totalW) / 2)
    local gridTop = TOP_OFFSET
    local gridH = sh - TOP_OFFSET - BOTTOM_PAD
    return cols, gx0, gridTop, gridH
end

function DeckViewerScreen:_closeRect()
    local sw = love.graphics.getWidth()
    return sw - 52, 24, 30, 30
end

function DeckViewerScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    if self.inspectModal:isVisible() then return true end   -- modal trava scroll
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - dy * 48))
    return true
end

function DeckViewerScreen:keypressed(key)
    if not self.visible then return false end
    -- Modal de inspeção consome teclado primeiro (setas navegam, ESC fecha ele)
    if self.inspectModal:isVisible() then
        self.inspectModal:keypressed(key)
        return true
    end
    if key == "escape" or key == "d" then
        self:hide()
        return true
    elseif key == "up" or key == "pageup" then
        self.scroll = math.max(0, self.scroll - 120)
    elseif key == "down" or key == "pagedown" then
        self.scroll = math.min(self.maxScroll, self.scroll + 120)
    end
    return true   -- consome tudo enquanto aberto
end

function DeckViewerScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    -- Modal aberto: cliques vão pras setas / fora-fecha (igual à Coleção).
    if self.inspectModal:isVisible() then
        self.inspectModal:mousepressed(x, y, button)
        return true
    end
    return true
end

function DeckViewerScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    -- BUG playtest Jul/2026: o RELEASE do MESMO clique que abriu (press na
    -- TopBar) era roteado pra cá e fechava no mesmo frame. Ignora releases
    -- logo após a abertura.
    if love.timer.getTime() - (self._openedAt or 0) < 0.25 then
        return true
    end
    -- Modal aberto consome o release (navegação foi no press).
    if self.inspectModal:isVisible() then
        return true
    end
    if button ~= 1 then return true end
    -- botão X (fechar)
    local cx, cy, cw, ch = self:_closeRect()
    if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
        self:hide()
        return true
    end
    -- Clique numa carta → abre a inspeção completa (igual à Coleção).
    for _, r in ipairs(self._cardRects) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            self.inspectModal:show(self.instances[r.i], self.instances, r.i)
            return true
        end
    end
    return true
end

-- ===== Render =====

function DeckViewerScreen:draw()
    if not self.visible then return end
    -- DeckViewer não é atualizado pelo main.lua (só desenhado) — tico o fade do
    -- modal aqui mesmo, com o delta do frame.
    self.inspectModal:update(love.timer.getDelta())
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local modalOpen = self.inspectModal:isVisible()

    -- Fundo cheio: cena de coleção (mesma vibe) + escurecida; fallback = véu.
    if not SceneBackground.draw("collection", sw, sh, 0.30) then
        love.graphics.setColor(0.05, 0.04, 0.03, 0.96)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    else
        love.graphics.setColor(0.04, 0.03, 0.02, 0.72)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    -- ===== Header =====
    local tf = FontManager.getResponsiveFont(0.045, 32)
    love.graphics.setFont(tf)
    local title = I18n.t("deck_viewer.title", nil, "SEU DECK")
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, math.floor((sw - tf:getWidth(title)) / 2), 22)

    -- contagens por tipo (reconhecimento > memorização)
    local c = self.counts
    local cf = FontManager.getFont(11)
    love.graphics.setFont(cf)
    local countsText = I18n.t("deck_viewer.counts", {
        total = c.total, atk = c.attack or 0, def = c.defense or 0,
        eff = c.effect or 0, jok = c.joker or 0,
    }, (c.total .. " cartas   ·   " .. (c.attack or 0) .. " ataque   ·   "
        .. (c.defense or 0) .. " defesa   ·   " .. (c.effect or 0)
        .. " efeito   ·   " .. (c.joker or 0) .. " coringa"))
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(countsText, math.floor((sw - cf:getWidth(countsText)) / 2), 66)

    -- estado das pilhas da batalha atual (se em combate)
    if self.game and self.game.deck then
        local piles = "Compra " .. #self.game.deck
            .. "   ·   Descarte " .. #(self.game.discard or {})
            .. "   ·   Mão " .. #(self.game.hand or {})
        local pf = FontManager.getFont(9)
        love.graphics.setFont(pf)
        Palette.set(Palette.RUST)
        love.graphics.print(piles, math.floor((sw - pf:getWidth(piles)) / 2), 90)
    end

    -- botão X (fechar)
    do
        local cx, cy, cw, ch = self:_closeRect()
        local mx, my = love.mouse.getPosition()
        local hot = mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch
        Palette.set(hot and Palette.BLOOD or Palette.PANEL_FILL)
        love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)
        local xf = FontManager.getFont(14)
        love.graphics.setFont(xf)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.print("X", cx + (cw - xf:getWidth("X")) / 2, cy + (ch - xf:getHeight()) / 2)
    end

    -- ===== Grid =====
    local cols, gx0, gridTop, gridH = self:_gridMetrics()
    local rows = math.ceil(#self.instances / cols)
    local contentH = rows * (CARD_H + GAP_Y)
    self.maxScroll = math.max(0, contentH - gridH)
    if self.scroll > self.maxScroll then self.scroll = self.maxScroll end

    local scale = CARD_W / 96   -- instância é 96×144 → 128×192
    local mx, my = love.mouse.getPosition()
    local hovered, hx, hy = nil, 0, 0
    -- Modal aberto suprime o hover do grid (igual à Coleção).
    local mouseInGrid = (not modalOpen) and my >= gridTop and my <= gridTop + gridH
    self._cardRects = {}

    love.graphics.setScissor(0, gridTop, sw, gridH)
    for i, inst in ipairs(self.instances) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = gx0 + col * (CARD_W + GAP_X)
        local y = gridTop + row * (CARD_H + GAP_Y) - self.scroll
        if y + CARD_H > gridTop and y < gridTop + gridH then
            self._cardRects[#self._cardRects + 1] =
                { i = i, x = x, y = y, w = CARD_W, h = CARD_H }
            local isHover = mouseInGrid and mx >= x and mx < x + CARD_W
                and my >= y and my < y + CARD_H
            if isHover then
                hovered, hx, hy = inst, x, y
            elseif inst.image then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(inst.image, x, y, 0, scale, scale)
            end
        end
    end
    -- Hovered por último (por cima dos vizinhos): lift + scale sutil + moldura.
    if hovered and hovered.image then
        local hs = scale * 1.07
        local ox = (CARD_W * (hs / scale - 1)) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hovered.image, hx - ox, hy - 8 - ox, 0, hs, hs)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", hx - ox - 2, hy - 10 - ox,
            CARD_W * (hs / scale) + 4, CARD_H * (hs / scale) + 4, 3, 3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setScissor()

    -- Barra de scroll à direita
    if self.maxScroll > 0 then
        local barX = sw - 12
        local frac = self.scroll / self.maxScroll
        local knobH = math.max(30, gridH * (gridH / (gridH + self.maxScroll)))
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.5)
        love.graphics.rectangle("fill", barX, gridTop, 6, gridH)
        Palette.set(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, gridTop + frac * (gridH - knobH), 6, knobH)
    end

    -- Tooltip completo no hover (só quando o modal NÃO está aberto).
    if hovered and not modalOpen then
        hovered.currentScale = scale
        self.cardInfo:draw(hovered, hx, hy - 8, {
            showRarity = true,
            showStats = true,
            showDescription = true,
        })
    end

    HintBar.draw(I18n.t("deck_viewer.hint", nil,
        "CLIQUE pra inspecionar  ·  RODA rola  ·  D ou ESC fecha"))

    -- Modal de inspeção completo por cima de TUDO (igual à aba de Coleção).
    self.inspectModal:draw()
    love.graphics.setColor(1, 1, 1, 1)
end

return DeckViewerScreen
