-- components/TopBar.lua
-- Barra superior com informações do jogo (ouro, deck, config).
-- Pixel chrome: ink fill + borda dourada + ícones via IconLoader.

local FontManager = require("src.ui.FontManager")
local ImageCache  = require("src.ui.ImageCache")
local IconLoader  = require("src.ui.IconLoader")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")
local I18n        = require("src.i18n.I18n")
local ValueEasing = require("src.ui.ValueEasing")

local TopBar = {}
TopBar.__index = TopBar

function TopBar:new()
    local instance = setmetatable({}, TopBar)

    instance.visible = true
    instance.height = 52

    -- Ícones PNG legados (coin/deck ainda carregam do assets/icons/)
    instance.coinIcon = ImageCache.get("assets/icons/coin.png")
    instance.deckIcon = ImageCache.get("assets/icons/deck.png")

    -- Gear (pixel) via IconLoader — substitui config.png
    instance.gearIcon = IconLoader.get("gear")

    instance.game = nil

    instance.configHover = 0   -- 0..1 suavizado (fade do hover)
    instance.configSpin = 0    -- ângulo acumulado da engrenagem (nunca snapa)
    instance.isConfigHovered = false

    -- Valores eased pra display de gold/deck suavemente mutando.
    instance.disp = {}

    return instance
end

function TopBar:setGame(game)
    self.game = game
end

function TopBar:update(dt, game)
    if not self.visible then return end

    local mx, my = love.mouse.getPosition()
    self.isConfigHovered = self:isConfigIconClicked(mx, my)

    -- Hover da engrenagem: valor SUAVIZADO 0..1 (placa/escala fazem fade)
    -- e giro ACUMULADO — acelera no hover, desacelera ao sair (sem snap).
    local hoverTarget = self.isConfigHovered and 1 or 0
    self.configHover = self.configHover
        + (hoverTarget - self.configHover) * math.min(1, dt * 12)
    self.configSpin = self.configSpin + dt * 3.2 * self.configHover

    -- Ease gold toward real (ease_dollars-style do Balatro). Counter sobe/desce
    -- suave em vez de saltar quando ganhar/gastar ouro.
    local g = game or self.game
    -- Adota o game ATUAL (returnToMenu recria o Game — sem isto a barra fica
    -- presa na instância morta: ouro congelado e engrenagem no aviso).
    if g and g ~= self.game then self.game = g end
    if g and g.economySystem then
        local realGold = g.economySystem.currentGold or 0
        -- Detecta delta de gold (ganho/gasto) e dispara micro-jiggle Balatro-style
        -- (engine/ui.lua:990 pattern: cada evento monetário empurra o accumulator).
        -- Skip primeiro frame onde _lastGold é nil pra não jigglar no boot.
        if self._lastGold and self._lastGold ~= realGold then
            if _G.jiggleScreen then
                local delta = math.abs(realGold - self._lastGold)
                local amt = math.min(0.6, 0.05 + delta * 0.02) -- cap pra não enjoar em ganhos grandes
                _G.jiggleScreen(amt)
            end
            -- Flash direcional no NÚMERO (padrão TopPanel do StS: verde ao
            -- ganhar, vermelho ao gastar — a direção da mudança é informação).
            self._goldFlash = {
                dir = (realGold > self._lastGold) and 1 or -1,
                t = 0.6,
            }
        end
        if self._goldFlash then
            self._goldFlash.t = self._goldFlash.t - dt
            if self._goldFlash.t <= 0 then self._goldFlash = nil end
        end
        self._lastGold = realGold
        ValueEasing.tick(self.disp, "gold", realGold, dt, 6)
    end
end

