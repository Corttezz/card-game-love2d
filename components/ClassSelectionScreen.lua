-- components/ClassSelectionScreen.lua
-- "O Salão dos Heróis" (v2, Jul/2026 — docs/plan/class-select-v2.md).
-- Cada classe é um PERSONAGEM full-body animado (PixelLab v3, 96px) em
-- idle sobre um spotlight âmbar — StS-style. Hover dá um passo à frente;
-- clique é um MOMENTO (flash + anel + faíscas + confirma em 0.45s).
-- Fallback gracioso: sem sprites instalados, cai pro ícone antigo.

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local IconLoader = require("src.ui.IconLoader")
local SpriteAnimation = require("src.ui.SpriteAnimation")
local RadialGlow = require("src.ui.RadialGlow")
local HintBar = require("src.ui.HintBar")
local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")

local CLASS_ICONS = {
    warrior = "sword_great",
    mage    = "orb",
    rogue   = "dagger",
}

-- Cor de identidade por classe (linha da placa de nome + spotlight tint).
local CLASS_COLORS = {
    warrior = { 0.78, 0.25, 0.18 },   -- carmim
    mage    = { 0.45, 0.55, 0.95 },   -- azul arcano
    rogue   = { 0.42, 0.72, 0.34 },   -- verde veneno
}

-- Ordem FIXA de exibição (pairs() embaralhava a ordem entre sessões)
local CLASS_ORDER = { "warrior", "mage", "rogue" }

local ClassSelectionScreen = {}
ClassSelectionScreen.__index = ClassSelectionScreen

function ClassSelectionScreen:new()
    local instance = setmetatable({}, ClassSelectionScreen)
    instance.visible = false
    instance.buttons = {}
    instance.panels = {}          -- {classId, x, y, w, h, btn, info, cards, lift, fx}
    instance.cardRegistry = CardRegistry:new()
    instance.selectedClass = nil
    instance._starterCache = {}   -- classId -> {cardInstance, ...}
    instance._heroAnims = {}      -- classId -> SpriteAnimation | false
    instance._locked = false      -- input travado durante o FX de escolha
    instance._sparks = {}         -- faíscas do momento da escolha

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

-- Animação idle do herói (PixelLab). false = já tentou e não existe.
function ClassSelectionScreen:_heroAnim(classId)
    if self._heroAnims[classId] == nil then
        self._heroAnims[classId] = SpriteAnimation.new(
            "heroes/" .. classId, "idle", "south", 7, { pingpong = true })
            or false
    end
    return self._heroAnims[classId]
end

function ClassSelectionScreen:createClassButtons()
    self.buttons = {}
    self.panels = {}

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local pw, ph = 288, 396
    local gap = 30
    local totalW = pw * 3 + gap * 2
    local startX = math.floor((sw - totalW) / 2)
    local py = math.floor(sh * 0.32)

    for i, classId in ipairs(CLASS_ORDER) do
        local info = self.cardRegistry:getClassInfo(classId)
        if info then
            local x = startX + (i - 1) * (pw + gap)
            local panel = {
                classId = classId,
                info = info,
                x = x, y = py, w = pw, h = ph,
                cards = self:_starterCards(classId),
                lift = 0,       -- suavizado no update
                fx = 0,         -- 1→0 após o clique (flash/anel)
            }
            -- área clicável cobre o HERÓI (que fica acima do painel) também
            panel.btn = Button:new(x, py - 150, pw, ph + 150, "",
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
        py + ph + 16,
        backButtonWidth,
        backButtonHeight,
        I18n.t("class_select.back"),
        function() self:goBackToMenu() end,
        Theme.Colors.WARNING,
        12
    )
    self.buttons.back:setVariant("tv")

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
    if self._locked then return end
    self.selectedClass = classId

    -- O MOMENTO da escolha: flash + anel + faíscas + som, e a confirmação
    -- vem 0.45s depois (EventManager). Sem EM, confirma direto.
    local panel
    for _, p in ipairs(self.panels) do
        if p.classId == classId then panel = p break end
    end
    local EM = _G.EventManager
    if panel and EM then
        self._locked = true
        panel.fx = 1
        -- faíscas douradas radiando do herói
        local cx = panel.x + panel.w / 2
        local cy = panel.y - 10
        for i = 1, 16 do
            local a = (i / 16) * math.pi * 2 + math.random() * 0.3
            table.insert(self._sparks, {
                x = cx, y = cy,
                vx = math.cos(a) * (90 + math.random() * 120),
                vy = math.sin(a) * (90 + math.random() * 120) - 40,
                t = 0, life = 0.5 + math.random() * 0.3,
            })
        end
        Sfx.play("comboTrigger", { volume = 0.8 })
        if panel.btn and panel.btn.juice_up then panel.btn:juice_up(0.3, 0.1) end
        EM.after(0.45, function()
            self._locked = false
            if self.onClassSelected then
                self.onClassSelected(classId)
            else
                Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
            end
        end)
    else
        if self.onClassSelected then
            self.onClassSelected(classId)
        else
            Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
        end
    end
