-- components/DeckViewerScreen.lua
-- DECK VIEWER GLOBAL (F5 do UI Overhaul — docs/plan/ui-ux-overhaul-v1.md §5).
-- Overlay de 1 clique disponível em qualquer tela da run: grid do deck da
-- corrida com header de contagens (total/tipos), estado das pilhas
-- (compra/descarte/mão) e nível de forja (+N). Pesquisa (StS mods):
-- "deck viewer acessível de qualquer tela" é o QoL mais pedido do gênero.
--
-- Abrir: clique no deck da TopBar OU tecla D (combate). ESC/D fecha.

local DeckViewerScreen = {}
DeckViewerScreen.__index = DeckViewerScreen

local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local Panel9       = require("src.ui.Panel9")
local HintBar      = require("src.ui.HintBar")
local CardDatabase = require("src.systems.CardDatabase")
local Sfx          = require("src.systems.Sfx")

function DeckViewerScreen:new()
    local instance = setmetatable({}, DeckViewerScreen)
    instance.visible = false
    instance.game = nil
    instance.instances = {}
    instance.counts = { total = 0 }
    instance.scroll = 0
    instance._openedAt = 0
    -- Tooltip completo no hover (StS-style: descrição + raridade + forja)
    instance.cardInfo = require("src.ui.CardInfoDisplay"):new()
    return instance
end

-- Ordena por tipo (attack→defense→effect→joker) e custo dentro do tipo —
-- o default recomendado pela pesquisa (custo/tipo).
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
                -- F5: stats + selo +N na própria moldura (CardFrame re-render)
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

function DeckViewerScreen:wheelmoved(dx, dy)
    if not self.visible then return false end
    self.scroll = math.max(0, self.scroll - dy * 40)
    return true
end

function DeckViewerScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "d" then
        self:hide()
        return true
    end
    return true   -- consome tudo enquanto aberto
end

function DeckViewerScreen:mousepressed(x, y, button)
    return self.visible
end

function DeckViewerScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    -- BUG playtest Jul/2026: o RELEASE do MESMO clique que abriu (press na
    -- TopBar) era roteado pra cá — o ponto fica fora do painel e o viewer
    -- fechava no mesmo frame ("clico e já fecha"). Ignora releases logo
    -- após a abertura.
    if love.timer.getTime() - (self._openedAt or 0) < 0.25 then
        return true
    end
    -- clique fora do painel fecha
    local px, py, pw, ph = self:panelRect()
    if x < px or x > px + pw or y < py or y > py + ph then
        self:hide()
    end
    return true
end

function DeckViewerScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(860, math.floor(sw * 0.88))
    local ph = math.floor(sh * 0.86)
    return math.floor((sw - pw) / 2), math.floor((sh - ph) / 2), pw, ph
end

function DeckViewerScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- véu sobre a cena (o mundo continua visível como contexto)
    love.graphics.setColor(0.04, 0.03, 0.02, 0.72)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    -- header: título + contagens (reconhecimento > memorização)
    local tf = FontManager.getFont(18)
    love.graphics.setFont(tf)
    Palette.set(Palette.INK)
    love.graphics.print("SEU DECK", px + 36, py + 30)

    local cf = FontManager.getFont(9)
    love.graphics.setFont(cf)
    local c = self.counts
    local countsText = c.total .. " cartas — " .. (c.attack or 0)
        .. " ataque · " .. (c.defense or 0) .. " defesa · "
        .. (c.effect or 0) .. " efeito"

    -- estado das pilhas da batalha atual (se em combate)
    local pilesW = 0
    if self.game and self.game.deck then
        local piles = "Compra: " .. #self.game.deck
            .. " · Descarte: " .. #(self.game.discard or {})
            .. " · Mão: " .. #(self.game.hand or {})
        pilesW = cf:getWidth(piles)
        Palette.set(Palette.INK)
        love.graphics.print(piles, px + pw - 36 - pilesW, py + 58)
    end

    -- counts com FIT até o bloco de pilhas (deck grande colidia à direita).
    Palette.set(Palette.RUST)
    require("src.ui.TextFit").print(countsText, px + 36, py + 58,
        { size = 9, maxW = math.max(80, pw - 72 - pilesW - 16) })

    -- grid de cartas (scissor pra rolagem dentro do painel)
    local gridTop = py + 84
    local gridH = ph - 84 - 40
    local scale = 0.92
    local cw, chh = 96 * scale, 144 * scale
    local gutter = 14
    local perRow = math.max(1, math.floor((pw - 72 + gutter) / (cw + gutter)))
    local gx0 = px + math.floor((pw - (perRow * (cw + gutter) - gutter)) / 2)

    -- clamp do scroll
    local rows = math.ceil(#self.instances / perRow)
    local contentH = rows * (chh + gutter)
    local maxScroll = math.max(0, contentH - gridH)
    if self.scroll > maxScroll then self.scroll = maxScroll end

    -- Hover (StS-style): a carta sob o mouse levanta e ganha moldura dourada;
    -- o tooltip COMPLETO (descrição, raridade, forja com ganhos reais) abre
    -- acima dela — desenhado FORA do scissor, por cima de tudo.
    local mx, my = love.mouse.getPosition()
    local hovered, hx, hy = nil, 0, 0
    local mouseInGrid = mx >= px + 12 and mx <= px + pw - 12
        and my >= gridTop and my <= gridTop + gridH

    love.graphics.setScissor(px + 12, gridTop, pw - 24, gridH)
    for i, inst in ipairs(self.instances) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local x = gx0 + col * (cw + gutter)
        local y = gridTop + row * (chh + gutter) - self.scroll
        if y + chh > gridTop and y < gridTop + gridH then
            local isHover = mouseInGrid and mx >= x and mx < x + cw
                and my >= y and my < y + chh
            if isHover then
                hovered, hx, hy = inst, x, y
            elseif inst.image then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(inst.image, x, y, 0, scale, scale)
            end
        end
    end
    -- Hovered por último (fica por cima dos vizinhos): lift + scale sutil +
    -- moldura dourada.
    if hovered and hovered.image then
        local hs = scale * 1.06
        local ox = (cw * (1.06 - 1)) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hovered.image, hx - ox, hy - 4 - ox, 0, hs, hs)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", hx - ox - 2, hy - 6 - ox,
            cw * 1.06 + 4, chh * 1.06 + 4, 3, 3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setScissor()

    -- Tooltip completo por cima de tudo (fora do scissor).
    if hovered then
        hovered.currentScale = scale
        self.cardInfo:draw(hovered, hx, hy - 4, {
            showRarity = true,
            showStats = true,
            showDescription = true,
        })
    end

    HintBar.draw("RODA rola · D ou ESC fecha · clique fora fecha")
    love.graphics.setColor(1, 1, 1, 1)
end

return DeckViewerScreen
