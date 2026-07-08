-- components/RoundEvalScreen.lua
-- Tela de "Cash Out" pós-batalha estilo Balatro.
-- Mapeamento direto de:
--   /home/cortez/projects/balatro-source/functions/UI_definitions.lua:1612-1627 (UIBox)
--   /home/cortez/projects/balatro-source/functions/common_events.lua:927-1095 (add_round_eval_row + animação coins)
--   /home/cortez/projects/balatro-source/functions/state_events.lua:1135-1208 (G.FUNCS.evaluate_round)
--
-- Layout (overlay sobre gameplay congelado):
--   ┌────────────────── PAINEL CENTRAL ──────────────────┐
--   │  AVALIAÇÃO DA RODADA  (DynaText pop-in cascade)     │
--   ├──────────────────────────────────────────────────────┤
--   │  Vitória              $$$$$       (5 coins)          │
--   │  HP cheio             $$$         (3 coins)          │
--   │  Juros                $$          (variable)         │
--   ├──── separator ──────────────────────────────────────┤
--   │             TOTAL: $N                                 │
--   │       ┌────────────────────────────┐                 │
--   │       │  RESGATAR: $N (orange)     │                 │
--   │       └────────────────────────────┘                 │
--   └──────────────────────────────────────────────────────┘
--
-- Timeline:
--   T=0     show() chamado. Painel slide-in do bottom (slideOffsetY: H → 0).
--   T=0.5   Painel settled. jiggle 0.8 + sfx cardSelect.
--   T=0.7+  Cada source aparece (label + coins anim) com stagger 0.5s.
--           Cada coin individual: 0.10s delay, sfx coinPickup pitch random.
--   T=last  Botão "RESGATAR: $N" pop-in laranja com flash.
--   <click> earnGold + slide-out + onCashOut callback.

local RoundEvalScreen = {}
RoundEvalScreen.__index = RoundEvalScreen

local Config       = require("src.core.Config")
local Debug        = require("src.core.Debug")
local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local PixelCanvas  = require("src.ui.PixelCanvas")
local Button       = require("components.Button")
local Sfx          = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DynaText     = require("src.ui.DynaText")
local FlashShader  = require("src.ui.FlashShader")

-- Constantes da timeline (segundos). Padrão Balatro common_events.lua:1141+.
local PHASES = {
    SLIDE_IN      = 0.5,    -- Painel desliza do bottom
    PRE_ROW_DELAY = 0.20,   -- Espera após settle pra primeira row
    ROW_DELAY     = 0.45,   -- Entre cada source (após coins terminarem)
    COIN_STAGGER  = 0.10,   -- Entre cada $ individual
    BIG_THRESHOLD = 60,     -- > 60 dollars: text único, senão coins individuais
    BUTTON_DELAY  = 0.35,   -- Após últimas coins, antes do botão Resgatar
}

function RoundEvalScreen:new()
    local instance = setmetatable({}, RoundEvalScreen)
    instance.visible = false
    instance.game = nil
    instance.onCashOut = nil
    instance.sources = {}
    instance.totalDollars = 0
    instance.coinsAccumulated = 0
    instance.cashOutButton = nil
    instance.cashOutReady = false
    instance._closing = false
    instance.slideOffsetY = 0
    instance.titleText = nil
    instance.totalText = nil
    instance.rowDynas = {}
    instance._rowVisible = {}      -- bool por index (true após pop-in)
    instance._rowCoins = {}        -- count de coins exibidas por row
    instance._totalPulseTimer = 0  -- pulse no total a cada coin
    return instance
end