end

function ClassSelectionScreen:goBackToMenu()
    if self._locked then return end
    if self.onBackToMenu then
        self.onBackToMenu()
    end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    self._locked = false
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

    -- v2.1: backdrop vivo (mesma linguagem do menu) — parallax suavizado
    do
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local mx, my = love.mouse.getPosition()
        local tx = math.max(-1, math.min(1, (mx / W - 0.5) * 2))
        local ty = math.max(-1, math.min(1, (my / H - 0.5) * 2))
        local k = math.min(1, dt * 4)
        self._parX = (self._parX or 0) + (tx - (self._parX or 0)) * k
        self._parY = (self._parY or 0) + (ty - (self._parY or 0)) * k
    end

    -- brasas subindo dos braseiros
    self._embers = self._embers or {}
    self._emberTimer = (self._emberTimer or 0) - dt
    if self._emberTimer <= 0 and #self._embers < 8 then
        self._emberTimer = 0.35 + math.random() * 0.5
        table.insert(self._embers, {
            brazier = math.random(2),
            offX = (math.random() - 0.5) * 14,
            t = 0,
            life = 1.2 + math.random() * 1.2,
            sway = math.random() * math.pi * 2,
        })
    end
    for i = #self._embers, 1, -1 do
        local e = self._embers[i]
        e.t = e.t + dt
        if e.t >= e.life then table.remove(self._embers, i) end
    end

    for _, p in ipairs(self.panels) do
        -- lift suavizado (hover = herói dá um passo à frente)
        local target = (p.btn and p.btn.hover and not self._locked) and 1 or 0
        p.lift = p.lift + (target - p.lift) * math.min(1, dt * 10)
        -- FX do clique decai
        if p.fx > 0 then p.fx = math.max(0, p.fx - dt / 0.45) end
        -- idle do herói
        local anim = self:_heroAnim(p.classId)
        if anim then anim:update(dt) end
    end

    -- faíscas da escolha
    for i = #self._sparks, 1, -1 do
        local s = self._sparks[i]
        s.t = s.t + dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.vy = s.vy + 300 * dt
        if s.t >= s.life then table.remove(self._sparks, i) end
    end
end

-- ===== Herói: sprite animado + spotlight + fallback =====
function ClassSelectionScreen:_drawHero(p, cx, feetY)
    local col = CLASS_COLORS[p.classId] or { 1, 0.72, 0.22 }
    local hover = p.lift

    -- SPOTLIGHT no chão (elipse radial; acende no hover, tinge no clique)
    local glow = RadialGlow.get()
    love.graphics.setBlendMode("add")
    local ga = 0.22 + 0.30 * hover + 0.5 * p.fx
    love.graphics.setColor(1, 0.72, 0.30, ga)
    love.graphics.draw(glow, cx, feetY - 4, 0, 2.4, 0.75, 64, 64)
    love.graphics.setColor(col[1], col[2], col[3], 0.18 + 0.22 * hover)
    love.graphics.draw(glow, cx, feetY - 4, 0, 1.5, 0.5, 64, 64)
    love.graphics.setBlendMode("alpha")

    local anim = self:_heroAnim(p.classId)
    if anim then
        local iw, ih = anim:getSize()
        local scale = 2 + 0.18 * hover
        local dx = cx - iw * scale / 2
        local dy = feetY - ih * scale + 14 * scale  -- compensa padding do canvas
        anim:draw(dx, dy - hover * 8, scale)
        -- FLASH branco no momento da escolha
        if p.fx > 0.02 then
            love.graphics.setBlendMode("add")
            anim:draw(dx, dy - hover * 8, scale, { 1, 1, 1, p.fx * 0.85 })
            love.graphics.setBlendMode("alpha")
        end
        return true
    end

    -- Fallback: ícone antigo centralizado na zona do herói
    local icon = IconLoader.get(CLASS_ICONS[p.classId] or "scroll")
    if icon and icon.size then
        local s = (72 + 16 * hover) / icon.size.w
        love.graphics.setColor(1, 1, 1, 1)
        icon.draw(math.floor(cx - icon.size.w * s / 2),
            math.floor(feetY - icon.size.w * s - 10 - hover * 8), s)
    end
    return false