-- Layout CENTRALIZADO da barra: o tubo CRT distorce os cantos em telas
-- largas — todo o conteúdo (ouro/deck/score/progresso/engrenagem) vive num
-- grupo central, onde o vidro é plano e legível (pedido playtest Jul/2026).
-- FONTE ÚNICA de posições: draw, hover zones e mousepressed leem daqui.
--
-- Larguras MEDIDAS pelos textos do locale atual com números-modelo largos:
-- nenhum idioma estoura o bloco e o layout não "dança" quando o valor muda.
function TopBar:_layout()
    local sw = love.graphics.getWidth()
    local f14 = FontManager.getFont(14)
    local f9 = FontManager.getFont(9)
    -- 50 = offset REAL onde o texto é desenhado nos blocos (x+50 no draw) —
    -- com 36 o texto invadia ~14px do gap do bloco vizinho.
    local ICON_W = 50
    local PAD_R = 14    -- respiro à direita do texto

    local blocks = {}
    local function add(key, line1, line2)
        local w = math.max(f14:getWidth(line1 or ""), f9:getWidth(line2 or ""))
        table.insert(blocks, { key = key, w = ICON_W + math.ceil(w) + PAD_R })
    end

    if self.game and self.game.economySystem then
        add("gold", "$88888", I18n.t("top_bar.interest_suffix", { amount = 8 }))
    end
    if self.game and self.game.deck then
        add("deck", I18n.t("top_bar.deck_cards", { n = 88 }),
            I18n.t("top_bar.hand_suffix", { n = 8 }))
    end
    if self.game and self.game.scoreSystem then
        local label = I18n.t("top_bar.score_record")
        local label2 = I18n.t("top_bar.score_label")
        if f9:getWidth(label2) > f9:getWidth(label) then label = label2 end
        add("score", "888888", label)
    end
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if run then
        local l1 = run.endlessMode and I18n.t("top_bar.endless")
            or I18n.t("top_bar.act", { n = 8 })
        add("progress", l1, I18n.t("top_bar.floor", { x = 8, total = 8 }))
    end
    -- (engrenagem fica FORA do grupo: fixa no canto direito — _getConfigRect)

    local gap = 22
    local total = gap * math.max(0, #blocks - 1)
    for _, b in ipairs(blocks) do total = total + b.w end

    local x = math.max(16, math.floor((sw - total) / 2))
    local out = {}
    for _, b in ipairs(blocks) do
        out[b.key] = { x = x, w = b.w }
        x = x + b.w + gap
    end
    return out
end

-- Zona interativa da barra: highlight dourado sutil no hover + tooltip via
-- StatusTooltip (show() agenda; main.lua desenha no fim do frame, por cima).
-- Chamar ANTES de desenhar o conteúdo do bloco (o highlight fica por baixo).
function TopBar:_hoverZone(x0, w, tipName, ctx)
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x0 and mx <= x0 + w and my >= 0 and my <= self.height
    if hovered then
        PixelCanvas.rect(math.floor(x0), 3, math.floor(w), self.height - 8,
            { 0.32, 0.26, 0.11, 0.38 })
        if tipName then
            local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
            if okST and StatusTooltip.show then
                StatusTooltip.show(tipName, mx, my, ctx)
            end
        end
    end
    return hovered
end

function TopBar:draw()
    if not self.visible then return end

    local screenWidth = love.graphics.getWidth()

    -- Fundo pixel: ink fill + borda dourada dupla
    -- Fundo mais ESCURO que PANEL_FILL: sob o CRT (scanlines+vinheta) o
    -- dourado precisa de mais contraste (feedback: "difícil de enxergar").
    PixelCanvas.rect(0, 0, screenWidth, self.height, { 0.07, 0.055, 0.04, 0.98 })
    PixelCanvas.hline(0, self.height,     screenWidth, Palette.AGED_GOLD)
    PixelCanvas.hline(0, self.height + 1, screenWidth, Palette.AGED_GOLD_DARK)

    -- Rivets dourados espaçados (rectangles 4x4 inteiros)
    for i = 0, 4 do
        local x = 20 + math.floor(i * (screenWidth - 40) / 4)
        PixelCanvas.rect(x - 2, self.height - 6, 4, 4, Palette.AGED_GOLD)
        PixelCanvas.pixel(x - 1, self.height - 5, Palette.AGED_GOLD_LIGHT)
    end

    self:drawGameInfo()
    self:drawConfigIcon()
end

function TopBar:drawGameInfo()
    local iconScale = 0.05
    local centerY = math.floor(self.height / 2)
    local L = self:_layout()

    -- Moeda
    if self.game and self.game.economySystem and L.gold then
        local coinX = L.gold.x
        local coinY = centerY - 22

        -- Zona interativa (highlight + tooltip com breakdown dos juros).
        local interestGold = self.game.economySystem:calculateInterest()
        self:_hoverZone(coinX - 6, L.gold.w, "topbar_gold", {
            gold = self.game.economySystem.currentGold or 0,
            interest = math.floor(interestGold),
        })

        love.graphics.setColor(1, 1, 1, 1)
        -- Ambient pulse Balatro-style (engine/text.lua:228 pulse pattern):
        -- ícone ondula scale ±3% em sin lento (0.7 rad/s) pra não ficar estático.
        -- Reduced motion zera a oscilação.
        local rm = _G.gameSettings and _G.gameSettings.reducedMotion
        local pulse = rm and 1 or (1 + math.sin(love.timer.getTime() * 0.7) * 0.03)
        local cw, ch = self.coinIcon:getWidth(), self.coinIcon:getHeight()
        local scaledIcon = iconScale * pulse
        love.graphics.draw(self.coinIcon, coinX + cw * iconScale * 0.5, coinY + ch * iconScale * 0.5, 0,
                           scaledIcon, scaledIcon, cw / 2, ch / 2)

        -- Cor do número: flash direcional (verde subiu / vermelho desceu)
        -- decaindo de volta pro dourado — padrão TopPanel do StS.
        local base = Palette.AGED_GOLD_LIGHT
        if self._goldFlash then
            local k = math.min(1, self._goldFlash.t / 0.6)
            local flash = self._goldFlash.dir > 0
                and { 0.45, 0.90, 0.40 }   -- verde: ganhou
                or  { 0.95, 0.35, 0.30 }   -- vermelho: gastou/perdeu
            love.graphics.setColor(
                base[1] + (flash[1] - base[1]) * k,
                base[2] + (flash[2] - base[2]) * k,
                base[3] + (flash[3] - base[3]) * k, 1)
        else
            Palette.set(base)
        end
        love.graphics.setFont(FontManager.getFont(14))
        -- Display eased pra counter Balatro-style (sobe/desce número suave)
        local goldDisp = math.floor((self.disp.gold or self.game.economySystem.currentGold or 0) + 0.001)
        local goldText = "$" .. goldDisp
        love.graphics.print(goldText, coinX + 50, centerY - 10)

        if interestGold > 0 then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(9))
            local interestText = I18n.t("top_bar.interest_suffix", { amount = math.floor(interestGold) })
            love.graphics.print(interestText, coinX + 50, centerY + 6)
        end
    end

    -- Deck
    if self.game and self.game.deck and L.deck then
        local deckX = L.deck.x
        local deckY = centerY - 22

        self:_hoverZone(deckX - 6, L.deck.w, "topbar_deck", {
            deck = #self.game.deck,
            hand = self.game.hand and #self.game.hand or 0,
        })

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.deckIcon, deckX, deckY, 0, iconScale, iconScale)

        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(FontManager.getFont(14))
        local deckSize = #self.game.deck
        local deckText = I18n.t("top_bar.deck_cards", { n = deckSize })
        love.graphics.print(deckText, deckX + 50, centerY - 10)

        if self.game.hand then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(9))
            local handSize = #self.game.hand
            local handText = I18n.t("top_bar.hand_suffix", { n = handSize })
            love.graphics.print(handText, deckX + 50, centerY + 6)
        end
    end

    -- Score da run (F3 gameplay-overhaul): TINTA×SELO acumulado, sempre
    -- visível — o "quero bater meu recorde" do Balatro. Vira dourado pulsante
    -- pelo resto da run quando o recorde histórico é cruzado.
    if self.game and self.game.scoreSystem and L.score then
        local scoreX = L.score.x
        local IconLoader = require("src.ui.IconLoader")

        -- Zona interativa (tooltip de score já existente, agora com highlight).
        local okPS, ProfileStats = pcall(require, "engine.ProfileStats")
        self:_hoverZone(scoreX - 6, L.score.w, "score", {
            best = (okPS and ProfileStats.get().bestScore) or 0,
        })

        local icon = IconLoader.get("star")
        if icon and icon.draw and icon.size then
            local sc = 26 / icon.size.w
            love.graphics.setColor(1, 1, 1, 1)
            icon.draw(scoreX, centerY - 14, sc)
        end
        local record = self.game.scoreSystem.recordBroken
        if record then
            local pulse = 0.85 + math.sin(love.timer.getTime() * 2.5) * 0.15
            local g = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(g[1] * pulse, g[2] * pulse, g[3], 1)
        else
            Palette.set(Palette.PARCHMENT_LIGHT)
        end
        love.graphics.setFont(FontManager.getFont(14))
        love.graphics.print(tostring(self.game.score or 0), scoreX + 34, centerY - 10)
        Palette.set(record and Palette.AGED_GOLD or Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(9))
        love.graphics.print(record and I18n.t("top_bar.score_record")
            or I18n.t("top_bar.score_label"), scoreX + 34, centerY + 6)
    end

    -- Progresso da run: "ATO N" + "andar X/8" (StS TopPanel: onde estou e o
    -- que vem por aí SEMPRE visíveis). Some fora do run mode (modo clássico).
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if run and L.progress then
        local progressX = L.progress.x
        local MapManager = require("src.systems.MapManager")
        local total = MapManager.FLOORS_PER_ACT
        local act = run.actNumber or 1
        local floorIn = run.floorInAct or 1

        self:_hoverZone(progressX - 6, L.progress.w, "topbar_progress", {
            act = act, floor = floorIn, total = total,
        })

        local icon = IconLoader.get("scroll")
        if icon and icon.draw and icon.size then
            local sc = 26 / icon.size.w
            love.graphics.setColor(1, 1, 1, 1)
            icon.draw(progressX, centerY - 14, sc)
        end

        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(FontManager.getFont(14))
        local actText = run.endlessMode and I18n.t("top_bar.endless")
            or I18n.t("top_bar.act", { n = act })
        love.graphics.print(actText, progressX + 34, centerY - 10)

        Palette.set(Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(9))
        love.graphics.print(I18n.t("top_bar.floor", { x = floorIn, total = total }),
            progressX + 34, centerY + 6)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:_getConfigRect()
    local iconPxSize = 32                                -- pixel size on screen
    -- Engrenagem FIXA no canto direito (pedido do dono Jul/2026). Margem de
    -- 30px: bezel do CRT come 20px e a placa de hover cresce +5px além do
    -- ícone — assim nada fica atrás do gabinete.
    local configX = love.graphics.getWidth() - iconPxSize - 30
    local configY = math.floor((self.height - iconPxSize) / 2)
    return configX, configY, iconPxSize
