local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local PixelBackground = require("src.ui.PixelBackground")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local CardBack = require("src.ui.CardBack")
local CardBackHover = require("src.ui.CardBackHover")
local DynaText = require("src.ui.DynaText")

local Menu = {}
Menu.__index = Menu

function Menu:new()
    local instance = setmetatable({}, Menu)
    instance.buttons = {}
    instance.visible = true

    -- Estado de intro animation. Modificado por enterWithIntro().
    -- alphaTitle / alphaSubtitle / alphaButtons[name] são interpolados via
    -- EventManager.ease pra fade-in stagger Balatro-style.
    instance.intro = {
        active        = false,
        alphaTitle    = 1,
        alphaSubtitle = 1,
        alphaButtons  = { play = 1, collection = 1, settings = 1, quit = 1 },
        alphaBg       = 1,
        titleScale    = 1,
        buttonOffsetY = { play = 0, collection = 0, settings = 0, quit = 0 },
    }

    -- 3 versos de carta flutuantes (Balatro-style demo cards). Cada uma tem
    -- um state de hover compartilhado com CardBackHover (replica Card:updateMouse).
    instance.floatingCards = {
        { ax = 0.16, ay = 0.30, phase = 0.0, freqY = 0.7, freqR = 0.5, hover = CardBackHover.new() },
        { ax = 0.84, ay = 0.30, phase = 1.7, freqY = 0.5, freqR = 0.6, hover = CardBackHover.new() },
        { ax = 0.50, ay = 0.83, phase = 3.1, freqY = 0.8, freqR = 0.4, hover = CardBackHover.new() },
    }

    -- Cria os botões do menu
    instance:createButtons()

    -- Re-cria botões quando trocar idioma (textos mudam)
    I18n.onLocaleChanged(function()
        if instance.visible ~= nil then instance:createButtons() end
    end)

    return instance
end

function Menu:_title()    return I18n.t("menu.title") end
function Menu:_subtitle() return I18n.t("menu.subtitle") end

function Menu:createButtons()
    -- Usa coordenadas relativas à resolução da tela
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5 -- 50% da altura
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")
    
    -- Botão Jogar
    self.buttons.play = Button:new(
        centerX - buttonWidth / 2,
        startY,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.play"),
        function() self:onPlayClick() end,
        Theme.Colors.SUCCESS,
        24
    )

    -- Botão Coleção
    self.buttons.collection = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.collection"),
        function() self:onCollectionClick() end,
        Theme.Colors.ACCENT or Theme.Colors.INFO,
        20
    )

    -- Botão Configurações
    self.buttons.settings = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 2,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.settings"),
        function() self:onSettingsClick() end,
        Theme.Colors.WARNING,
        20
    )

    -- Botão Sair
    self.buttons.quit = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 3,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.quit"),
        function() self:onQuitClick() end,
        Theme.Colors.ERROR,
        20
    )

    -- Ícones pixel em cada botão (deixa o Button fazer auto-scale pela altura)
    self.buttons.play:setIcon("play_triangle")
    self.buttons.collection:setIcon("scroll")
    self.buttons.settings:setIcon("gear")
    self.buttons.quit:setIcon("x_close")
end

function Menu:updatePositions()
    -- Reposiciona os botões dinamicamente baseado na resolução atual
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")
    
    -- Reposiciona cada botão
    if self.buttons.play then
        self.buttons.play:setPosition(centerX - buttonWidth / 2, startY)
        self.buttons.play.width = buttonWidth
        self.buttons.play.height = buttonHeight
    end
    
    if self.buttons.collection then
        self.buttons.collection:setPosition(centerX - buttonWidth / 2, startY + spacing)
        self.buttons.collection.width = buttonWidth
        self.buttons.collection.height = buttonHeight
    end

    if self.buttons.settings then
        self.buttons.settings:setPosition(centerX - buttonWidth / 2, startY + spacing * 2)
        self.buttons.settings.width = buttonWidth
        self.buttons.settings.height = buttonHeight
    end

    if self.buttons.quit then
        self.buttons.quit:setPosition(centerX - buttonWidth / 2, startY + spacing * 3)
        self.buttons.quit.width = buttonWidth
        self.buttons.quit.height = buttonHeight
    end
