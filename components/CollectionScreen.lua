-- components/CollectionScreen.lua
-- Tela de coleção: grid com todas as cartas do CardDatabase.
-- Scroll vertical com mouse wheel, filtros por classe, tooltip no hover.
-- Acessível pelo botão "COLEÇÃO" no menu principal, ESC volta.

local Config       = require("src.core.Config")
local FontManager  = require("src.ui.FontManager")
local Theme        = require("src.ui.Theme")
local Palette      = require("src.ui.Palette")
local PixelBackground = require("src.ui.PixelBackground")
local PixelCanvas  = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardDatabase = require("src.systems.CardDatabase")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local CardArt      = require("src.ui.CardArt")
local I18n         = require("src.i18n.I18n")

local CollectionScreen = {}
CollectionScreen.__index = CollectionScreen

local RARITY_ORDER = { basic = 1, common = 2, uncommon = 3, rare = 4, legendary = 5 }
local CLASS_ORDER  = { warrior = 1, mage = 2, rogue = 3, [""] = 4 }

-- Filtros: id estável + chave I18n p/ label. Resolvido a cada draw via _filters().
local FILTERS = {
    { id = "all",     i18n = "collection.filter_all" },
    { id = "warrior", i18n = "collection.filter_warrior" },
    { id = "mage",    i18n = "collection.filter_mage" },
    { id = "rogue",   i18n = "collection.filter_rogue" },
    { id = "attack",  i18n = "collection.filter_attack" },
    { id = "defense", i18n = "collection.filter_defense" },
    { id = "joker",   i18n = "collection.filter_joker" },
    { id = "effect",  i18n = "collection.filter_effect" },
}

local function filterLabel(f) return I18n.t(f.i18n) end

local CARD_W, CARD_H = 128, 192   -- tamanho renderizado na tela (96×144 × 1.333)
local GAP_X, GAP_Y = 18, 24
local COLS = 5
local TOP_OFFSET = 120            -- espaço pro título + filtros
local BOTTOM_PAD = 40

function CollectionScreen:new()
    local self = setmetatable({}, CollectionScreen)
    self.visible = false
    self.scrollY = 0
    self.maxScrollY = 0
    self.hoverCard = nil
    self.filter = "all"
    self.cardInstances = {}       -- lazy init em show()
    self.filtered = {}
    self.onCloseCallback = nil
    self.inspectedCard = nil      -- carta em modal de zoom
    self.inspectAnim = 0          -- 0..1 (fade/zoom in)
    return self
end

-- Ordena cartas: class > rarity > name (ordena pelo nome localizado pra ficar
-- alfabético no idioma atual)
local function sortCards(list)
    table.sort(list, function(a, b)
        local ca = CLASS_ORDER[a.class or ""] or 99
        local cb = CLASS_ORDER[b.class or ""] or 99
        if ca ~= cb then return ca < cb end
        local ra = RARITY_ORDER[a.rarity or "common"] or 99
        local rb = RARITY_ORDER[b.rarity or "common"] or 99
        if ra ~= rb then return ra < rb end
        return I18n.cardName(a) < I18n.cardName(b)
    end)
end

