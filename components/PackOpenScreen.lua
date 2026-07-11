-- components/PackOpenScreen.lua
-- Cinemática de pack opening fiel ao source do Balatro
-- (functions/UI_definitions.lua:1629-1857). Estrutura:
--
--   ┌────────────────── PACK OPEN OVERLAY ──────────────────┐
--   │                                                        │
--   │              [ CardArea linear horizontal ]            │
--   │                                                        │
--   │      ╔══════════════╗              ┌──────┐            │
--   │      ║  PACOTE X    ║              │ SKIP │            │
--   │      ║  Choose 1    ║              └──────┘            │
--   │      ╚══════════════╝                                  │
--   └────────────────────────────────────────────────────────┘
--
-- Sequência:
--   T=0.0   Loja desliza pra baixo (handled by main.lua via callback).
--           Sleeve do pack aparece materializando no centro.
--   T=0.4   Sleeve.explode() — partículas + screen jiggle.
--   T=1.3   Cards spawnam na posição do explode e voam pra CardArea linear,
--           materializando em cascata 80ms.
--   T=1.5   DynaText "Pacote X" + "Choose N" aparecem com pop_in cascade.
--           Skip button fica clicável.
--   <click> Card: dissolve + adiciona ao deck. Skip: cards restantes dissolvem.
--   Close   Loja desliza de volta. onComplete chamado.
--
-- NÃO TEM backdrop preto — segue Balatro (shop sai de cena, pack toma o lugar).

local PackOpenScreen = {}
PackOpenScreen.__index = PackOpenScreen

local Config         = require("src.core.Config")
local Debug          = require("src.core.Debug")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local PixelCanvas    = require("src.ui.PixelCanvas")
local Button         = require("components.Button")
local Sfx            = require("src.systems.Sfx")
local EventManager   = require("engine.EventManager")
local DissolveShader = require("src.ui.DissolveShader")
local FlashShader    = require("src.ui.FlashShader")
local DynaText       = require("src.ui.DynaText")
local PackSleeve     = require("src.ui.PackSleeve")
local ImageCache     = require("src.ui.ImageCache")
local I18n           = require("src.i18n.I18n")

-- Configuração de timeline (segundos).
local TIMING = {
    sleeveAppear   = 0.0,    -- sleeve materializa no centro
    sleeveExplode  = 0.7,    -- sleeve.explode() — começa partículas
    cardSpawn      = 1.3,    -- cards começam a spawnar (após explode peak)
    cardStagger    = 0.10,   -- delay entre cada card materializar
    titleAppear    = 1.5,    -- DynaText do nome+choose entra com pop_in
    skipEnable     = 1.7,    -- skip button fica clicável
}

-- Pose do sleeve = mesma Y da linha de cards. Quando o pack explode, cards
-- materializam ali mesmo e se espalham horizontalmente. Padrão Balatro
-- (UI_definitions.lua:1631-1635 — CardArea fica na posição da hand).
local function sleeveCenter()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    return sw * 0.5, sh * 0.42
end

-- Layout dos cards: linha horizontal centralizada NO MESMO Y do sleeve. O
-- explode faz o pack sumir e os cards spawnam exatamente ali.
local function cardLayout(n, cardW, cardH)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local spacing = cardW * 0.12
    local totalW = cardW * n + spacing * math.max(0, n - 1)
    local startX = (sw - totalW) * 0.5
    -- Y: mesmo do sleeve, descontado meio cardH pra centralizar carta no Y do sleeve.
    local y = sh * 0.42 - cardH * 0.5
    return startX, y, spacing
end

function PackOpenScreen:new()
    local instance = setmetatable({}, PackOpenScreen)
    instance.visible = false
    instance.pack = nil
    instance.onComplete = nil
    instance.choicesRemaining = 0
    instance.skipButton = nil
    instance._closing = false
    instance._selectedCards = {}
    instance._sleeveDissolve = 1     -- 1 = invisível, 0 = sólido
    instance._sleeveExploded = false
    instance._sleeveScale = 1
    instance._sleeveTilt = 0          -- pre-explode wobble (rad)
    instance._burstScale = 0           -- 0 → 1.6 durante explode (PixelLab burst overlay)
    instance._burstAlpha = 0           -- 0 → 0.95 → 0 (peak no explode peak)
    instance._burstRotation = 0        -- gira durante explode
    instance._cardsReady = false
    -- F3: card selection 3-zone (Balatro pattern, replica CardRewardScreen).
    instance.selectedCardIdx = nil
    instance.selectedCard = nil
    instance.selectButton = nil
    instance._selectionAnim = 0
    instance.titleText = nil          -- DynaText do nome do pack
    instance.chooseText = nil         -- DynaText "Choose N"
    instance._skipReady = false
    return instance