end

function Menu:update(dt)
    if not self.visible then return end

    -- DynaText do título (lazy-init em ensure). update progredindo timer interno
    -- pra que pop_in cascade + rotate wobble animem por frame.
    self:_ensureTitleDyna()
    if self._titleDyna then self._titleDyna:update(dt) end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end
end

-- Cria/recria a instância DynaText do título. Recria se a fonte responsiva
-- mudou (resize) ou se o texto mudou (locale switch). Cache local em
-- self._titleDyna; o objeto guarda timer interno (pop_in + bump/rotate).
function Menu:_ensureTitleDyna()
    local height = love.graphics.getHeight()
    local size = math.min(40, math.floor(height * (Config.UI.TITLE_FONT_RATIO or 0.08)))
    local title = self:_title()
    if not self._titleDyna
       or self._titleDyna._cachedText ~= title
       or self._titleDyna._cachedSize ~= size then
        local g = Palette.AGED_GOLD_LIGHT
        self._titleDyna = DynaText.new({
            text = title,
            fontSize = size,
            rotate = true,                   -- wobble idle Balatro-style
            pop_in = 0.5,                    -- cascata de letras na entrada
            pop_in_rate = 4,
            colours = { { g[1], g[2], g[3], 1 } },
            shadow = true,
            align = "center",
            spacing = 0,
        })
        self._titleDyna._cachedText = title
        self._titleDyna._cachedSize = size
    end
end

function Menu:draw()
    if not self.visible then return end

    -- Background com gradiente profissional
    self:drawBackground()

    -- Cartas decorativas flutuantes (Balatro-style demo).
    self:_drawFloatingCards()

    -- Título
    self:drawTitle()

    -- Subtítulo
    local saA = self.intro.alphaSubtitle or 1
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], saA)
    local subtitleFont = FontManager.getResponsiveFont(Config.UI.SUBTITLE_FONT_RATIO, 14)
    love.graphics.setFont(subtitleFont)
    local subtitle = self:_subtitle()
    local subtitleWidth = subtitleFont:getWidth(subtitle)
    love.graphics.print(subtitle,
        math.floor(love.graphics.getWidth() / 2 - subtitleWidth / 2),
        math.floor(love.graphics.getHeight() * 0.42))

    -- Desenha botões. Durante intro: cada botão fica invisível até seu alpha
    -- passar de 0.1, depois faz slide-up de 12px com back_out (efeito "pop in").
    for name, button in pairs(self.buttons) do
        local a = self.intro.alphaButtons[name] or 1
        if a > 0.1 then
            local offY = self.intro.buttonOffsetY[name] or 0
            local origY = button.y
            if offY ~= 0 then button.y = origY + offY end
            button:draw()
            if offY ~= 0 then button.y = origY end
        end
    end

    -- Instruções
    self:drawInstructions()

    -- Reseta cor
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:drawBackground()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local bgAlpha = self.intro.alphaBg or 1

    -- Tenta usar PNG gerado (scene_menu.png); fallback pra voidStars procedural.
    local SceneBackground = require("src.ui.SceneBackground")
    if SceneBackground.draw("menu", width, height) then
        -- Mask de fade-in (escurece enquanto bgAlpha sobe).
        if bgAlpha < 1 then
            love.graphics.setColor(0, 0, 0, 1 - bgAlpha)
            love.graphics.rectangle("fill", 0, 0, width, height)
        end
        -- Overlay grimório pulsante dourado sutil
        local pulse = 0.04 + math.sin(love.timer.getTime() * 0.5) * 0.02
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], pulse * bgAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Fallback: voidStars + overlay ink (sem magenta)
    local bg = PixelBackground.voidStars(width, height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, 0, 0)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.45)
    love.graphics.rectangle("fill", 0, 0, width, height)
    if bgAlpha < 1 then
        love.graphics.setColor(0, 0, 0, 1 - bgAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 40)
    love.graphics.setFont(titleFont)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local title = self:_title()
    local tw = titleFont:getWidth(title)
    local th = titleFont:getHeight(title)

    -- Intro state: alpha + scale (back_out pop).
    local alpha = self.intro.alphaTitle or 1
    if alpha <= 0.02 then return end
    local scale = self.intro.titleScale or 1

    local centerX = math.floor(width / 2)
    local centerY = math.floor(height * 0.22 + th / 2)

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(scale, scale)

    local tx = -tw / 2
    local ty = -th / 2

    -- Banner pixel: ink fill + borda dourada dupla via PixelCanvas (em coords locais).
    local padX, padY = 28, 12
    local bx, by = tx - padX, ty - padY
    local bw, bh = tw + padX * 2, th + padY * 2

    -- Aplica alpha multiplicativo nas cores do banner.
    local function colA(c, mul) return { c[1], c[2], c[3], (c[4] or 1) * (mul or alpha) } end
    PixelCanvas.rect(bx, by, bw, bh, colA(Palette.PANEL_FILL))
    PixelCanvas.rectOutline(bx, by, bw, bh, colA(Palette.PANEL_OUTLINE))
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, colA(Palette.PANEL_OUTLINE_INNER))

    -- Título via DynaText (Balatro engine/text.lua port): pop_in cascade na
    -- entrada + rotate wobble idle + shadow integrada. Substitui love.graphics.print
    -- direto pra dar movimento "vivo" característico do polish do Balatro.
    if self._titleDyna then
        local pulse = 0.85 + math.sin(love.timer.getTime() * 1.2) * 0.15
        if alpha < 0.99 then pulse = 1 end -- intro: sem pulse
        local g = Palette.AGED_GOLD_LIGHT
        local c = self._titleDyna.colours[1]
        c[1], c[2], c[3], c[4] = g[1] * pulse, g[2] * pulse, g[3] * pulse, alpha
        self._titleDyna:draw(0, 0)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cartas decorativas que flutuam atrás do título (Balatro-style demo cards).