-- Converte cartas raw → instâncias renderizadas (com CardFrame aplicado)
function CollectionScreen:_buildInstances()
    if #self.cardInstances > 0 then return end
    local db = CardDatabase:new()
    local all = db:getAllCards()
    local list = {}
    for _, cd in pairs(all) do list[#list + 1] = cd end
    sortCards(list)

    for _, cd in ipairs(list) do
        local ok, instance = pcall(function() return db:createCardInstance(cd) end)
        if ok and instance then
            self.cardInstances[#self.cardInstances + 1] = instance
        else
            print("[CollectionScreen] falha ao instanciar carta: " .. tostring(cd.id))
        end
    end
    print("[CollectionScreen] " .. #self.cardInstances .. " cartas carregadas")
end

function CollectionScreen:_applyFilter()
    self.filtered = {}
    for _, inst in ipairs(self.cardInstances) do
        local match = false
        if self.filter == "all" then
            match = true
        elseif self.filter == "warrior" or self.filter == "mage" or self.filter == "rogue" then
            match = inst.class == self.filter
        elseif self.filter == "attack" or self.filter == "defense"
            or self.filter == "joker" or self.filter == "effect" then
            match = inst.type == self.filter
        end
        if match then self.filtered[#self.filtered + 1] = inst end
    end
    -- Recalcula scroll máximo
    local rows = math.ceil(#self.filtered / COLS)
    local contentH = rows * (CARD_H + GAP_Y)
    local viewH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
    self.maxScrollY = math.max(0, contentH - viewH)
    self.scrollY = math.min(self.scrollY, self.maxScrollY)
end

function CollectionScreen:show(onClose)
    self.visible = true
    self.scrollY = 0
    self.onCloseCallback = onClose
    self:_buildInstances()
    self:_applyFilter()
end

function CollectionScreen:hide()
    self.visible = false
    self.hoverCard = nil
end

function CollectionScreen:isVisible()
    return self.visible
end

-- ===== Layout helpers =====

local function gridOrigin()
    local width = love.graphics.getWidth()
    local totalW = COLS * CARD_W + (COLS - 1) * GAP_X
    local startX = (width - totalW) / 2
    return startX, TOP_OFFSET
end

local function cardRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    local ox, oy = gridOrigin()
    return ox + col * (CARD_W + GAP_X), oy + row * (CARD_H + GAP_Y)
end

-- ===== Eventos =====

function CollectionScreen:update(dt)
    if not self.visible then return end
    -- Anima entrada/saída do modal de inspeção
    if self.inspectedCard then
        self.inspectAnim = math.min(1, self.inspectAnim + dt * 6)
    else
        self.inspectAnim = math.max(0, self.inspectAnim - dt * 8)
    end
    -- No modal não processa hover do grid
    if self.inspectedCard then
        self.hoverCard = nil
        return
    end
    local mx, my = love.mouse.getPosition()
    self.hoverCard = nil
    for i, inst in ipairs(self.filtered) do
        local x, y = cardRect(i)
        y = y - self.scrollY
        if mx >= x and mx <= x + CARD_W and my >= y and my <= y + CARD_H then
            self.hoverCard = { instance = inst, x = x, y = y }
            break
        end
    end
end

function CollectionScreen:wheelmoved(x, y)
    if not self.visible then return end
    if self.inspectedCard then return end -- scroll desabilitado no modal
    self.scrollY = math.max(0, math.min(self.maxScrollY, self.scrollY - y * 40))
end

function CollectionScreen:keypressed(key)
    if not self.visible then return end
    -- Modal de inspeção consome ESC primeiro
    if self.inspectedCard then
        if key == "escape" or key == "space" or key == "return" then
            self.inspectedCard = nil
        elseif key == "left" or key == "a" then
            self:_inspectNeighbor(-1)
        elseif key == "right" or key == "d" then
            self:_inspectNeighbor(1)
        end
        return
    end
    if key == "escape" then
        self:hide()
        if self.onCloseCallback then self.onCloseCallback() end
    elseif key == "up" or key == "pageup" then
        self.scrollY = math.max(0, self.scrollY - 100)
    elseif key == "down" or key == "pagedown" then
        self.scrollY = math.min(self.maxScrollY, self.scrollY + 100)
    end
end

-- Navega entre cartas filtradas no modal (setas ← →)
function CollectionScreen:_inspectNeighbor(delta)
    if not self.inspectedCard then return end
    local idx = nil
    for i, inst in ipairs(self.filtered) do
        if inst == self.inspectedCard then idx = i; break end
    end
    if not idx then return end
    local newIdx = ((idx - 1 + delta) % #self.filtered) + 1
    self.inspectedCard = self.filtered[newIdx]
    self.inspectAnim = 0.3 -- leve "pop" ao trocar
end

function CollectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    if button == 1 then
        -- Modal de inspeção: clique fora fecha, clique em setas navega
        if self.inspectedCard then
            local w, h = love.graphics.getDimensions()
            -- Área da carta grande (centralizada)
            local cardW, cardH = 384, 576 -- 96×144 × 4
            local cardX = (w - cardW) / 2 - 140 -- empurra à esquerda pra caber texto
            local cardY = (h - cardH) / 2
            -- Setas de navegação (clique em 80px nas laterais)
            local arrowY = h / 2 - 30
            -- Esquerda
            if x >= 20 and x <= 100 and y >= arrowY and y <= arrowY + 60 then
                self:_inspectNeighbor(-1)
                return
            end
            -- Direita
            if x >= w - 100 and x <= w - 20 and y >= arrowY and y <= arrowY + 60 then
                self:_inspectNeighbor(1)
                return
            end
            -- Clique em qualquer outro lugar fecha
            if x < cardX or x > cardX + cardW + 320 or y < cardY - 20 or y > cardY + cardH + 20 then
                self.inspectedCard = nil
            end
            return
        end
        -- Filtro tabs no topo
        local font = FontManager.getFont(14)
        local tabY = 70
        local tabX = 20
        love.graphics.setFont(font)
        for _, f in ipairs(FILTERS) do
            local w = font:getWidth(filterLabel(f)) + 20
            if x >= tabX and x <= tabX + w and y >= tabY and y <= tabY + 28 then
                self.filter = f.id
                self.scrollY = 0
                self:_applyFilter()
                return
            end
            tabX = tabX + w + 8
        end
        -- Clique numa carta → modal de inspeção
        for i, inst in ipairs(self.filtered) do
            local cx, cy = cardRect(i)
            cy = cy - self.scrollY
            if x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
                self.inspectedCard = inst
                self.inspectAnim = 0
                return
            end
        end
    end
end

-- ===== Render =====

local function drawBackground()
    local w, h = love.graphics.getDimensions()
    if SceneBackground.draw("collection", w, h, 0.55) then return end
    -- Fallback
    local bg = PixelBackground.voidStars(w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, 0, 0)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

local function drawTitleAndFilters(self)
    local width = love.graphics.getWidth()

    -- Título
    local titleFont = FontManager.getResponsiveFont(0.05, 36)
    love.graphics.setFont(titleFont)
    local title = I18n.t("collection.title")
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, (width - titleFont:getWidth(title)) / 2, 12)

    -- Subtítulo: count
    local subFont = FontManager.getFont(14)
    love.graphics.setFont(subFont)
    local sub = I18n.t("collection.count", { n = #self.filtered })
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, (width - subFont:getWidth(sub)) / 2, 50)

    -- Filtros (tabs horizontais)
    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local tabX = 20
    local tabY = 70
    for _, f in ipairs(FILTERS) do
        local label = filterLabel(f)
        local w = font:getWidth(label) + 20
        local active = self.filter == f.id
        if active then
            love.graphics.setColor(Palette.AGED_GOLD)
        else
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.6)
        end
        love.graphics.rectangle("fill", tabX, tabY, w, 28, 4, 4)
        love.graphics.setColor(Palette.PARCHMENT_DARK)
        love.graphics.rectangle("line", tabX, tabY, w, 28, 4, 4)
        love.graphics.setColor(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        love.graphics.print(label, tabX + 10, tabY + 6)
        tabX = tabX + w + 8
    end

    -- Barra de scroll à direita
    if self.maxScrollY > 0 then
        local barX = width - 12
        local barH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
        local scrollFrac = self.scrollY / self.maxScrollY
        local knobH = math.max(30, barH * (barH / (barH + self.maxScrollY)))
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.5)
        love.graphics.rectangle("fill", barX, TOP_OFFSET, 6, barH)
        love.graphics.setColor(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, TOP_OFFSET + scrollFrac * (barH - knobH), 6, knobH)
    end
end

local function drawCardMini(instance, x, y)
    if not instance.image then return end
    love.graphics.setColor(1, 1, 1, 1)
    local scale = CARD_W / instance.image:getWidth()
    local px, py = math.floor(x), math.floor(y)
    love.graphics.draw(instance.image, px, py, 0, scale, scale)

    -- Icon animations por cima (sparkle/drip/shine/etc — por tipo do ícone)
    if not instance._cachedArt then
        local ok, a = pcall(CardArt.resolve, instance)
        instance._cachedArt = ok and a or { bgPattern = nil }
    end
    CardAnimationLayer.draw(instance, instance._cachedArt, px, py, scale, scale)
end

local function drawHoverTooltip(self)
    if not self.hoverCard then return end
    local inst = self.hoverCard.instance

    local TIP_W = 320
    local TIP_H = 180
    local PAD = 10
    local TEXT_W = TIP_W - PAD * 2   -- largura útil pra printf wrap

    local cx = self.hoverCard.x + CARD_W + 10
    local cy = self.hoverCard.y
    if cx + TIP_W > love.graphics.getWidth() then
        cx = self.hoverCard.x - TIP_W - 10
    end
    if cx < 0 then cx = 0 end
    -- Clamp vertical pra não vazar pelo rodapé
    if cy + TIP_H > love.graphics.getHeight() then
        cy = love.graphics.getHeight() - TIP_H - 10
    end

    -- Fundo pixel (sem cantos arredondados)
    PixelCanvas.rect(cx, cy, TIP_W, TIP_H, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(cx, cy, TIP_W, TIP_H, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(cx + 2, cy + 2, TIP_W - 4, TIP_H - 4, Palette.AGED_GOLD_DARK)

    -- Nome (Press Start 2P size 12) com wrap
    local nameFont = FontManager.getFont(12)
    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.printf(I18n.cardName(inst), cx + PAD, cy + PAD, TEXT_W)

    -- Separador fino
    PixelCanvas.hline(cx + PAD, cy + PAD + 30, TEXT_W, Palette.AGED_GOLD_DARK)

    -- Type / Class / Rarity em 3 linhas separadas (evita overflow horizontal)
    local metaFont = FontManager.getFont(8)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local mY = cy + PAD + 36
    Palette.set(typeColor)
    love.graphics.print(typeLabel, cx + PAD, mY)
    Palette.set(Palette.PARCHMENT)
    love.graphics.print(classLabel, cx + PAD + 72, mY)
    Palette.set(rarityColor)
    love.graphics.print(rarityLabel, cx + PAD + 172, mY)

    -- Descrição (wrap)
    local descFont = FontManager.getFont(8)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT_LIGHT)
    local descText = I18n.cardDesc(inst)
    if not descText or descText == "" then descText = I18n.t("card_info.no_desc") end
    love.graphics.printf(descText, cx + PAD, cy + PAD + 54, TEXT_W)

    -- Stats (rodapé)
    local statFont = FontManager.getFont(10)
    love.graphics.setFont(statFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local statLine = I18n.t("card_info.cost") .. tostring(inst.cost or 0)
    if inst.type == "attack" then
        statLine = statLine .. "  ATK: " .. tostring(inst.attack or 0)
    elseif inst.type == "defense" then
        statLine = statLine .. "  DEF: " .. tostring(inst.defense or 0)
    end
    love.graphics.print(statLine, cx + PAD, cy + TIP_H - 20)
end

local function drawInspectArrows(self, width, height)
    if #self.filtered <= 1 then return end
    local arrowY = height / 2 - 30
    local t = love.timer.getTime()
    local pulse = 0.7 + math.sin(t * 3) * 0.2
    local arrowFont = FontManager.getFont(48)
    love.graphics.setFont(arrowFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], pulse)
    love.graphics.print("‹", 40, arrowY)
    love.graphics.print("›", width - 80, arrowY)
end

local function drawInspectModal(self)
    if not self.inspectedCard and self.inspectAnim <= 0 then return end
    local inst = self.inspectedCard or self.lastInspected
    if not inst then return end
    self.lastInspected = inst

    local width, height = love.graphics.getDimensions()
    local anim = self.inspectAnim

    -- Backdrop escurecido
    love.graphics.setColor(0, 0, 0, 0.82 * anim)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Carta em escala grande (4x = 384×576)
    local scale = 4 * (0.85 + 0.15 * anim)
    local cardW = 96 * scale
    local cardH = 144 * scale
    local cardX = (width - cardW) / 2 - 140  -- desloca pra esquerda pra caber painel
    local cardY = (height - cardH) / 2

    -- Sombra da carta
    love.graphics.setColor(0, 0, 0, 0.6 * anim)
    love.graphics.rectangle("fill", cardX + 10, cardY + 14, cardW, cardH, 6, 6)

    -- Render da carta (estática) + icon animations por cima
    if inst.image then
        love.graphics.setColor(1, 1, 1, anim)
        love.graphics.draw(inst.image, cardX, cardY, 0, scale, scale)

        -- Animações do ícone (shine/drip/sparkle/etc) no modal de zoom
        if not inst._cachedArt then
            local ok, a = pcall(CardArt.resolve, inst)
            inst._cachedArt = ok and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(inst, inst._cachedArt, cardX, cardY, scale, scale)
    end

    -- Painel lateral com info detalhada — pixel chrome (sem cantos arredondados)
    local panelX = cardX + cardW + 30
    local panelY = cardY
    local panelW = 340
    local panelH = cardH
    local PAD = 16
    local TEXT_W = panelW - PAD * 2

    -- Fundo pixel com dual outline. rectangle simples respeita anim (alpha fade-in).
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92 * anim)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
    love.graphics.rectangle("line", panelX,     panelY,     panelW,     panelH)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], anim)
    love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

    -- Nome (Press Start 2P é larga; size 16 com wrap cabe em 308px)
    local nameFont = FontManager.getFont(16)
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    love.graphics.printf(I18n.cardName(inst), panelX + PAD, panelY + 18, TEXT_W)

    -- Separador dourado
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

    -- Type / Class / Rarity em 3 linhas separadas (cada uma com sua cor)
    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local metaY = panelY + 84
    local lineH = metaFont:getHeight() + 4
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], anim)
    love.graphics.print(typeLabel, panelX + PAD, metaY)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], anim)
    love.graphics.print(classLabel, panelX + PAD, metaY + lineH)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], anim)
    love.graphics.print(rarityLabel, panelX + PAD, metaY + lineH * 2)

    -- Stats box
    local statFont = FontManager.getFont(12)
    love.graphics.setFont(statFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local statY = metaY + lineH * 3 + 12
    love.graphics.print(I18n.t("card_info.cost") .. tostring(inst.cost or 0), panelX + PAD, statY)
    statY = statY + 20
    if inst.type == "attack" then
        love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], anim)
        love.graphics.print(I18n.t("card_info.damage") .. tostring(inst.attack or 0), panelX + PAD, statY)
        statY = statY + 20
    elseif inst.type == "defense" then
        love.graphics.setColor(Palette.STEEL_LIGHT[1], Palette.STEEL_LIGHT[2], Palette.STEEL_LIGHT[3], anim)
        love.graphics.print(I18n.t("card_info.defense") .. tostring(inst.defense or 0), panelX + PAD, statY)
        statY = statY + 20
    end

    -- Descrição
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, statY + 4, TEXT_W, 1)
    statY = statY + 14
    local descFont = FontManager.getFont(10)
    love.graphics.setFont(descFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local fullDesc = I18n.cardDesc(inst)
    if not fullDesc or fullDesc == "" then fullDesc = I18n.t("card_info.no_desc") end
    love.graphics.printf(fullDesc, panelX + PAD, statY, TEXT_W)

    -- Efeitos listados
    if inst.effects and #inst.effects > 0 then
        local effY = statY + 80
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
        love.graphics.print(I18n.t("card_info.effects"), panelX + PAD, effY)
        love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
        love.graphics.setFont(descFont)
        for i, e in ipairs(inst.effects) do
            local desc = I18n.effectDesc(e)
            love.graphics.printf("- " .. desc, panelX + PAD + 8, effY + 16 * i, TEXT_W - 8)
            if i >= 4 then break end
        end
    end

    -- ID no rodapé do painel (debug-friendly)
    local idFont = FontManager.getFont(8)
    love.graphics.setFont(idFont)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.4 * anim)
    love.graphics.printf(inst.id or "", panelX + PAD, panelY + panelH - 16, TEXT_W)

    -- Setas de navegação se há mais cartas
    drawInspectArrows(self, width, height)

    -- Dica de fechar no rodapé
    local closeFont = FontManager.getFont(13)
    love.graphics.setFont(closeFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    local closeMsg = I18n.t("collection.inspect_help")
    love.graphics.print(closeMsg, (width - closeFont:getWidth(closeMsg)) / 2, height - 30)

    love.graphics.setColor(1, 1, 1, 1)
end

function CollectionScreen:draw()
    if not self.visible then return end
    drawBackground()
    drawTitleAndFilters(self)

    -- Grid com clip pra não vazar pro topo/rodapé
    local width, height = love.graphics.getDimensions()
    love.graphics.setScissor(0, TOP_OFFSET, width, height - TOP_OFFSET - BOTTOM_PAD)
    for i, inst in ipairs(self.filtered) do
        local x, y = cardRect(i)
        y = y - self.scrollY
        -- skip cartas totalmente off-screen (otimização)
        if y + CARD_H >= TOP_OFFSET and y <= height - BOTTOM_PAD then
            drawCardMini(inst, x, y)
        end
    end
    love.graphics.setScissor()

    -- Hover tooltip por cima (fora do scissor, apenas quando modal não está ativo)
    if not self.inspectedCard and self.inspectAnim < 0.1 then
        drawHoverTooltip(self)
    end

    -- Footer com instruções
    local instFont = FontManager.getFont(12)
    love.graphics.setFont(instFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    local inst = I18n.t("collection.footer")
    love.graphics.print(inst, (width - instFont:getWidth(inst)) / 2, height - 22)

    -- Modal de inspeção (por cima de tudo)
    drawInspectModal(self)

    love.graphics.setColor(1, 1, 1, 1)
end

return CollectionScreen