end

-- pack: { kind, size, choose, instances }
-- onComplete(selectedList) — selectedList = lista de cartas escolhidas (pode ser vazia).
function PackOpenScreen:show(pack, onComplete)
    self.visible = true
    self.pack = pack
    self.onComplete = onComplete
    self.choicesRemaining = pack.choose or 1
    self._closing = false
    self._selectedCards = {}
    self._sleeveDissolve = 1
    self._sleeveExploded = false
    self._sleeveScale = 1
    self._sleeveTilt = 0
    self._burstScale = 0
    self._burstAlpha = 0
    self._burstRotation = 0
    self._cardsReady = false
    self._skipReady = false
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self._selectionAnim = 0

    self:_layoutCards()
    self:_buildSkipButton()
    self:_buildTitleTexts()
    self:_scheduleTimeline()

    -- F11.5: shopOpen (cozy chime) na entrada — não duplica com pack-seal-break
    -- que vem em sleeve.explode (T=0.7s).
    Sfx.play("shopOpen")
    Debug.log("[PackOpenScreen] Abrindo pacote", pack.kind, "size", #pack.instances, "choose", self.choicesRemaining)
end

function PackOpenScreen:hide()
    self.visible = false
    self.pack = nil
    self.skipButton = nil
    self.titleText = nil
    self.chooseText = nil
    self._selectedCards = {}
end

function PackOpenScreen:isVisible() return self.visible end

-- Recomputa todo o layout em resposta a resize. Mantém estado de seleção
-- (selectedCardIdx) intacto — só recalcula posições de cartas + skip button.
function PackOpenScreen:resize()
    if not self.visible or not self.pack then return end
    self:_layoutCards()
    if self._buildSkipButton then self:_buildSkipButton() end
    -- Mini-buttons de seleção são reposicionados a cada frame em
    -- _drawCardSelectionOverlay — só precisamos garantir que self.selectedCard
    -- ainda existe. Layout muda mas card permanece selecionada.
end

function PackOpenScreen:_layoutCards()
    if not self.pack or not self.pack.instances then return end
    local n = #self.pack.instances
    if n == 0 then return end

    local first = self.pack.instances[1]
    local cardW = first.image:getWidth() * (Config.Cards.BASE_SCALE or 1)
    local cardH = first.image:getHeight() * (Config.Cards.BASE_SCALE or 1)

    local startX, baseY, spacing = cardLayout(n, cardW, cardH)
    local cx, cy = sleeveCenter()

    -- Salva final positions pra _scheduleTimeline poder mover via setTargetPos.
    self._finalCardPositions = {}

    for i, card in ipairs(self.pack.instances) do
        local finalX = startX + (i - 1) * (cardW + spacing)
        local finalY = baseY
        self._finalCardPositions[i] = { x = finalX, y = finalY }

        -- Cards começam SNAP na posição do sleeve. setRenderPos zera a
        -- interpolação interna — primeira chamada não fica "voando do nada".
        local sleeveCardX = cx - cardW * 0.5
        local sleeveCardY = cy - cardH * 0.5
        if card.setRenderPos then
            card:setRenderPos(sleeveCardX, sleeveCardY)
        else
            card.renderX = sleeveCardX
            card.renderY = sleeveCardY
            card.targetX = sleeveCardX
            card.targetY = sleeveCardY
        end
        card.x = sleeveCardX
        card.y = sleeveCardY
        card._posInitialized = true

        card.baseScale = Config.Cards.BASE_SCALE
        card.currentScale = Config.Cards.BASE_SCALE
        card.targetScale = Config.Cards.HOVER_SCALE
        card.isRewardCard = true
        card._packIndex = i
        card.dissolve = 1
        card.dissolve_colours = DissolveShader.palette("booster")
    end
end

function PackOpenScreen:_buildSkipButton()
    -- Posição: column à direita do footer, alinhado verticalmente com o título.
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    -- F11.2: reduzido de 110×48 → 90×34 pra ficar discreto, não disputar atenção com cards.
    local btnW, btnH = 90, 34
    -- Footer fica abaixo dos cards. Skip fica em column à direita do título.
    local footerY = sh * 0.78
    local x = sw * 0.78
    self.skipButton = Button:new(x, footerY, btnW, btnH,
        require("src.i18n.I18n").t("common.skip"),
        function() self:close() end,
        nil, 12)
    self.skipButton:setIcon("x_close")
    self.skipButton:setEnabled(false)  -- só habilita após delay
end

function PackOpenScreen:_buildTitleTexts()
    -- Title: nome do pack ("Pacote Padrão", etc).
    local kindLabel = self:_kindLabel()
    self.titleText = DynaText.new({
        text = kindLabel,
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

    -- Choose N (atualiza dinamicamente).
    self.chooseText = DynaText.new({
        text = "Escolha " .. tostring(self.choicesRemaining),
        fontSize = 14,
        bump = true,
        rotate = true,
        pop_in = 0.7,
        pop_in_rate = 4,
        spacing = 1,
        colours = {{0.95, 0.92, 0.88, 1}},
        shadow = true,
        align = "center",
    })
end

function PackOpenScreen:_kindLabel()
    local k = self.pack and self.pack.kind or "Standard"
    local labels = {
        Standard = "Pacote Padrão",
        Buffoon = "Pacote Bufão",
        Arcana = "Pacote Arcano",
        Celestial = "Pacote Celestial",
        Spectral = "Pacote Espectral",
    }
    return labels[k] or ("Pacote " .. k)
end

-- Agenda toda a timeline via EventManager.parallel — não-blocking, paralela.
function PackOpenScreen:_scheduleTimeline()
    -- T=0.0: sleeve materializa (dissolve 1 → 0).
    EventManager.parallelEase(self, "_sleeveDissolve", 0, 0.4, "smooth")

    -- T=0.45-0.7: PRÉ-EXPLODE wobble (Balatro card.lua:explode pattern). Sleeve
    -- treme em rotação senoidal antes de estourar — sinaliza a iminência da
    -- explosão e dá drama extra.
    EventManager.parallel(0.45, function()
        if _G.jiggleScreen then _G.jiggleScreen(0.4) end
    end)

    -- T=0.7: explode com flash + jiggle + burst overlay.
    EventManager.parallel(TIMING.sleeveExplode, function()
        self._sleeveExploded = true
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(0.7, 0.4)
        end
        if _G.jiggleScreen then _G.jiggleScreen(1.2) end
        -- F11.5: packSealBreak (chunky paper tear) substitui deckStart genérico no explode.
        Sfx.play("packSealBreak")
        -- Sleeve "explode" — fade rápido com scale up.
        EventManager.parallelEase(self, "_sleeveDissolve", 1, 0.25, "easeOut")
        EventManager.parallelEase(self, "_sleeveScale", 1.4, 0.25, "easeOut")

        -- Burst overlay (sprite PixelLab 'burst.png'): expande de 0 → 1.8 e
        -- alpha pulsa 0 → 0.95 → 0 ao longo de 0.55s, sobreposto ao sleeve
        -- enquanto ele some. Cria a sensação de "explosão de papel" sem
        -- depender só de partículas. Rotação acelerada pra dinamismo.
        EventManager.parallelEase(self, "_burstScale", 1.8, 0.5, "easeOut")
        EventManager.parallelEase(self, "_burstAlpha", 0.95, 0.12, "easeOut")
        EventManager.parallelEase(self, "_burstRotation", math.pi * 0.4, 0.5, "easeOut")
        -- Fade-out do burst começa após o pico (T=0.82).
        EventManager.parallel(0.16, function()
            EventManager.parallelEase(self, "_burstAlpha", 0, 0.4, "easeOut")
        end)
    end)

    -- T=1.3+: cards materializam na posição do sleeve. Quase em paralelo
    -- (delay 0.15s após materialize start) cada card SETA target pra posição
    -- final na linha — updateRender (lerp 16/s) lerpa naturalmente. Resultado:
    -- cards "voam" do sleeve pra linha enquanto materializam.
    for i, card in ipairs(self.pack.instances) do
        local at = TIMING.cardSpawn + (i - 1) * TIMING.cardStagger
        EventManager.parallel(at, function()
            if card.start_materialize then
                card:start_materialize(DissolveShader.palette("booster"), false, 0.7)
            else
                card.dissolve = 0
            end
            -- F11.5: packCardReveal por card que materializa, pitch crescente.
            Sfx.play("packCardReveal", { pitch = 0.9 + (i - 1) * 0.08, volume = 0.6 })
            if _G.jiggleScreen then _G.jiggleScreen(0.15) end
        end)
        -- Alvo da linha disparado um tiquinho depois do materialize start, pra
        -- card já estar visível enquanto voa.
        EventManager.parallel(at + 0.18, function()
            local fp = self._finalCardPositions[i]
            if fp and card.setTargetPos then
                card:setTargetPos(fp.x, fp.y)
            end
        end)
    end

    -- T=last_card + 0.3: marca cards prontos pra hover/click.
    local lastCardAt = TIMING.cardSpawn + (#self.pack.instances - 1) * TIMING.cardStagger + 0.5
    EventManager.parallel(lastCardAt, function()
        self._cardsReady = true
    end)

    -- Skip button habilitado.
    EventManager.parallel(TIMING.skipEnable, function()
        self._skipReady = true
        if self.skipButton then self.skipButton:setEnabled(true) end
    end)
end

function PackOpenScreen:_updateChooseText()
    if not self.chooseText then return end
    local label = self.choicesRemaining > 0
        and ("Escolha " .. tostring(self.choicesRemaining))
        or "Fechando..."
    if self.chooseText.text ~= label then
        self.chooseText:setText(label)
        self.chooseText:pulse(0.4, 0.4)
    end
end

function PackOpenScreen:close()
    if self._closing then return end
    self._closing = true

    -- Cards restantes (não escolhidos) dissolvem com palette booster.
    for _, card in ipairs(self.pack.instances or {}) do
        if not card._chosen and card.start_dissolve then
            card:start_dissolve(DissolveShader.palette("booster"), true, 0.5, false)
        end
    end

    -- Cards escolhidos voam pro canto inferior (deck) antes de dissolver.
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    for _, card in ipairs(self._selectedCards) do
        if card.setTargetPos then
            card:setTargetPos(sw * 0.5, sh + 100)
        end
        if card.start_dissolve then
            EventManager.parallel(0.3, function()
                card:start_dissolve(DissolveShader.palette("booster"), true, 0.5, true)
            end)
        end
    end

    local cb = self.onComplete
    local selected = self._selectedCards
    EventManager.after(0.85, function()
        self:hide()
        if cb then cb(selected) end
    end)
end

function PackOpenScreen:selectCard(card)
    if self._closing or not self._cardsReady then return end
    if not card or card._chosen then return end
    if self.choicesRemaining <= 0 then return end

    card._chosen = true
    table.insert(self._selectedCards, card)
    self.choicesRemaining = self.choicesRemaining - 1

    if card.juice_up then card:juice_up(0.6, 0.18) end
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.35, 0.2) end
    -- F11.5: packCardPick dedicado pra escolha de carta no pack.
    Sfx.play("packCardPick")
    if _G.jiggleScreen then _G.jiggleScreen(0.5) end

    self:_updateChooseText()

    if self.choicesRemaining <= 0 then
        EventManager.after(0.35, function() self:close() end)
    end
end

function PackOpenScreen:update(dt)
    if not self.visible then return end

    if self.titleText then self.titleText:update(dt) end
    if self.chooseText then self.chooseText:update(dt) end

    if self.skipButton then self.skipButton:update(dt) end
    if self.selectButton then self.selectButton:update(dt) end
    if self.cancelButton then self.cancelButton:update(dt) end

    -- Interpola posição (renderX/renderY → targetX/targetY) por frame.
    -- Sem isso, cards ficam parados onde foram inicializados.
    for _, card in ipairs(self.pack.instances) do
        if card and card.updateRender then
            card:updateRender(dt)
        end
    end

    if not self._closing and self._cardsReady then
        for _, card in ipairs(self.pack.instances) do
            if card and card.updateMouse then
                local mx, my = love.mouse.getPosition()
                local interactive = (card.dissolve or 0) < 0.2 and not card._chosen
                card:updateMouse(mx, my, dt, interactive)
            end
        end
    end
end

function PackOpenScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Vinheta sutil pra focar no centro (NÃO é backdrop preto, é gradient leve).
    -- Mantém a loja por trás visível mas levemente escurecida nos cantos.
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 1) Sleeve no centro. Materializa subindo de dissolve=1 (invisível) pra
    -- 0 (visível). No explode (T=0.7), volta pra 1 com scale up — efeito "estouro".
    if self._sleeveDissolve < 0.99 and self.pack then
        local cx, cy = sleeveCenter()
        local scale = self._sleeveScale or 1
        local alpha = 1 - (self._sleeveDissolve or 0)
        PackSleeve.drawAt(self.pack.id, self.pack.kind, cx, cy, scale, alpha)
    end

    -- 1b) Burst overlay (PixelLab burst.png): sobreposto ao sleeve durante
    -- explode. Scale + rotation + alpha animam via _scheduleTimeline.
    -- Desenhado APÓS o sleeve mas ANTES dos cards: explosão "engole" o sleeve,
    -- cards saem pela frente.
    if (self._burstAlpha or 0) > 0.001 then
        local burst = ImageCache.get("assets/sprites/packs/effects/burst.png")
        if burst and burst:getWidth() > 1 then
            local cx, cy = sleeveCenter()
            local bw, bh = burst:getWidth(), burst:getHeight()
            local s = self._burstScale or 0
            love.graphics.setColor(1, 1, 1, self._burstAlpha)
            love.graphics.draw(burst, cx, cy, self._burstRotation or 0,
                               s, s, bw / 2, bh / 2)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- 2) Cards (durante e após explode). Usa renderX/renderY (posição
    -- interpolada via updateRender) pra ficar coerente com o "voo" do sleeve.
    if self.pack and self.pack.instances then
        for _, card in ipairs(self.pack.instances) do
            if card and card.draw then
                local rx = card.renderX or card.x or 0
                local ry = card.renderY or card.y or 0
                card:draw(rx, ry, false, true)
            end
        end
    end

    -- 2b) Hover panels: info à esquerda + preview ampliado à direita da carta
    -- sob o mouse. Aparece SEM precisar clicar (similar ao Balatro card popup).
    self:_drawHoverInfoPanels()

    -- 2c) Selection overlay (CLICK): halo dourado + mini-buttons Balatro-style
    -- (Selecionar + X) compactos sob a carta clicada.
    self:_drawCardSelectionOverlay()

    -- 3) Footer com título e Choose.
    -- Layout (Balatro UI_definitions.lua:1646-1668): título à esquerda do skip,
    -- "Choose N" abaixo do título.
    local footerCenterX = sw * 0.42   -- left-of-center pra deixar espaço pro skip
    local footerY = sh * 0.72

    -- Painel de fundo do footer (banner pergaminho).
    local bannerW = sw * 0.46
    local bannerH = 96
    local bx = footerCenterX - bannerW * 0.5
    local by = footerY - 8
    PixelCanvas.rect(bx, by, bannerW, bannerH, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bannerW, bannerH, Palette.AGED_GOLD_DARK)
    PixelCanvas.rectOutline(bx + 2, by + 2, bannerW - 4, bannerH - 4, Palette.AGED_GOLD)

    -- Título DynaText (nome do pacote).
    if self.titleText then
        self.titleText:draw(footerCenterX, footerY + 28)
    end

    -- "Choose N" DynaText abaixo.
    if self.chooseText then
        self.chooseText:draw(footerCenterX, footerY + 66)
    end

    -- 4) Skip button à direita do banner. Reposicionado em sintonia com novo Y.
    if self.skipButton then
        self.skipButton.x = footerCenterX + bannerW * 0.5 + 16
        self.skipButton.y = footerY + 24
        self.skipButton:draw()
    end

    -- 5) Indicador de cards prontos: hint piscando entre cards e banner.
    if self._cardsReady and not self._closing and self.choicesRemaining > 0 then
        local hintAlpha = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(1, 0.92, 0.55, hintAlpha * 0.85)
        local hintFont = FontManager.getFont(11)
        love.graphics.setFont(hintFont)
        local hint = "Clique em uma carta"
        local hw = hintFont:getWidth(hint)
        love.graphics.print(hint, sw * 0.5 - hw * 0.5, sh * 0.60)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:mousepressed(x, y, button)
    if not self.visible or self._closing then return false end

    if self._skipReady and self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end

    -- Selection mini-buttons (Balatro card.lua:4582-4607: highlight cria use_button child).
    -- Consomem o click ANTES da detecção de clique na carta pra evitar
    -- "click no botão re-seleciona a carta atrás dele".
    if self.selectButton and self.selectButton:mousepressed(x, y, button) then
        return true
    end
    if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then
        return true
    end

    if not self._cardsReady then return true end  -- consome durante intro pra evitar click acidental

    for i, card in ipairs(self.pack.instances or {}) do
        if card and not card._chosen and (card.dissolve or 0) < 0.2 then
            local imgW = card.image:getWidth() * (card.currentScale or 1)
            local imgH = card.image:getHeight() * (card.currentScale or 1)
            local rx = card.renderX or card.x or 0
            local ry = card.renderY or card.y or 0
            if x >= rx and x <= rx + imgW and y >= ry and y <= ry + imgH then
                -- Click numa carta = SELECIONA pra preview (3-zone overlay).
                -- Re-click na mesma OU click no Select button = confirma.
                if self.selectedCardIdx == i then
                    self:_clearCardSelection()
                    self:selectCard(card)  -- consome a escolha
                else
                    self:_setCardSelection(i, card)
                end
                return true
            end
        end
    end

    -- Click fora de cards e button → desselleciona.
    if self.selectedCardIdx then
        self:_clearCardSelection()
    end
    return true  -- consome cliques na área do overlay