end

function TopBar:drawConfigIcon()
    local configX, configY, iconPxSize = self:_getConfigRect()
    local centerX = configX + iconPxSize / 2
    local centerY = configY + iconPxSize / 2
    local hover = self.configHover or 0

    -- Placa de hover FIXA (fora da rotação — só a engrenagem gira):
    -- rounded plate dourada + aro claro, ambos com fade pelo hover suave.
    if hover > 0.02 then
        local pad = 5  -- respiro pro gear girado não encostar no aro
        local gd, gl = Palette.AGED_GOLD_DARK, Palette.AGED_GOLD_LIGHT
        PixelCanvas.rectRounded(configX - pad, configY - pad,
            iconPxSize + pad * 2, iconPxSize + pad * 2, 3,
            { gd[1], gd[2], gd[3], 0.55 * hover })
        PixelCanvas.rectRoundedOutline(configX - pad, configY - pad,
            iconPxSize + pad * 2, iconPxSize + pad * 2, 3,
            { gl[1], gl[2], gl[3], 0.9 * hover })
    end
    if self.isConfigHovered then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            local mx, my = love.mouse.getPosition()
            StatusTooltip.show("topbar_config", mx, my)
        end
    end

    -- Só a ENGRENAGEM roda (e cresce um tico no hover). Escala pelo
    -- tamanho REAL do handle (PNG 64×64 do PixelLab ou matriz 16×16
    -- fallback — o hard-code de 16 estouraria o PNG pra 128px).
    local drawSize = iconPxSize * (1 + 0.12 * hover)
    local scale = drawSize / (self.gearIcon.size and self.gearIcon.size.w or 16)
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.configSpin)
    self.gearIcon.draw(-drawSize / 2, -drawSize / 2, scale)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:setDeckClickCallback(cb) self.onDeckClick = cb end

function TopBar:mousepressed(x, y, button)
    if not self.visible then return false end
    if y <= self.height then
        if self:isConfigIconClicked(x, y) then
            -- Engrenagem abre o MENU DE PAUSA (StS-style: continuar /
            -- configurações / salvar e sair / abandonar). Fallback legado:
            -- toggleMenu do game (settings direto) se o pause não existir.
            if _G.togglePauseMenu then
                _G.togglePauseMenu()
            elseif self.game and self.game.toggleMenu then
                self.game:toggleMenu()
            end
            return true
        end
        -- F5 do UI Overhaul: área do deck abre o Deck Viewer global
        local L = self:_layout()
        if self.onDeckClick and L.deck
            and x >= L.deck.x - 6 and x <= L.deck.x + L.deck.w then
            self.onDeckClick()
            return true
        end
        return true
    end
    return false
end

function TopBar:mousereleased(x, y, button)
    if not self.visible then return false end
    return y <= self.height
end

function TopBar:resize() end

function TopBar:isConfigIconClicked(x, y)
    local configX, configY, iconPxSize = self:_getConfigRect()
    return x >= configX and x <= configX + iconPxSize
        and y >= configY and y <= configY + iconPxSize
end

return TopBar