-- Cada uma tem fase própria pra dessincronizar drift+rotação.
function Menu:_drawFloatingCards()
    if not self.floatingCards then return end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local t = love.timer.getTime()

    -- Tamanho das cartas decorativas: ~12% da largura (mais visíveis).
    local cardW = math.floor(W * 0.12)
    local cardH = math.floor(cardW * 1.5)

    local bgAlpha = self.intro.alphaBg or 1
    if bgAlpha <= 0.05 then return end

    local alpha = 0.95 * bgAlpha
    local dt = love.timer.getDelta()

    -- Mouse pra hover-tilt 3D nas cartas (mesma lógica Card.lua via CardBackHover).
    local mx, my = love.mouse.getPosition()

    for _, fc in ipairs(self.floatingCards) do
        local cx = W * fc.ax
        local cy = H * fc.ay + math.sin(t * fc.freqY + fc.phase) * 14
        local rotDrift = math.sin(t * fc.freqR + fc.phase) * 0.10

        -- Atualiza hover state (tilts/lift/perspective via CardBackHover.update,
        -- mesmo math que Card:updateMouse). liftDir="up" = sobe quando hovered.
        CardBackHover.update(fc.hover, mx, my, cx, cy, cardW, cardH, dt, "up")
        fc.hover.alpha = alpha
        fc.hover.scale = 1
        fc.hover.rot   = rotDrift  -- drift senoidal além do perspective rotation

        CardBack.draw(cx, cy, cardW, cardH, fc.hover)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:drawInstructions()
    Palette.set(Palette.PARCHMENT_DARK)
    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 10)
    love.graphics.setFont(instructionFont)

    local instructions = {
        I18n.t("menu.instr_mouse"),
        I18n.t("menu.instr_space"),
        I18n.t("menu.instr_restart"),
        I18n.t("menu.instr_jokers"),
    }

    local y = math.floor(love.graphics.getHeight() * 0.88)
    for i, instruction in ipairs(instructions) do
        local x = math.floor(love.graphics.getWidth() / 2 - instructionFont:getWidth(instruction) / 2)
        love.graphics.print(instruction, x, y + (i - 1) * (instructionFont:getHeight() + 4))
    end
end