end

function PackOpenScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then return true end
    if self.selectButton and self.selectButton:mousereleased(x, y, button) then return true end
    if self.cancelButton and self.cancelButton:mousereleased(x, y, button) then return true end
    return false
end

-- ============================================================================
-- CARD SELECTION (3-zone overlay com info-left + preview-right + button attached)
-- ============================================================================

function PackOpenScreen:_setCardSelection(idx, card)
    self.selectedCardIdx = idx
    self.selectedCard = card

    -- Mini-button compacto Balatro-style (UI_definitions.lua:280 use_card pattern):
    -- "SELECT" sozinho ~50% da largura da carta + botão X cancel ao lado.
    local imgW = card.image:getWidth() * (card.currentScale or 1)
    local imgH = card.image:getHeight() * (card.currentScale or 1)
    local rx = card.renderX or card.x or 0
    local ry = card.renderY or card.y or 0
    local btnW = math.floor(math.min(imgW * 0.55, 90))
    local btnH = 34
    local gap = 6
    local totalW = btnW * 2 + gap
    local bx0 = math.floor(rx + (imgW - totalW) / 2)
    local by0 = math.floor(ry + imgH + 8)

    self.selectButton = Button:new(bx0, by0, btnW, btnH,
        I18n.t("reward.select_card") or "SELECIONAR",
        function()
            local toSelect = self.selectedCard
            self:_clearCardSelection()
            if toSelect then self:selectCard(toSelect) end
        end, nil, 9)

    -- Botão fechar (X) — cancela seleção sem consumir choice.
    self.cancelButton = Button:new(bx0 + btnW + gap, by0, btnW, btnH, "X",
        function() self:_clearCardSelection() end, nil, 12)
    self.cancelButton:setIcon("x_close")

    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "pack_select")
    else
        self._selectionAnim = 1
    end

    if Sfx.playWithVariation then
        Sfx.playWithVariation("hoverCard", 1.1, 0.08, 0.5, 0.05)
    end
