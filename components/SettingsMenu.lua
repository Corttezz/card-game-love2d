-- components/SettingsMenu.lua
-- Overlay pixel de configurações (volume, fullscreen, CRT shader).
-- Ativado pelo ícone de config na TopBar. Desenha por cima do jogo.

local Button      = require("components.Button")
local FontManager = require("src.ui.FontManager")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")
local CRTShader   = require("src.ui.CRTShader")
local I18n        = require("src.i18n.I18n")
local SaveManager = require("engine.SaveManager")

local SettingsMenu = {}
SettingsMenu.__index = SettingsMenu

local STEP = 0.1   -- incremento de volume por clique

function SettingsMenu:new()
    local instance = setmetatable({}, SettingsMenu)
    instance.visible = false
    instance.buttons = {}
    instance.languageMenuOpen = false   -- dropdown de idiomas
    instance.languageButtons = {}        -- botoes do dropdown (um por idioma)
    instance._langAnchor = nil           -- {x, y, w, h} do botao gatilho
    return instance
end

function SettingsMenu:show() self.visible = true; self:rebuild() end
function SettingsMenu:hide() self.visible = false end
function SettingsMenu:isVisible() return self.visible end
function SettingsMenu:toggle()
    if self.visible then self:hide() else self:show() end
end

-- Recalcula posições dos botões (chamar em show e em love.resize).
function SettingsMenu:rebuild()
    self.buttons = {}
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    -- Painel maior pra acomodar as linhas extras (8 rows agora: + iluminação).
    local panelW = math.min(520, math.floor(W * 0.65))
    local panelH = math.min(580, math.floor(H * 0.86))
    local panelX = math.floor((W - panelW) / 2)
    local panelY = math.floor((H - panelH) / 2)
    self._panel = { x = panelX, y = panelY, w = panelW, h = panelH }

    local btnW, btnH = 36, 32
    local rowX = panelX + panelW - 180
    local rowY = panelY + 76
    local gap  = 50

    -- Linhas 1-3: volumes
    self:_addVolumeRow("music",  rowX, rowY,            btnW, btnH)
    self:_addVolumeRow("sfx",    rowX, rowY + gap,      btnW, btnH)
    self:_addVolumeRow("master", rowX, rowY + gap * 2,  btnW, btnH)

    -- Linha 4: Fullscreen toggle
    local fsOn = love.window.getFullscreen()
    local fsBtn = Button:new(
        rowX, rowY + gap * 3, 140, btnH,
        fsOn and I18n.t("settings.on") or I18n.t("settings.off"),
        function()
            local fs = not love.window.getFullscreen()
            love.window.setFullscreen(fs)
            FontManager.clearCache()
            if love.resize then love.resize(love.graphics.getWidth(), love.graphics.getHeight()) end
            self:rebuild()
            self:_persist()
        end, nil, 10
    )
    fsBtn:setIcon(fsOn and "check" or "x_close")
    table.insert(self.buttons, fsBtn)

    -- Linha 5: CRT shader toggle
    local crtOn = CRTShader.isEnabled()
    local crtBtn = Button:new(
        rowX, rowY + gap * 4, 140, btnH,
        crtOn and I18n.t("settings.on") or I18n.t("settings.off"),
        function()
            CRTShader.toggle()
            self:rebuild()
            self:_persist()
        end, nil, 10
    )
    crtBtn:setIcon(crtOn and "check" or "x_close")
    table.insert(self.buttons, crtBtn)

    -- Linha 6: Iluminação (LightEngine da cena WorldRoad) toggle
    local lightOn = not (_G.gameSettings and _G.gameSettings.lighting == false)
    local lightBtn = Button:new(
        rowX, rowY + gap * 5, 140, btnH,
        lightOn and I18n.t("settings.on") or I18n.t("settings.off"),
        function()
            if _G.gameSettings then
                _G.gameSettings.lighting = not lightOn
            end
            self:rebuild()
            self:_persist()
        end, nil, 10
    )
    lightBtn:setIcon(lightOn and "check" or "x_close")
    table.insert(self.buttons, lightBtn)

    -- Linha 7: Reduced motion toggle (acessibilidade Balatro-style)
    local rmOn = _G.gameSettings and _G.gameSettings.reducedMotion or false
    local rmBtn = Button:new(
        rowX, rowY + gap * 6, 140, btnH,
        rmOn and I18n.t("settings.on") or I18n.t("settings.off"),
        function()
            _G.gameSettings.reducedMotion = not rmOn
            self:rebuild()
            self:_persist()
        end, nil, 10
    )
    rmBtn:setIcon(rmOn and "check" or "x_close")
    table.insert(self.buttons, rmBtn)

    -- Linha 8: seletor de idioma (dropdown). Click no botao alterna lista.
    local langBtnW = 140
    local langBtnX = rowX
    local langBtnY = rowY + gap * 7
    local langBtn = Button:new(
        langBtnX, langBtnY, langBtnW, btnH,
        I18n.getLabel(I18n.getLocale()),
        function() self:_toggleLanguageMenu() end,
        nil, 10
    )
    langBtn:setIcon("scroll")
    table.insert(self.buttons, langBtn)
    self._langAnchor = { x = langBtnX, y = langBtnY, w = langBtnW, h = btnH }
    -- Reconstroi a lista do dropdown (necessario apos rebuild de painel).
    self:_buildLanguageButtons()

    -- Botão fechar (com ícone x)
    local closeBtn = Button:new(
        panelX + panelW / 2 - 70, panelY + panelH - 56, 140, 36,
        I18n.t("settings.close"), function() self:hide() end, nil, 12
    )
    closeBtn:setIcon("x_close")
    table.insert(self.buttons, closeBtn)