-- show(game, sources, onCashOut)
--   sources = { { label="Vitória", dollars=5, color={r,g,b,a} }, ... }
function RoundEvalScreen:show(game, sources, onCashOut)
    self.visible = true
    self.game = game
    self.onCashOut = onCashOut
    self.sources = sources or {}
    self.totalDollars = 0
    for _, s in ipairs(self.sources) do
        self.totalDollars = self.totalDollars + (s.dollars or 0)
    end
    self.coinsAccumulated = 0
    self.cashOutReady = false
    self._closing = false
    self.slideOffsetY = love.graphics.getHeight()
    self._rowVisible = {}
    self._rowCoins = {}
    for i = 1, #self.sources do
        self._rowVisible[i] = false
        self._rowCoins[i] = 0
    end
    self._totalPulseTimer = 0

    -- F3: breakdown TINTA×SELO da batalha que acabou (celebração de score).
    self.scoreData = game and game.scoreSystem
        and game.scoreSystem.lastBattle or nil
    self._scoreVisible = false

    self:_buildDynaTexts()
    self:_scheduleTimeline()

    Sfx.play("shopOpen")  -- F11.5: substituiu deckStart genérico por shop chime warm.
    if _G.jiggleScreen then _G.jiggleScreen(0.8) end
    Debug.log("[RoundEvalScreen] open with", #self.sources, "sources, total $" .. self.totalDollars)
end

function RoundEvalScreen:hide()
    self.visible = false
    self.game = nil
    self.cashOutButton = nil
    self.titleText = nil
    self.totalText = nil
    self.scoreText = nil
    self.scoreData = nil
    self.rowDynas = {}
end

function RoundEvalScreen:isVisible()
    return self.visible
end

function RoundEvalScreen:resize()
    if self.visible then
        self:_buildDynaTexts()
        self:_buildCashOutButton()
    end
end

function RoundEvalScreen:_buildDynaTexts()
    self.titleText = DynaText.new({
        text = "AVALIAÇÃO DA RODADA",
        fontSize = 22,
        bump = true,
        rotate = true,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {{1, 0.85, 0.30, 1}, {1, 0.92, 0.55, 1}},
        colour_cycle = 1.5,
        shadow = true,
        align = "center",
    })

    self.rowDynas = {}
    for i, src in ipairs(self.sources) do
        self.rowDynas[i] = DynaText.new({
            text = src.label or "",
            fontSize = 14,
            bump = false,
            rotate = false,
            pop_in = 0.35,
            pop_in_rate = 6,
            spacing = 1,
            colours = { src.color or {0.95, 0.92, 0.88, 1} },
            shadow = true,
            align = "left",
        })
    end

    self.scoreText = nil
    if self.scoreData then
        local sd = self.scoreData
        self.scoreText = DynaText.new({
            text = ("+%d PONTOS"):format(sd.total),
            fontSize = 15,
            bump = false,
            pop_in = 0.4,
            pop_in_rate = 5,
            spacing = 1,
            colours = {{1, 0.85, 0.30, 1}, {0.95, 0.92, 0.88, 1}},
            colour_cycle = 2.0,
            shadow = true,
            align = "center",
        })
    end

    self.totalText = DynaText.new({
        text = "TOTAL: $" .. self.totalDollars,
        fontSize = 18,
        bump = true,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {{1, 0.92, 0.40, 1}},
        shadow = true,
        align = "center",
    })
end

-- Agenda toda a timeline via EventManager (não-blocking, paralelo).
function RoundEvalScreen:_scheduleTimeline()
    -- 1) Slide-in painel.
    EventManager.parallelEase(self, "slideOffsetY", 0, PHASES.SLIDE_IN, "smooth")

    -- 1.5) Banner de score (F3) pop logo após o painel assentar.
    if self.scoreData then
        EventManager.parallel(PHASES.SLIDE_IN + 0.10, function()
            self._scoreVisible = true
            Sfx.play("comboTrigger", { volume = 0.7 })
            if _G.jiggleScreen then _G.jiggleScreen(0.3) end
        end)
    end

    -- 2) Cada source aparece em cascata.
    local t = PHASES.SLIDE_IN + PHASES.PRE_ROW_DELAY
        + (self.scoreData and 0.35 or 0)
    for i, src in ipairs(self.sources) do
        local rowAt = t

        -- Label entra (DynaText pop-in inicia).
        EventManager.parallel(rowAt, function()
            self._rowVisible[i] = true
            -- F11.5: row entry usa coinTotalThud (chunky thump), pitch crescente
            -- por source pra dar sensação de cascade.
            local pitch = 0.95 + (i - 1) * 0.06
            Sfx.play("coinTotalThud", { pitch = pitch })
            if _G.jiggleScreen then _G.jiggleScreen(0.18) end
        end)

        -- Coins individuais (se dollars <= 60). Caso contrário, valor único.
        local dollars = src.dollars or 0
        if dollars <= PHASES.BIG_THRESHOLD then
            for c = 1, dollars do
                EventManager.parallel(rowAt + 0.20 + c * PHASES.COIN_STAGGER, function()
                    self.coinsAccumulated = self.coinsAccumulated + 1
                    self._rowCoins[i] = (self._rowCoins[i] or 0) + 1
                    self._totalPulseTimer = 0.25  -- pulse no TOTAL
                    -- F11.5: cada coin individual usa coinClink (warm wooden thock).
                    -- Pitch random pra cada uma soar levemente diferente.
                    Sfx.play("coinClink", {
                        pitch = 0.85 + math.random() * 0.3,
                        volume = 0.6,
                    })
                    if _G.jiggleScreen then _G.jiggleScreen(0.04) end
                end)
            end
            t = rowAt + 0.20 + dollars * PHASES.COIN_STAGGER + PHASES.ROW_DELAY
        else
            EventManager.parallel(rowAt + 0.4, function()
                self.coinsAccumulated = self.coinsAccumulated + dollars
                self._rowCoins[i] = dollars
                self._totalPulseTimer = 0.4
                -- F11.5: pile big = thud com volume cheio.
                Sfx.play("coinTotalThud", { pitch = 1.0, volume = 0.85 })
            end)
            t = rowAt + 0.4 + PHASES.ROW_DELAY
        end
    end

    -- 3) Botão "RESGATAR" pop-in laranja após últimas coins.
    EventManager.parallel(t + PHASES.BUTTON_DELAY, function()
        self:_buildCashOutButton()
        self.cashOutReady = true
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(0.45, 0.35)
        end
        if _G.jiggleScreen then _G.jiggleScreen(0.8) end
        -- F11.5: cashOutChime (warm brass swell) anuncia que botão Resgatar entrou.
        Sfx.play("cashOutChime")
    end)