end

function PackOpenScreen:_clearCardSelection()
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self.cancelButton = nil
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 0, 0.12, "smooth", "pack_select")
    else
        self._selectionAnim = 0
    end
end

-- Desenha overlay de carta selecionada — apenas halo dourado + mini-buttons
-- compactos sob a carta (Balatro use_and_sell_buttons pattern). Os painéis
-- info/preview aparecem via hover separadamente em PackOpenScreen:draw().
function PackOpenScreen:_drawCardSelectionOverlay()
    local anim = self._selectionAnim or 0
    if anim < 0.01 and not self.selectedCard then return end
    if not self.selectedCard then return end

    local card = self.selectedCard
    if not card.image then return end
    local imgW = card.image:getWidth() * (card.currentScale or 1)
    local imgH = card.image:getHeight() * (card.currentScale or 1)
    local rx = card.renderX or card.x or 0
    local ry = card.renderY or card.y or 0

    -- Halo dourado pulsante na carta selecionada.
    local haloAlpha = 0.55 * anim * (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], haloAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rx - 3, ry - 3, imgW + 6, imgH + 6)
    love.graphics.setLineWidth(1)

    -- Reposiciona mini-buttons pra acompanhar movimento da carta + draw.
    if self.selectButton and self.cancelButton then
        local btnW = self.selectButton.width
        local btnH = self.selectButton.height
        local gap = 6
        local totalW = btnW * 2 + gap
        local bx0 = math.floor(rx + (imgW - totalW) / 2)
        local by0 = math.floor(ry + imgH + 8)
        self.selectButton.x = bx0
        self.selectButton.y = by0
        self.cancelButton.x = bx0 + btnW + gap
        self.cancelButton.y = by0
        self.selectButton:draw()
        self.cancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Hover info panels: info à esquerda da carta + preview ampliado à direita.