end

-- ===== Dropdown de idiomas =====
-- Cria um Button por idioma disponivel. Posicionados ABAIXO do botao gatilho
-- formando uma lista vertical. Marcados como invisiveis ate o dropdown abrir
-- (controlado por self.languageMenuOpen).
function SettingsMenu:_buildLanguageButtons()
    self.languageButtons = {}
    if not self._langAnchor then return end
    local a = self._langAnchor
    local locales = I18n.getAvailable()
    local current = I18n.getLocale()
    for i, code in ipairs(locales) do
        local label = I18n.getLabel(code)
        -- Marca o ativo com check; demais sem icone.
        local btn = Button:new(
            a.x, a.y + a.h + 2 + (i - 1) * (a.h + 2),
            a.w, a.h,
            label,
            function() self:_selectLanguage(code) end,
            nil, 10
        )
        if code == current then btn:setIcon("check") end
        self.languageButtons[i] = { code = code, btn = btn }
    end
end

function SettingsMenu:_toggleLanguageMenu()
    self.languageMenuOpen = not self.languageMenuOpen
end

function SettingsMenu:_selectLanguage(code)
    self.languageMenuOpen = false
    if I18n.setLocale(code) then
        -- rebuild reconstroi os botoes com labels traduzidos
        self:rebuild()
        self:_persist()
    end
end

function SettingsMenu:_dropdownRect()
    if not self._langAnchor then return nil end
    local a = self._langAnchor
    local n = #self.languageButtons
    return a.x, a.y + a.h + 2, a.w, n * (a.h + 2)
end

function SettingsMenu:_addVolumeRow(kind, x, y, btnW, btnH)
    local minus = Button:new(x, y, btnW, btnH, "-",
        function() self:_adjust(kind, -STEP) end, nil, 16)
    local plus  = Button:new(x + btnW + 24, y, btnW, btnH, "+",
        function() self:_adjust(kind, STEP) end, nil, 16)
    table.insert(self.buttons, minus)
    table.insert(self.buttons, plus)
end

function SettingsMenu:_adjust(kind, delta)
    local a = _G.audioSystem
    if not a then return end
    local getter = kind == "music" and a.musicVolume or (kind == "sfx" and a.sfxVolume or a.volume)
    local new = math.max(0, math.min(1, (getter or 0) + delta))
    if kind == "music" then a:setMusicVolume(new)
    elseif kind == "sfx" then a:setSFXVolume(new)
    else a:setVolume(new) end
    self:_persist()
end

-- Snapshot current settings → SaveManager. Chamado em qualquer mudança.
function SettingsMenu:_persist()
    local a = _G.audioSystem
    SaveManager.saveSettings({
        masterVolume  = a and a.volume or 1.0,
        musicVolume   = a and a.musicVolume or 0.3,
        sfxVolume     = a and a.sfxVolume or 0.7,
        fullscreen    = love.window.getFullscreen(),
        crtShader     = CRTShader.isEnabled(),
        lighting      = not (_G.gameSettings and _G.gameSettings.lighting == false),
        reducedMotion = _G.gameSettings and _G.gameSettings.reducedMotion or false,
        screenshake   = _G.gameSettings and _G.gameSettings.screenshake or 1.0,
        locale        = I18n.getLocale(),
    })
end

function SettingsMenu:update(dt)
    if not self.visible then return end
    for _, b in ipairs(self.buttons) do b:update(dt) end
    if self.languageMenuOpen then
        for _, e in ipairs(self.languageButtons) do e.btn:update(dt) end
    end
end

