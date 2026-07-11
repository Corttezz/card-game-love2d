-- components/ClassSelectionScreen.lua
-- Tela para seleção de classe antes de iniciar uma run.
--
-- F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): 3 PAINÉIS-CLASSE com
-- ícone, identidade, descrição e PREVIEW REAL das cartas iniciais — no lugar
-- de 3 botões soltos sem nenhuma informação (diagnóstico: "ZERO informação
-- por classe"). Hover levanta o painel; clique seleciona.

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local Panel9 = require("src.ui.Panel9")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local IconLoader = require("src.ui.IconLoader")
local HintBar = require("src.ui.HintBar")
local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")

local CLASS_ICONS = {
    warrior = "sword_great",
    mage    = "orb",
    rogue   = "dagger",
}

-- Ordem FIXA de exibição (pairs() embaralhava a ordem entre sessões)
local CLASS_ORDER = { "warrior", "mage", "rogue" }

local ClassSelectionScreen = {}
ClassSelectionScreen.__index = ClassSelectionScreen

function ClassSelectionScreen:new()
    local instance = setmetatable({}, ClassSelectionScreen)
    instance.visible = false
    instance.buttons = {}
    instance.panels = {}          -- {classId, x, y, w, h, btn, info, cards}
    instance.cardRegistry = CardRegistry:new()
    instance.selectedClass = nil
    instance._starterCache = {}   -- classId -> {cardInstance, ...}

    -- Callbacks
    instance.onClassSelected = nil
    instance.onBackToMenu = nil

    instance:createClassButtons()

    return instance
end

-- Instâncias visuais das cartas iniciais (CardFrame real, cacheado).
function ClassSelectionScreen:_starterCards(classId)
    if self._starterCache[classId] then return self._starterCache[classId] end
    local out = {}
    local ids = self.cardRegistry:getStarterDeckForClass(classId)
    for _, id in ipairs(ids) do
        local cd = CardDatabase:getCard(id)
        if cd then
            local ok, inst = pcall(function()
                return CardDatabase:createCardInstance(cd)
            end)
            if ok and inst then table.insert(out, inst) end
        end
    end
    self._starterCache[classId] = out
    return out
end

function ClassSelectionScreen:createClassButtons()
    self.buttons = {}
    self.panels = {}

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local pw, ph = 280, 408
    local gap = 28
    local totalW = pw * 3 + gap * 2
    local startX = math.floor((sw - totalW) / 2)
    local py = math.floor(sh * 0.30)

    for i, classId in ipairs(CLASS_ORDER) do
        local info = self.cardRegistry:getClassInfo(classId)
        if info then
            local x = startX + (i - 1) * (pw + gap)
            local panel = {
                classId = classId,
                info = info,
                x = x, y = py, w = pw, h = ph,
                cards = self:_starterCards(classId),
            }
            panel.btn = Button:new(x, py, pw, ph, "",
                function() self:selectClass(classId) end)
            panel.btn:setVariant("invisible")
            table.insert(self.panels, panel)
            self.buttons[classId] = panel.btn
        end
    end

    -- Botão voltar ao menu
    local backButtonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 200, "width")
    local backButtonHeight = 44

    self.buttons.back = Button:new(
        math.floor(sw / 2 - backButtonWidth / 2),
        py + ph + 20,
        backButtonWidth,
        backButtonHeight,
        I18n.t("class_select.back"),
        function() self:goBackToMenu() end,
        Theme.Colors.WARNING,
        12
    )
    self.buttons.back:setIcon("arrow_left")

    -- Recria botões ao trocar idioma (textos mudam)
    if not self._localeListenerWired then
        self._localeListenerWired = true
        I18n.onLocaleChanged(function()
            self.buttons = {}
            self:createClassButtons()
        end)
    end
end

function ClassSelectionScreen:updatePositions()
    -- layout inteiro depende de sw/sh: recriar é o caminho mais simples e
    -- barato (padrão resize_pattern.md)
    self:createClassButtons()
end

function ClassSelectionScreen:selectClass(classId)
    self.selectedClass = classId
    if self.onClassSelected then
        self.onClassSelected(classId)
    else
        Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
    end
end

function ClassSelectionScreen:goBackToMenu()
    if self.onBackToMenu then
        self.onBackToMenu()
    end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    self:updatePositions()
end

function ClassSelectionScreen:hide()
    self.visible = false