end

function RoundEvalScreen:_buildCashOutButton()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    -- Reduzido de 360×64 → 240×42 (F11.2). Estava grande demais e visualmente
    -- desproporcional ao painel.
    local btnW = 240
    local btnH = 42
    local btnX = sw * 0.5 - btnW * 0.5
    local btnY = sh * 0.78
    self.cashOutButton = Button:new(
        btnX, btnY, btnW, btnH,
        "RESGATAR  $" .. self.totalDollars,
        function() self:_onCashOutClick() end,
        nil, 12
    )
    if self.cashOutButton.setIcon then
        self.cashOutButton:setIcon("coin")
    end
end

function RoundEvalScreen:_onCashOutClick()
    if self._closing then return end
    self._closing = true
    -- F12.2: cashOutChime já toca quando o botão Resgatar entra (signal "ready").
    -- Tocar de novo no click duplicava o som. Click usa coinTotalThud + flash
    -- + jiggle pra feedback distinto.
    Sfx.play("coinTotalThud", { pitch = 1.2, volume = 0.85 })
    if _G.jiggleScreen then _G.jiggleScreen(1.2) end
    if FlashShader and FlashShader.trigger then
        FlashShader.trigger(0.65, 0.4)
    end

    -- Aplica ouro no economySystem (equivalente Balatro ease_dollars).
    if self.game and self.game.economySystem and self.game.economySystem.earnGold then
        self.game.economySystem:earnGold(self.totalDollars, "round_eval")
    end

    -- Slide-out + callback.
    local cb = self.onCashOut
    EventManager.parallelEase(self, "slideOffsetY", love.graphics.getHeight(), 0.45, "smooth")
    EventManager.after(0.5, function()
        self:hide()
        if cb then cb() end
    end)