end

-- Painel de classe v2: herói em cima (vazando o painel), placa de nome,
-- passiva e cartas iniciais num backing translúcido (linguagem menu v2.1).
function ClassSelectionScreen:_drawClassPanel(p)
    local lift = -8 * p.lift
    local x, y, w, h = p.x, p.y + lift, p.w, p.h
    local col = CLASS_COLORS[p.classId] or { 1, 0.72, 0.22 }
    local hover = p.lift

    -- BACKING translúcido (não Panel9 pesado): ink + contorno que acende
    love.graphics.setColor(0.05, 0.04, 0.03, 0.62)
    love.graphics.rectangle("fill", x, y, w, h)
    local oa = 0.25 + 0.65 * hover
    love.graphics.setColor(1, 0.72, 0.22, oa)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    if hover > 0.05 then
        love.graphics.setColor(1, 0.72, 0.22, 0.25 * hover)
        love.graphics.rectangle("line", x - 2.5, y - 2.5, w + 5, h + 5)
    end

    -- HERÓI (vaza acima do painel — StS style)
    local cx = x + w / 2
    self:_drawHero(p, cx, y + 96)

    -- PLACA DE NOME + linha de cor da classe
    local name = (p.info.name or p.classId):upper()
    Palette.set(hover > 0.5 and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    require("src.ui.TextFit").print(name, x + 14, y + 116,
        { size = 17, maxW = w - 28, align = "center", minSize = 12,
          shadow = { 0, 0, 0, 0.8 } })
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    local lineW = 64 + 30 * hover
    love.graphics.rectangle("fill", cx - lineW / 2, y + 140, lineW, 2)

    -- Descrição curta (PARCHMENT cheio — DARK afogava sobre o backing ink)
    local descFont = FontManager.getFont(9)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT)
    love.graphics.printf(p.info.description or "", x + 22, y + 152,
        w - 44, "center")

    -- PASSIVA (o diferencial real de gameplay)
    if p.info.passiveName then
        local py2 = y + 196
        -- chip: fundo sutil + nome âmbar
        love.graphics.setColor(1, 0.72, 0.22, 0.10 + 0.10 * hover)
        love.graphics.rectangle("fill", x + 16, py2 - 6, w - 32, 54)
        love.graphics.setColor(1, 0.72, 0.22, 0.35)
        love.graphics.rectangle("line", x + 16.5, py2 - 5.5, w - 33, 53)
        love.graphics.setColor(1, 0.72, 0.22, 1)
        require("src.ui.TextFit").print(
            I18n.t("class_select.passive_label") .. " — " .. p.info.passiveName:upper(),
            x + 20, py2, { size = 10, maxW = w - 40, align = "center" })
        local pdf = FontManager.getFont(8)
        love.graphics.setFont(pdf)
        Palette.set(Palette.PARCHMENT)
        love.graphics.printf(p.info.passiveDesc or "", x + 24, py2 + 18,
            w - 48, "center")
    end

    -- Cartas iniciais (CardFrame REAL em miniatura)
    local cardScale = 0.82
    local cw = 96 * cardScale
    local chh = 144 * cardScale
    local totalCw = #p.cards * cw + math.max(0, #p.cards - 1) * 12
    local ccx = math.floor(cx - totalCw / 2)
    local cy = y + h - chh - 16
    for _, inst in ipairs(p.cards) do
        if inst.image then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(inst.image, ccx, cy, 0, cardScale, cardScale)
        end
        ccx = ccx + cw + 12
    end

    -- ANEL do momento da escolha (expande e some)
    if p.fx > 0.02 then
        local k = 1 - p.fx
        love.graphics.setColor(1, 0.85, 0.4, p.fx * 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cx, y - 10, 30 + k * 160)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:draw()
    if not self.visible then return end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Fundo VIVO (v2.1, mesma linguagem do menu): parallax de mouse +
    -- braseiros pulsando + respiração quente + brasas + poeira.
    self:_drawLivingBackdrop(width, height)

    self:drawTitle()

    for _, p in ipairs(self.panels) do
        self:_drawClassPanel(p)
    end

    -- faíscas da escolha (por cima dos painéis)
    for _, s in ipairs(self._sparks) do
        local a = 1 - s.t / s.life
        love.graphics.setColor(1, 0.85, 0.4, a)
        love.graphics.rectangle("fill", math.floor(s.x), math.floor(s.y), 2, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)

    if self.buttons.back then self.buttons.back:draw() end

    HintBar.draw(I18n.t("class_select.description"))