function SettingsMenu:draw()
    if not self.visible then return end

    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local p = self._panel

    -- Dim global
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Painel pixel (sem cantos arredondados): fill INK + dual outline gold
    PixelCanvas.rect(p.x, p.y, p.w, p.h, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(p.x, p.y, p.w, p.h, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(p.x + 2, p.y + 2, p.w - 4, p.h - 4, Palette.PANEL_OUTLINE_INNER)

    -- Título
    local titleFont = FontManager.getFont(16)
    love.graphics.setFont(titleFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local title = I18n.t("settings.title")
    love.graphics.print(title,
        math.floor(p.x + (p.w - titleFont:getWidth(title)) / 2),
        p.y + 20)

    -- Separador gold sob o título
    PixelCanvas.hline(p.x + 16, p.y + 52, p.w - 32, Palette.AGED_GOLD_DARK)

    -- Labels + valores (gap = 50, mesmo que rebuild)
    local gap = 50
    self:_drawRow(I18n.t("settings.music"),  _G.audioSystem and _G.audioSystem.musicVolume or 0, p.x + 24, p.y + 76)
    self:_drawRow(I18n.t("settings.sfx"),    _G.audioSystem and _G.audioSystem.sfxVolume or 0,   p.x + 24, p.y + 76 + gap)
    self:_drawRow(I18n.t("settings.master"), _G.audioSystem and _G.audioSystem.volume or 0,      p.x + 24, p.y + 76 + gap * 2)
    self:_drawLabel(I18n.t("settings.fullscreen"),     p.x + 24, p.y + 76 + gap * 3)
    self:_drawLabel(I18n.t("settings.crt_shader"),     p.x + 24, p.y + 76 + gap * 4)
    self:_drawLabel(I18n.t("settings.lighting"),       p.x + 24, p.y + 76 + gap * 5)
    self:_drawLabel(I18n.t("settings.reduced_motion"), p.x + 24, p.y + 76 + gap * 6)
    self:_drawLabel(I18n.t("settings.language"),       p.x + 24, p.y + 76 + gap * 7)

    for _, b in ipairs(self.buttons) do b:draw() end

    -- Dropdown de idiomas (por cima dos demais botoes, com leve sombra)
    if self.languageMenuOpen then
        local dx, dy, dw, dh = self:_dropdownRect()
        if dx then
            -- Sombra
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", dx + 3, dy + 3, dw, dh + 4)
            -- Painel pixel do dropdown
            PixelCanvas.rect(dx, dy, dw, dh + 4, Palette.PANEL_FILL)
            PixelCanvas.rectOutline(dx, dy, dw, dh + 4, Palette.AGED_GOLD)
            PixelCanvas.rectOutline(dx + 1, dy + 1, dw - 2, dh + 2, Palette.AGED_GOLD_DARK)
            for _, e in ipairs(self.languageButtons) do e.btn:draw() end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsMenu:_drawRow(label, value, x, y)
    self:_drawLabel(label, x, y)
    local font = FontManager.getFont(10)
    love.graphics.setFont(font)
    Palette.set(Palette.PARCHMENT)
    local pct = math.floor((value or 0) * 100)
    love.graphics.print(pct .. "%", x + 130, y + 10)
end

function SettingsMenu:_drawLabel(text, x, y)
    local font = FontManager.getFont(12)
    love.graphics.setFont(font)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(text, x, y + 6)
end

function SettingsMenu:mousepressed(x, y, button)
    if not self.visible then return false end
    -- Dropdown aberto: cliques fora dele fecham o dropdown (sem fechar painel)
    if self.languageMenuOpen then
        for _, e in ipairs(self.languageButtons) do e.btn:mousepressed(x, y, button) end
        local dx, dy, dw, dh = self:_dropdownRect()
        local insideDropdown = dx and x >= dx and x <= dx + dw and y >= dy and y <= dy + dh + 4
        local a = self._langAnchor
        local insideAnchor = a and x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h
        if not insideDropdown and not insideAnchor then
            self.languageMenuOpen = false
        end
        return true
    end
    for _, b in ipairs(self.buttons) do b:mousepressed(x, y, button) end
    return true   -- consome o clique (overlay modal)
end

function SettingsMenu:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.languageMenuOpen then
        for _, e in ipairs(self.languageButtons) do e.btn:mousereleased(x, y, button) end
        return true
    end
    for _, b in ipairs(self.buttons) do b:mousereleased(x, y, button) end
    return true
end

function SettingsMenu:keypressed(key)
    if not self.visible then return false end
    if key == "escape" then
        if self.languageMenuOpen then
            self.languageMenuOpen = false
        else
            self:hide()
        end
        return true
    end
    return true
end

return SettingsMenu