function Menu:onPlayClick()
    self.visible = false
    -- Fade-out da música menu antes de entrar no gameplay.
    if Sfx.fadeMusicOut then Sfx.fadeMusicOut(0.5) end
    -- Jiggle + flash ao entrar no jogo: feedback cinematográfico Balatro-style
    -- (game.lua dispara o mesmo combo no `start_run`). Sinaliza ao jogador
    -- "transição importante acontecendo".
    if _G.jiggleScreen then _G.jiggleScreen(0.8) end
    local ok, FlashShader = pcall(require, "src.ui.FlashShader")
    if ok and FlashShader and FlashShader.trigger then FlashShader.trigger(0.35, 0.4) end
    if self.onPlayCallback then
        self.onPlayCallback()
    end
end

function Menu:onSettingsClick()
    if self.onSettingsCallback then
        self.onSettingsCallback()
    else
        print("Configurações - callback não definido")
    end
end

function Menu:onCollectionClick()
    if self.onCollectionCallback then
        self.onCollectionCallback()
    else
        print("Coleção - callback não definido")
    end
end

function Menu:setCollectionCallback(cb) self.onCollectionCallback = cb end
function Menu:setSettingsCallback(cb) self.onSettingsCallback = cb end

function Menu:onQuitClick()
    love.event.quit()
end

function Menu:setPlayCallback(callback)
    self.onPlayCallback = callback
end

function Menu:show()
    self.visible = true
end

-- Reanima o menu como se fosse a primeira vez: alpha 0→1 staggered nos botões,
-- title scale com back-out, music fade-in. Chamado por main.lua após o splash
-- e ao voltar do gameplay/collection/settings.
function Menu:enterWithIntro()
    self.visible = true

    -- Reset alphas pra 0.
    self.intro.active        = true
    self.intro.alphaBg       = 0
    self.intro.alphaTitle    = 0
    self.intro.alphaSubtitle = 0
    self.intro.titleScale    = 0.85
    for k in pairs(self.intro.alphaButtons) do
        self.intro.alphaButtons[k] = 0
        self.intro.buttonOffsetY[k] = 12
    end

    local EM = _G.EventManager
    if not EM then
        -- Sem EventManager: snap pra 1.
        self.intro.alphaBg = 1
        self.intro.alphaTitle = 1
        self.intro.alphaSubtitle = 1
        self.intro.titleScale = 1
        for k in pairs(self.intro.alphaButtons) do
            self.intro.alphaButtons[k] = 1
            self.intro.buttonOffsetY[k] = 0
        end
    else
        -- Limpa queue de intro anterior caso ainda tenha resíduo
        -- (ex: jogador entra/sai do menu rapidamente).
        EM.clear("menu_intro")

        -- IMPORTANTE: usar parallelEase pra todas eases iniciarem AGORA em
        -- paralelo. ease bloqueante faria fade-in sequencial absurdamente longo.
        EM.parallelEase(self.intro, "alphaBg",       1, 0.35, "smooth",   "menu_intro")
        EM.parallelEase(self.intro, "alphaTitle",    1, 0.55, "smooth",   "menu_intro")
        EM.parallelEase(self.intro, "alphaSubtitle", 1, 0.55, "smooth",   "menu_intro")
        EM.parallelEase(self.intro, "titleScale",    1, 0.55, "back_out", "menu_intro")

        -- Stagger botões: 0.08s offset entre cada (delays absolutos).
        local order = { "play", "collection", "settings", "quit" }
        for i, name in ipairs(order) do
            local delay = 0.30 + (i - 1) * 0.08
            EM.parallel(delay, function()
                EM.parallelEase(self.intro.alphaButtons,  name, 1, 0.30, "smooth",   "menu_intro")
                EM.parallelEase(self.intro.buttonOffsetY, name, 0, 0.30, "back_out", "menu_intro")
            end, "menu_intro")
        end
    end

    -- Música. fadeDuration > 0 faz crossfade-in suave via AudioManager.
    if Sfx.playMusic then Sfx.playMusic("menuMusic", { fadeDuration = 1.5 }) end
end

function Menu:hide()
    self.visible = false
end

function Menu:mousepressed(x, y, button)
    if not self.visible then return end
    
    for name, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function Menu:mousereleased(x, y, button)
    if not self.visible then return end
    
    for name, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return Menu