end

function RoundEvalScreen:update(dt)
    if not self.visible then return end

    if self.titleText then self.titleText:update(dt) end
    if self.scoreText then self.scoreText:update(dt) end
    if self.totalText then self.totalText:update(dt) end
    for _, dyna in ipairs(self.rowDynas) do dyna:update(dt) end

    if self.cashOutButton then self.cashOutButton:update(dt) end

    if self._totalPulseTimer > 0 then
        self._totalPulseTimer = math.max(0, self._totalPulseTimer - dt)
        if self.totalText and self._totalPulseTimer > 0.2 then
            self.totalText:pulse(0.2, 0.2)
        end
    end
end

function RoundEvalScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Backdrop sépia escuro (não preto puro pra não sumir o gameplay atrás).
    love.graphics.setColor(0.05, 0.04, 0.08, 0.65)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Painel central (slide com offset).
    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    -- Painel principal (Balatro pattern: dark bg, gold border, embossed).
    local panelW = math.floor(sw * 0.55)
    local panelH = math.floor(sh * 0.62)
    local panelX = math.floor((sw - panelW) * 0.5)
    local panelY = math.floor(sh * 0.10)

    -- Sombra do painel.
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 8, 8)
    -- Painel.
    love.graphics.setColor(0.12, 0.10, 0.08, 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    -- Highlight bevel topo (linha clara fina) — F11.2 detalhe profissional.
    love.graphics.setColor(1, 0.88, 0.55, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 8, panelY + 2, panelX + panelW - 8, panelY + 2)
    -- Borda dourada externa.
    love.graphics.setColor(Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    -- Borda interna mais escura.
    love.graphics.setColor(Palette.AGED_GOLD_DARK or {0.45, 0.32, 0.10, 1})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 4, panelY + 4, panelW - 8, panelH - 8, 6, 6)

    -- Corner ornaments (F11.2): 4 cantos com triângulos dourados.
    do
        local cornerSize = 14
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
        love.graphics.setLineWidth(2)
        local px = panelX
        local py = panelY
        local pw = panelW
        local ph = panelH
        -- Top-left
        love.graphics.line(px + 3, py + cornerSize, px + 3, py + 3, px + cornerSize, py + 3)
        -- Top-right
        love.graphics.line(px + pw - cornerSize, py + 3, px + pw - 3, py + 3, px + pw - 3, py + cornerSize)
        -- Bottom-left
        love.graphics.line(px + 3, py + ph - cornerSize, px + 3, py + ph - 3, px + cornerSize, py + ph - 3)
        -- Bottom-right
        love.graphics.line(px + pw - cornerSize, py + ph - 3, px + pw - 3, py + ph - 3, px + pw - 3, py + ph - cornerSize)
    end

    -- Título DynaText.
    if self.titleText then
        self.titleText:draw(sw * 0.5, panelY + 32)
    end

    -- Linha separadora dourada após título.
    love.graphics.setColor(0.78, 0.65, 0.20, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 24, panelY + 60, panelX + panelW - 24, panelY + 60)

    -- F3: bloco de pontuação da batalha — total grande + recibo do que o
    -- jogador FEZ pra ganhar cada bônus (feedback: fórmula era críptica).
    local scoreBlockH = 0
    if self.scoreData and self._scoreVisible then
        if self.scoreText then
            self.scoreText:draw(sw * 0.5, panelY + 80)
        end
        local lines = self.scoreData.breakdown or {}
        local lf = FontManager.getFont(10)
        love.graphics.setFont(lf)
        local ly = panelY + 98
        local lx = panelX + 60
        local rx = panelX + panelW - 60
        for _, item in ipairs(lines) do
            if item.bad then
                love.graphics.setColor(0.85, 0.45, 0.35, 0.95)
            else
                love.graphics.setColor(0.82, 0.78, 0.70, 0.95)
            end
            love.graphics.print(item.label, lx, ly)
            if item.bad then
                love.graphics.setColor(0.9, 0.4, 0.3, 1)
            else
                love.graphics.setColor(1, 0.85, 0.30, 1)
            end
            love.graphics.print(item.value, rx - lf:getWidth(item.value), ly)
            ly = ly + 16
        end
        scoreBlockH = 34 + #lines * 16
        -- separador fecha o bloco de score antes das rows de ouro
        love.graphics.setColor(0.78, 0.65, 0.20, 0.4)
        love.graphics.setLineWidth(1)
        love.graphics.line(panelX + 24, ly + 4, panelX + panelW - 24, ly + 4)
    elseif self.scoreData then
        scoreBlockH = 34 + #(self.scoreData.breakdown or {}) * 16
    end

    -- Rows de ouro: descem pra abrir espaço pro bloco de score.
    local rowY = panelY + 90 + scoreBlockH
    local rowH = 36
    local labelX = panelX + 36
    local coinsX = panelX + panelW - 36

    for i, src in ipairs(self.sources) do
        if self._rowVisible[i] then
            -- Label esquerda.
            if self.rowDynas[i] then
                self.rowDynas[i]:draw(labelX + 70, rowY + rowH * 0.5)
            end

            -- Coins/dollars direita: cada $ é um pequeno disco animado.
            local coinsCount = self._rowCoins[i] or 0
            local dollars = src.dollars or 0
            if dollars <= PHASES.BIG_THRESHOLD then
                -- Render N $ como string crescente.
                local coinsTxt = string.rep("$", coinsCount)
                local font = FontManager.getFont(15)
                love.graphics.setFont(font)
                local color = src.color or {1, 0.85, 0.30, 1}
                love.graphics.setColor(color)
                local tw = font:getWidth(coinsTxt)
                love.graphics.print(coinsTxt, coinsX - tw, rowY + rowH * 0.5 - font:getHeight() * 0.5)
            else
                -- Render valor único "$N".
                local txt = "$" .. coinsCount
                local font = FontManager.getFont(18)
                love.graphics.setFont(font)
                love.graphics.setColor(src.color or {1, 0.85, 0.30, 1})
                local tw = font:getWidth(txt)
                love.graphics.print(txt, coinsX - tw, rowY + rowH * 0.5 - font:getHeight() * 0.5)
            end
        end

        rowY = rowY + rowH + 4
    end

    -- Linha separadora antes do total.
    love.graphics.setColor(0.78, 0.65, 0.20, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 60, rowY + 8, panelX + panelW - 60, rowY + 8)

    -- TOTAL grande.
    if self.totalText then
        self.totalText:setText("TOTAL: $" .. self.coinsAccumulated)
        self.totalText:draw(sw * 0.5, rowY + 36)
    end

    love.graphics.pop()  -- fim do slide

    -- Botão Resgatar (FORA do slide — sempre na posição absoluta).
    if self.cashOutButton and self.cashOutReady then
        -- Glow laranja ao redor do botão (Balatro G.C.ORANGE).
        local btn = self.cashOutButton
        love.graphics.setColor(0.99, 0.64, 0.0, 0.4)
        love.graphics.rectangle("fill", btn.x - 6, btn.y - 6, btn.width + 12, btn.height + 12, 12, 12)
        love.graphics.setColor(1, 1, 1, 1)
        btn:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RoundEvalScreen:mousepressed(x, y, button)
    if not self.visible or self._closing then return false end
    if self.cashOutButton and self.cashOutReady then
        if self.cashOutButton:mousepressed(x, y, button) then return true end
    end
    return true  -- consome cliques na área
end

function RoundEvalScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.cashOutButton and self.cashOutReady then
        if self.cashOutButton:mousereleased(x, y, button) then return true end
    end
    return false
end

function RoundEvalScreen:keypressed(key)
    if not self.visible then return false end
    if (key == "return" or key == "space") and self.cashOutReady and not self._closing then
        self:_onCashOutClick()
        return true
    end
    return false
end

return RoundEvalScreen