end

-- ===== v2.1: backdrop vivo =====
-- Âncoras dos 2 BRASEIROS na imagem do salão minimalista (coords
-- relativas ao PNG 400×256, v2 "limpo" Jul/2026 — ajuste se regenerar).
local BRAZIER_ANCHORS = {
    { xr = 0.380, yr = 0.735, phase = 0.0 },
    { xr = 0.618, yr = 0.735, phase = 2.9 },
}

function ClassSelectionScreen:_drawLivingBackdrop(width, height)
    local t = love.timer.getTime()

    -- CAMADA 1: salão com parallax (folga de zoom, offset clampado)
    -- overlay leve: a arte v2 já é escura por composição (0.38 afogava)
    local ok, tf = SceneBackground.drawParallax("classSelection", width, height,
        0.15, (self._parX or 0) * -12, (self._parY or 0) * -7, 1.07)
    if not ok then
        if not SceneBackground.draw("menu", width, height, 0.55) then
            Theme.Utils.drawVerticalGradient(0, 0, width, height, {
                { 0.1, 0.1, 0.2, 1 }, { 0.05, 0.05, 0.1, 1 } })
        end
        return
    end
    self._sceneTf = tf

    -- CAMADA 2: fogo dos braseiros (glow radial com flicker de noise)
    local glow = RadialGlow.get()
    love.graphics.setBlendMode("add")
    for _, a in ipairs(BRAZIER_ANCHORS) do
        local x = tf.ox + a.xr * tf.dw
        local y = tf.oy + a.yr * tf.dh
        local flick = 0.65 + 0.35 * love.math.noise(t * 6.0, a.phase)
        local r = tf.dw * 0.060 * (0.9 + 0.16 * love.math.noise(t * 3.1, a.phase + 5))
        love.graphics.setColor(1, 0.48, 0.14, 0.28 * flick)
        love.graphics.draw(glow, x, y, 0, r * 2 / 128, r * 1.5 / 128, 64, 64)
        love.graphics.setColor(1, 0.78, 0.38, 0.30 * flick)
        love.graphics.draw(glow, x, y, 0, r / 128, r * 0.8 / 128, 64, 64)
    end
    love.graphics.setBlendMode("alpha")

    -- CAMADA 3: respiração quente global (sala à luz de fogo)
    local warm = 0.025 + 0.025 * love.math.noise(t * 2.1, 3.3)
    love.graphics.setColor(1, 0.62, 0.28, warm)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- CAMADA 4: brasas dos braseiros (esfriam amarelo→laranja)
    for _, e in ipairs(self._embers or {}) do
        local anch = BRAZIER_ANCHORS[e.brazier]
        local k = e.t / e.life
        local x = tf.ox + anch.xr * tf.dw + e.offX
            + math.sin(e.t * 3 + e.sway) * 7 * k
        local y = tf.oy + anch.yr * tf.dh - k * 85
        love.graphics.setColor(1, 0.85 - 0.45 * k, 0.30 - 0.20 * k, (1 - k) * 0.85)
        local s = k < 0.15 and 2 or 1
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ClassSelectionScreen:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 24)
    love.graphics.setFont(titleFont)

    local title = I18n.t("class_select.title")
    local width = love.graphics.getWidth()
    local titleX = math.floor(width / 2 - titleFont:getWidth(title) / 2)
    local titleY = math.floor(love.graphics.getHeight() * 0.07)

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
    if not self.visible or self._locked then return end
    for _, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    if self._locked then return end
    for _, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return ClassSelectionScreen