-- Triggered pelo card.isHovered (Card:updateMouse já tracks). Diferente do
-- CardRewardScreen — aqui usamos a posição da carta hovered como anchor (em vez
-- do panel da loja, que não existe).
function PackOpenScreen:_drawHoverInfoPanels()
    if not self.pack or not self.pack.instances then return end
    if not self._cardsReady then return end
    if self._closing then return end

    -- Encontra carta hovered (que não está chosen e não dissolvida).
    local hovered, hoveredImgW, hoveredImgH, hoveredRX, hoveredRY
    for _, card in ipairs(self.pack.instances) do
        if card and card.isHovered and not card._chosen and (card.dissolve or 0) < 0.2 then
            hovered = card
            hoveredImgW = card.image:getWidth() * (card.currentScale or 1)
            hoveredImgH = card.image:getHeight() * (card.currentScale or 1)
            hoveredRX = card.renderX or card.x or 0
            hoveredRY = card.renderY or card.y or 0
            break
        end
    end
    if not hovered then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local gap = 18

    -- ===== LEFT info panel =====
    local panelW = 280
    local panelH = math.min(hoveredImgH + 80, 280)
    local panelX = math.max(16, hoveredRX - panelW - gap)
    local panelY = hoveredRY + (hoveredImgH - panelH) / 2

    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.94)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], 1)
    love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

    local PAD = 14
    local TEXT_W = panelW - PAD * 2

    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], 1)
    love.graphics.setFont(FontManager.getFont(13))
    love.graphics.printf(hovered.name or "?", panelX + PAD, panelY + 14, TEXT_W, "left")

    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.85)
    love.graphics.setFont(FontManager.getFont(9))
    love.graphics.printf(hovered.type or "?", panelX + PAD, panelY + 50, TEXT_W, "left")

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6)
    love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], 0.95)
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.printf(hovered.description or "", panelX + PAD, panelY + 86, TEXT_W, "left")

    -- ===== RIGHT preview ampliado =====
    local previewScale = 1.5
    local previewW = hoveredImgW * previewScale
    local previewH = hoveredImgH * previewScale
    local previewX = math.min(sw - previewW - 16, hoveredRX + hoveredImgW + gap)
    local previewY = hoveredRY + (hoveredImgH - previewH) / 2
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", previewX + 6, previewY + 8, previewW, previewH)
    local origImgW, origImgH = hovered.image:getWidth(), hovered.image:getHeight()
    local sx = previewW / origImgW
    local sy = previewH / origImgH
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(hovered.image, previewX, previewY, 0, sx, sy)

    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" and self._skipReady then
        self:close()
        return true
    end
    return false
end

return PackOpenScreen