end

function ClassSelectionScreen:update(dt)
    if not self.visible then return end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end
end

-- Painel de classe: moldura + ícone + nome + descrição + cartas iniciais.
function ClassSelectionScreen:_drawClassPanel(p)
    local hover = p.btn and p.btn.hover
    local lift = hover and -6 or 0
    local x, y, w, h = p.x, p.y + lift, p.w, p.h

    Panel9.draw("panel_main", x, y, w, h, {
        tint = hover and { 1.12, 1.08, 0.9, 1 } or nil,
    })

    -- Ícone da classe
    local icon = IconLoader.get(CLASS_ICONS[p.classId] or "scroll")
    if icon and icon.size then
        local s = 48 / icon.size.w
        icon.draw(math.floor(x + w / 2 - icon.size.w * s / 2), y + 34, s)
    end

    -- Nome (fit na largura do painel — design system Jul/2026)
    Palette.set(hover and Palette.RUST or Palette.INK)
    local name = (p.info.name or p.classId):upper()
    require("src.ui.TextFit").print(name, x + 14, y + 96,
        { size = 16, maxW = w - 28, align = "center", minSize = 11 })

    -- Descrição (wrap, INK sobre pergaminho)
    local descFont = FontManager.getFont(9)
    love.graphics.setFont(descFont)
    Palette.set(Palette.INK)
    love.graphics.printf(p.info.description or "", x + 26, y + 128,
        w - 52, "center")

    -- PASSIVA da classe (identidade de gameplay — o diferencial real).
    if p.info.passiveName then
        Palette.set(Palette.BLOOD)
        local pn = "PASSIVA: " .. p.info.passiveName:upper()
        require("src.ui.TextFit").print(pn, x + 14, y + 168,
            { size = 10, maxW = w - 28, align = "center" })
        local pdf = FontManager.getFont(8)
        love.graphics.setFont(pdf)
        Palette.set(Palette.PARCHMENT_DARK)
        love.graphics.printf(p.info.passiveDesc or "", x + 22, y + 186,
            w - 44, "center")
    end

    -- Cartas iniciais (CardFrame REAL em miniatura)
    local label = "Deck inicial:"
    local lf = FontManager.getFont(9)
    love.graphics.setFont(lf)
    Palette.set(Palette.RUST)
    love.graphics.print(label,
        math.floor(x + w / 2 - lf:getWidth(label) / 2), y + 234)

    local cardScale = 0.88
    local cw = 96 * cardScale
    local chh = 144 * cardScale
    local totalCw = #p.cards * cw + math.max(0, #p.cards - 1) * 14
    local cx = math.floor(x + w / 2 - totalCw / 2)
    local cy = y + 254
    for _, inst in ipairs(p.cards) do
        if inst.image then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(inst.image, cx, cy, 0, cardScale, cardScale)
        end
        cx = cx + cw + 14
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:draw()
    if not self.visible then return end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Fundo: cena PNG (classSelection → fallback menu → fallback gradiente)
    if not SceneBackground.draw("classSelection", width, height, 0.45) then
        if not SceneBackground.draw("menu", width, height, 0.55) then
            local bgColors = {
                {0.1, 0.1, 0.2, 1},
                {0.05, 0.05, 0.1, 1}
            }
            Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
        end
    end

    self:drawTitle()

    for _, p in ipairs(self.panels) do
        self:_drawClassPanel(p)
    end

    if self.buttons.back then self.buttons.back:draw() end

    HintBar.draw(I18n.t("class_select.description"))
end

function ClassSelectionScreen:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 24)
    love.graphics.setFont(titleFont)

    local title = I18n.t("class_select.title")
    local width = love.graphics.getWidth()
    local titleX = math.floor(width / 2 - titleFont:getWidth(title) / 2)
    local titleY = math.floor(love.graphics.getHeight() * 0.10)

    -- Banner pixel: ink fill + dual outline gold
    local padX, padY = 20, 10
    local bw = titleFont:getWidth(title) + padX * 2
    local bh = titleFont:getHeight() + padY * 2
    local bx, by = titleX - padX, titleY - padY
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, Palette.PANEL_OUTLINE_INNER)

    -- Título
    Palette.set(Palette.INK)
    love.graphics.print(title, titleX + 1, titleY + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)
end

function ClassSelectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    for _, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    for _, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return ClassSelectionScreen
