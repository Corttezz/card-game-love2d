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
local TvOsd = require("src.ui.TvOsd")

local Menu = {}
Menu.__index = Menu

-- Movimento reduzido (Configurações → Jogo): a cena fica ESTÁTICA — nada
-- deriva, pisca, respira ou varre. Informação nenhuma some (só movimento).
local function reducedMotion()
    return _G.gameSettings and _G.gameSettings.reducedMotion and true or false
end
-- Relógio da cena: congelado em movimento reduzido (tudo que oscila lê daqui).
local function sceneClock()
    if reducedMotion() then return 0 end
    return love.timer.getTime()
end

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
        alphaButtons  = { continueRun = 1, play = 1, collection = 1, achievements = 1, settings = 1, quit = 1 },
        alphaBg       = 1,
        titleScale    = 1,
        buttonOffsetY = { continueRun = 0, play = 0, collection = 0, achievements = 0, settings = 0, quit = 0 },
    }

    -- 3 versos de carta flutuantes (Balatro-style demo cards). Cada uma tem
    -- um state de hover compartilhado com CardBackHover (replica Card:updateMouse).
    -- v2: CLICÁVEIS — clique dá spin 360° com juice (spinT anima em update).
    -- SÓ duas cartas: esquerda e direita (a 3ª de baixo poluía a coluna
    -- de botões — cortada a pedido do dono, Jul/2026).
    instance.floatingCards = {
        { ax = 0.16, ay = 0.30, phase = 0.0, freqY = 0.7, freqR = 0.5, hover = CardBackHover.new(), spinT = 0 },
        { ax = 0.84, ay = 0.30, phase = 1.7, freqY = 0.5, freqR = 0.6, hover = CardBackHover.new(), spinT = 0 },
    }

    -- v2 "o televisor é o palco" (docs/plan/menu-crt-v2.md):
    -- OSD do aparelho (tag de canal + relógio) que aparece ao entrar e
    -- some em ~3.5s como TV de verdade.
    instance.osdTimer = 0
    -- Motes de poeira dourada derivando (vida ambiente barata).
    -- v3 (Out/2026): 60% vivem no FEIXE de luz da lanterna (cone do teto ao
    -- livro — `shaft = true` mantém o mote dentro do cone no update), o resto
    -- vaga pela sala. Poeira que só se vê onde há luz, como numa sala real.
    instance.motes = {}
    for i = 1, 26 do
        instance.motes[i] = {
            ax = math.random(), ay = math.random(),
            speed = 0.004 + math.random() * 0.010,   -- sobe devagar
            drift = (math.random() - 0.5) * 0.006,
            phase = math.random() * math.pi * 2,
            size = 1 + math.random(2),
            shaft = i <= 16,
        }
    end
    -- Flare das velas (0..1, decai): a sala reage — entrada no menu e clique
    -- nas cartas fazem as chamas crescerem por um instante.
    instance._candleFlare = 0

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
    
    -- Botão Continuar (F1): só aparece com run salva em disco. Retomar é a
    -- ação mais provável de quem tem save — fica ACIMA de Jogar.
    local SaveManager = require("engine.SaveManager")
    self._hasSave = SaveManager.hasRun and SaveManager.hasRun() or false
    if self._hasSave then
        self.buttons.continueRun = Button:new(
            centerX - buttonWidth / 2,
            startY - spacing,
            buttonWidth,
            buttonHeight,
            I18n.t("menu.continue"),
            function()
                self.visible = false
                if Sfx.fadeMusicOut then Sfx.fadeMusicOut(0.5) end
                if self.onContinueCallback then self.onContinueCallback() end
            end,
            Theme.Colors.SUCCESS,
            22
        )
    else
        self.buttons.continueRun = nil
    end

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

    -- Botão Conquistas (F4 gameplay-overhaul)
    self.buttons.achievements = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 2,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.achievements"),
        function()
            if self.onAchievementsCallback then self.onAchievementsCallback() end
        end,
        Theme.Colors.ACCENT or Theme.Colors.INFO,
        20
    )

    -- Botão Configurações
    self.buttons.settings = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 3,
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
        startY + spacing * 4,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.quit"),
        function() self:onQuitClick() end,
        Theme.Colors.ERROR,
        20
    )

    -- v2.2: SEM ícones nos itens do menu (pedido do dono — eram fracos e
    -- repetidos; lista de TV é texto puro, a seta âmbar do hover já guia).
    -- v2.1: look "lista de TV" (variant tv) — barra de seleção âmbar.
    for _, btn in pairs(self.buttons) do
        btn:setVariant("tv")
    end
end

function Menu:updatePositions()
    -- Reposiciona os botões dinamicamente baseado na resolução atual
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")
    
    -- Reposiciona cada botão
    if self.buttons.continueRun then
        self.buttons.continueRun:setPosition(centerX - buttonWidth / 2, startY - spacing)
        self.buttons.continueRun.width = buttonWidth
        self.buttons.continueRun.height = buttonHeight
    end
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

    if self.buttons.achievements then
        self.buttons.achievements:setPosition(centerX - buttonWidth / 2, startY + spacing * 2)
        self.buttons.achievements.width = buttonWidth
        self.buttons.achievements.height = buttonHeight
    end

    if self.buttons.settings then
        self.buttons.settings:setPosition(centerX - buttonWidth / 2, startY + spacing * 3)
        self.buttons.settings.width = buttonWidth
        self.buttons.settings.height = buttonHeight
    end

    if self.buttons.quit then
        self.buttons.quit:setPosition(centerX - buttonWidth / 2, startY + spacing * 4)
        self.buttons.quit.width = buttonWidth
        self.buttons.quit.height = buttonHeight
    end
end

function Menu:update(dt)
    if not self.visible then return end

    -- DynaText do título (lazy-init em ensure). update progredindo timer interno
    -- pra que pop_in cascade + rotate wobble animem por frame.
    self:_ensureTitleDyna()
    -- (wobble do título também para em movimento reduzido)
    if self._titleDyna and not reducedMotion() then self._titleDyna:update(dt) end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end

    -- OSD do aparelho conta o tempo pra sumir (TV real: ~3.5s após trocar
    -- de canal). enterWithIntro reseta pra 0.
    self.osdTimer = (self.osdTimer or 0) + dt

    -- Spin das cartas clicáveis decai (0..1, 1 = acabou de clicar).
    for _, fc in ipairs(self.floatingCards or {}) do
        if fc.spinT and fc.spinT > 0 then
            fc.spinT = math.max(0, fc.spinT - dt / 0.55)
        end
    end

    -- Flare das velas decai (entrada / clique nas cartas acendem).
    self._candleFlare = math.max(0, (self._candleFlare or 0) - dt * 0.9)

    -- Movimento reduzido: a sala fica parada (poeira, parallax, brasas).
    if reducedMotion() then
        self.embers = {}
        self._parX, self._parY = 0, 0
        return
    end

    -- Poeira dourada deriva pra cima (wrap vertical). Motes do FEIXE ficam
    -- dentro do cone da lanterna (meia-largura cresce com a descida).
    local tf = self._sceneTf
    for _, m in ipairs(self.motes or {}) do
        m.ay = m.ay - m.speed * dt * 10
        m.ax = m.ax + m.drift * dt * 10
        if m.shaft and tf then
            local x0, hw = self:_shaftBounds(tf, m.ay)
            if m.ay < 0.03 then m.ay = 0.72; m.ax = x0 + (math.random() - 0.5) * 2 * hw end
            if m.ax < x0 - hw then m.ax = x0 - hw; m.drift = math.abs(m.drift)
            elseif m.ax > x0 + hw then m.ax = x0 + hw; m.drift = -math.abs(m.drift) end
        else
            if m.ay < -0.02 then m.ay = 1.02; m.ax = math.random() end
            if m.ax < -0.02 then m.ax = 1.02 elseif m.ax > 1.02 then m.ax = -0.02 end
        end
    end

    -- v2.1: PARALLAX suavizado (mouse → alvo; lerp evita tranco).
    do
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local mx, my = love.mouse.getPosition()
        local tx = math.max(-1, math.min(1, (mx / W - 0.5) * 2))
        local ty = math.max(-1, math.min(1, (my / H - 0.5) * 2))
        local k = math.min(1, dt * 4)
        self._parX = (self._parX or 0) + (tx - (self._parX or 0)) * k
        self._parY = (self._parY or 0) + (ty - (self._parY or 0)) * k
    end

    -- v2.1: BRASAS subindo das velas (faísca ocasional, vida curta).
    -- Com flare (entrada/clique) as velas cospem mais.
    self.embers = self.embers or {}
    self._emberTimer = (self._emberTimer or 0) - dt
    local flare = self._candleFlare or 0
    if self._emberTimer <= 0 and #self.embers < (flare > 0.3 and 18 or 10) then
        self._emberTimer = (0.28 + math.random() * 0.5) * (1 - 0.6 * flare)
        table.insert(self.embers, {
            candle = math.random(2),            -- índice da âncora
            offX = (math.random() - 0.5) * 10,
            t = 0,
            life = 1.4 + math.random() * 1.2,
            sway = math.random() * math.pi * 2,
        })
    end
    for i = #self.embers, 1, -1 do
        local e = self.embers[i]
        e.t = e.t + dt
        if e.t >= e.life then table.remove(self.embers, i) end
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

    -- Poeira dourada derivando (vida ambiente, atrás das cartas).
    self:_drawMotes()

    -- Brasas das velas (na frente do glow, atrás das cartas).
    self:_drawEmbers()

    -- Vinheta respirando (degraus; estática em movimento reduzido).
    self:_drawVignette(self.intro.alphaBg or 1)

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
    -- 0.355: com o botão Continuar presente a coluna de botões começa em
    -- ~0.42H — o subtítulo em 0.42 colidia com ele.
    love.graphics.print(subtitle,
        math.floor(love.graphics.getWidth() / 2 - subtitleWidth / 2),
        math.floor(love.graphics.getHeight() * 0.355))

    -- Desenha botões. Durante intro: cada botão fica invisível até seu alpha
    -- passar de 0.1, depois faz slide-up de 12px com back_out (efeito "pop in").
    for name, button in pairs(self.buttons) do
        local a = self.intro.alphaButtons[name] or 1
        if a > 0.1 then
            local offY = self.intro.buttonOffsetY[name] or 0
            local origY = button.y
            if offY ~= 0 then button.y = origY + offY end
            button:draw()
            -- v2: estética CRT no hover (varredura + glow + seta OSD)
            self:_drawButtonCrtFx(button)
            if offY ~= 0 then button.y = origY end
        end
    end

    -- Perfil persistente (vitórias/melhor progresso) + versão no rodapé —
    -- o menu "lembra de você" (repaginada Jul/2026).
    self:_drawProfilePlaque()
    self:_drawVersionFooter()

    -- OSD do aparelho por cima de tudo (tag de canal + relógio que somem).
    self:_drawOsdChrome()

    -- Reseta cor
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v2: OSD do televisor =====
-- "AV-1 GRIMOIRE" + relógio real no canto sup-dir. Visível ~3.5s após
-- entrar no menu, depois some com fade — comportamento de TV de verdade.
function Menu:_drawOsdChrome()
    local t = self.osdTimer or 99
    local a = 1
    if t > 3.5 then a = math.max(0, 1 - (t - 3.5) / 0.8) end
    a = a * (self.intro.alphaBg or 1)
    if a <= 0.02 then return end

    local W = love.graphics.getWidth()
    local tag = "AV-1  GRIMOIRE"
    TvOsd.text(tag, W - TvOsd.textWidth(tag) - 26, 20, a)
    local clock = os.date("%H:%M")
    TvOsd.text(clock, W - TvOsd.textWidth(clock) - 26, 44, a * 0.85)
end

-- ===== v2: estética CRT nos botões (hover) =====
-- (a) varredura de scanline clara descendo em loop (scissor no rect);
-- (b) glow de fósforo pulsante na borda; (c) seta OSD piscando à esquerda.
-- Desenhado POR CIMA do Button — o widget global fica intocado.
function Menu:_drawButtonCrtFx(btn)
    if not btn.hover or btn.disabled then return end
    local t = sceneClock()
    local x, y, w, h = btn.x, btn.y, btn.width, btn.height
    local static = reducedMotion()

    -- (a) varredura: banda clara de 10px descendo pelo botão (loop 0.9s)
    local bandH = 10
    local sweepY = y - bandH + ((t * (h + bandH) / 0.9) % (h + bandH))
    love.graphics.setScissor(x, y, w, h)
    love.graphics.setColor(1, 1, 0.92, 0.10)
    love.graphics.rectangle("fill", x, sweepY, w, bandH)
    love.graphics.setColor(1, 1, 0.92, 0.05)
    love.graphics.rectangle("fill", x, sweepY - 4, w, bandH + 8)
    love.graphics.setScissor()

    -- (a2) GLINT pixel: um brilho de 2 px corre a borda de cima do botão em
    -- passos de 4 px (grade), com um rastro de 1 px — reflexo de metal, não
    -- gradiente. Estático em movimento reduzido (fica parado no canto).
    do
        local span = w + 24
        local gx = x - 12 + (static and 0 or math.floor(((t * 160) % span) / 4) * 4)
        local gy = y - 1
        love.graphics.setColor(1, 0.97, 0.85, 0.95)
        love.graphics.rectangle("fill", gx, gy, 4, 2)
        love.graphics.setColor(1, 0.90, 0.55, 0.55)
        love.graphics.rectangle("fill", gx - 8, gy, 8, 1)
        love.graphics.rectangle("fill", gx + 4, gy, 4, 1)
    end

    -- (b) glow de fósforo: contorno duplo pulsante (âmbar quente)
    local pulse = 0.35 + 0.20 * math.sin(t * 5)
    love.graphics.setColor(0.95, 0.78, 0.32, pulse * 0.5)
    love.graphics.rectangle("line", x - 1.5, y - 1.5, w + 3, h + 3)
    love.graphics.setColor(0.95, 0.78, 0.32, pulse * 0.22)
    love.graphics.rectangle("line", x - 3.5, y - 3.5, w + 7, h + 7)

    -- (c) seta OSD piscando (TV menu style) — fixa em movimento reduzido
    if static or math.floor(t * 2.4) % 2 == 0 then
        local g = TvOsd.AMBER
        local ax = x - 18
        local ay = y + h / 2
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.polygon("fill", ax + 1, ay - 5, ax + 1, ay + 7, ax + 11, ay + 1)
        love.graphics.setColor(g[1], g[2], g[3], 0.95)
        love.graphics.polygon("fill", ax, ay - 6, ax, ay + 6, ax + 10, ay)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v2.1: brasas das velas =====
-- Faíscas ocasionais subindo da chama com sway senoidal, esfriando de
-- amarelo-quente pra laranja antes de apagar.
function Menu:_drawEmbers()
    local tf = self._sceneTf
    if not tf or not self.embers or reducedMotion() then return end
    local a0 = (self.intro.alphaBg or 1)
    if a0 <= 0.05 then return end
    local ANCH = { { 0.209, 0.44 }, { 0.770, 0.44 } }
    for _, e in ipairs(self.embers) do
        local anch = ANCH[e.candle]
        local k = e.t / e.life
        local x = tf.ox + anch[1] * tf.dw + e.offX
            + math.sin(e.t * 3 + e.sway) * 6 * k
        local y = tf.oy + anch[2] * tf.dh - k * 70
        local alpha = (1 - k) * 0.8 * a0
        -- esfria: amarelo → laranja
        love.graphics.setColor(1, 0.85 - 0.45 * k, 0.30 - 0.20 * k, alpha)
        local s = k < 0.15 and 2 or 1
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v3: FEIXE da lanterna =====
-- A lanterna pendurada no teto da arte (x 0.50, y 0.04 do PNG) ilumina o
-- livro (y ~0.70). O cone é desenhado em 3 DEGRAUS aditivos (nada de
-- gradiente suave) e balança devagar com noise. Devolve, pra uma altura
-- normalizada `ay`, o centro x e a meia-largura do cone (normalizados).
local SHAFT = { xr = 0.50, topY = 0.04, botY = 0.72, hwTop = 0.012, hwBot = 0.17 }
function Menu:_shaftBounds(tf, ay)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local k = math.max(0, math.min(1, (ay - SHAFT.topY) / (SHAFT.botY - SHAFT.topY)))
    local sway = reducedMotion() and 0 or (love.math.noise(sceneClock() * 0.35, 3.1) - 0.5) * 0.02 * k
    local x0 = (tf.ox + (SHAFT.xr + sway) * tf.dw) / W
    local hw = (SHAFT.hwTop + (SHAFT.hwBot - SHAFT.hwTop) * k) * tf.dw / W
    return x0, hw
end

function Menu:_drawLightShaft(tf, bgAlpha)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local flare = self._candleFlare or 0
    local breath = reducedMotion() and 0.5 or (0.5 + 0.5 * love.math.noise(sceneClock() * 0.8, 11.7))
    -- NA GRADE DA ARTE: o cone é uma pilha de linhas de 1 px da arte, cada
    -- uma com largura em múltiplos de 1 px da arte — bordas em escada, como
    -- o resto do cenário (um polígono antialiased lia como forma vetorial).
    local px = tf.dh / 256
    local yt = math.floor(SHAFT.topY * 256)
    local yb = math.floor(SHAFT.botY * 256)
    love.graphics.setBlendMode("add")
    for step = 1, 3 do
        local shrink = 1 - (step - 1) * 0.33
        local alpha = (0.030 + 0.012 * breath + 0.03 * flare) * bgAlpha
        love.graphics.setColor(1, 0.86, 0.55, alpha)
        for iy = yt, yb, 2 do   -- linhas de 2 px da arte (pilha mais barata)
            local ay = iy / 256
            local x0, hw = self:_shaftBounds(tf, ay)
            local halfPx = math.max(1, math.floor(hw * W * shrink / px))
            local cxPx = math.floor(x0 * W / px)
            -- linhas que se ENCOSTAM exatamente (sem fresta nem sobreposição —
            -- em blend aditivo qualquer uma das duas vira risca horizontal)
            local y0 = math.floor(tf.oy + iy * px)
            local y1 = math.floor(tf.oy + (iy + 2) * px)
            love.graphics.rectangle("fill", (cxPx - halfPx) * px, y0, halfPx * 2 * px, y1 - y0)
        end
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v3: VINHETA que respira =====
-- Bordas escurecem em 3 molduras DEGRAU (sem gradiente), com período lento
-- (~7 s) — a sala "respira" com a luz das velas. Estática em movimento reduzido.
function Menu:_drawVignette(bgAlpha)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = sceneClock()
    local breath = reducedMotion() and 0.5 or (0.5 + 0.5 * math.sin(t * (2 * math.pi / 7)))
    local base = (0.10 + 0.06 * breath) * bgAlpha
    local inset = math.floor(math.min(W, H) * 0.045)
    love.graphics.setLineWidth(1)
    for step = 0, 2 do
        local a = base * (1 - step * 0.33)
        local d = inset * step
        love.graphics.setColor(0, 0, 0, a)
        -- moldura (4 faixas) — degrau sólido, não gradiente
        love.graphics.rectangle("fill", d, d, W - d * 2, inset)
        love.graphics.rectangle("fill", d, H - d - inset, W - d * 2, inset)
        love.graphics.rectangle("fill", d, d + inset, inset, H - d * 2 - inset * 2)
        love.graphics.rectangle("fill", W - d - inset, d + inset, inset, H - d * 2 - inset * 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v3: a PÁGINA se mexe =====
-- O canto da página direita do livro (recorte do PNG) levanta 1-2 px da arte
-- em passos secos, de vez em quando — correnteza de ar na sala. Nada de
-- deformação suave: é o pixel subindo um degrau.
local PAGE_QUAD = { x = 250, y = 168, w = 42, h = 20 }   -- px da arte 400×256
function Menu:_drawPageFlutter(tf, bgAlpha)
    if reducedMotion() then return end
    local ImageCache = require("src.ui.ImageCache")
    local img = ImageCache.get("assets/sprites/scenes/menu.png")
    if not img then return end
    local t = sceneClock()
    -- passo seco a 8 Hz; "rajada" rara (noise > 0.72) levanta 1 ou 2 px
    local n = love.math.noise(math.floor(t * 8) * 0.37, 5.5)
    local lift = n > 0.80 and 2 or (n > 0.70 and 1 or 0)
    if lift == 0 then return end
    local iw, ih = img:getDimensions()
    local sx = tf.dw / iw
    local q = self._pageQuad
    if not q then
        q = love.graphics.newQuad(PAGE_QUAD.x, PAGE_QUAD.y, PAGE_QUAD.w, PAGE_QUAD.h, iw, ih)
        self._pageQuad = q
    end
    local x = tf.ox + PAGE_QUAD.x * sx
    local y = tf.oy + (PAGE_QUAD.y - lift) * (tf.dh / ih)
    love.graphics.setColor(1, 1, 1, bgAlpha)
    love.graphics.draw(img, q, math.floor(x), math.floor(y), 0, sx, tf.dh / ih)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== v2: poeira dourada =====
function Menu:_drawMotes()
    local a = (self.intro.alphaBg or 1)
    if a <= 0.05 then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = sceneClock()
    local g = Palette.AGED_GOLD_LIGHT
    for _, m in ipairs(self.motes or {}) do
        local twinkle = 0.25 + 0.20 * math.sin(t * 1.7 + m.phase)
        if m.shaft then twinkle = twinkle + 0.18 end   -- na luz, a poeira brilha
        love.graphics.setColor(g[1], g[2], g[3], twinkle * a)
        love.graphics.rectangle("fill",
            math.floor(m.ax * W), math.floor(m.ay * H), m.size, m.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Perfil no RODAPÉ direito, espelhando a versão no rodapé esquerdo —
-- uma linha discreta, sem caixa, que não briga com a arte do menu
-- (a plaque em caixa no canto superior destoava do cenário — feedback
-- do dono, Jul/2026). Texto com sombra ink pra legibilidade sobre a arte.
function Menu:_drawProfilePlaque()
    local ProfileStats = require("engine.ProfileStats")
    if not ProfileStats.hasHistory() then return end
    local s = ProfileStats.get()

    local a = (self.intro.alphaBg or 1) * 0.9
    if a <= 0.05 then return end

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Linha única: "★ 2 vitorias · Melhor: Ato 2-6" (ou só corridas se
    -- nunca venceu). Curta, sem rótulo "PERFIL" — o conteúdo se explica.
    local parts = {}
    table.insert(parts, I18n.t("menu.profile_wins", { n = s.wins or 0 }))
    if (s.bestAct or 0) > 0 then
        table.insert(parts, I18n.t("menu.profile_best",
            { act = s.bestAct, floor = s.bestFloor or 0 }))
    else
        table.insert(parts, I18n.t("menu.profile_runs", { n = s.runs or 0 }))
    end
    local text = table.concat(parts, "  ·  ")

    local f = FontManager.getFont(9)
    love.graphics.setFont(f)
    local tw = f:getWidth(text)

    -- Ícone estrela pequeno à esquerda do texto.
    local IconLoader = require("src.ui.IconLoader")
    local icon = IconLoader.get("star")
    local iconSize = 14
    local totalW = tw + (icon and (iconSize + 6) or 0)
    local x = sw - 12 - totalW
    local y = sh - 22

    if icon and icon.draw and icon.size then
        local sc = iconSize / icon.size.w
        love.graphics.setColor(1, 1, 1, a)
        icon.draw(x, y - 2, sc)
        x = x + iconSize + 6
    end

    -- Sombra ink + texto pergaminho (mesma receita do drawWithOutline).
    love.graphics.setColor(0, 0, 0, 0.75 * a)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2],
        Palette.PARCHMENT[3], a)
    love.graphics.print(text, x, y)
end

-- Versão + engine no rodapé esquerdo (discreto, alpha baixo).
function Menu:_drawVersionFooter()
    local a = (self.intro.alphaBg or 1) * 0.65
    if a <= 0.05 then return end
    local f = FontManager.getFont(9)
    love.graphics.setFont(f)
    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
        Palette.PARCHMENT_DARK[3], a)
    local ver = "v" .. (Config.VERSION or "?") .. " · LOVE2D"
    local y = love.graphics.getHeight() - 22
    love.graphics.print(ver, 12, y)

    -- Link "Créditos" logo depois da versão (substitui o antigo "Sobre"
    -- placeholder). Link de rodapé, não item da coluna: a coluna já tem 6
    -- botões e um 7º empurraria o "Sair" pra fora da tela em 768px.
    local label = I18n.t("credits.link")
    local lx = 12 + f:getWidth(ver) + 18
    local lw, lh = f:getWidth(label), f:getHeight()
    self._creditsRect = { x = lx - 6, y = y - 6, w = lw + 12, h = lh + 12 }
    local mx, my = love.mouse.getPosition()
    local r = self._creditsRect
    local hover = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
    if hover then
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
            Palette.AGED_GOLD_LIGHT[3], math.min(1, a / 0.65))
    end
    love.graphics.print(label, lx, y)
    love.graphics.rectangle("fill", lx, y + lh + 1, lw, 1)
end

-- ===== v2.1: BACKGROUND EM CAMADAS VIVAS =====
-- O cenário deixou de ser um PNG parado: parallax de mouse (a sala inteira
-- responde), luz de vela PULSANDO nas duas velas (âncoras na imagem),
-- flicker quente global, fumaça de incenso derivando na frente.
-- v2.3: ANIMAÇÃO DE VELA — o background cicla por frames de flicker
-- desenhados à mão (crossfade suave, "vida de fogo" igual às luminárias dos
-- postes). Ordem pedida pelo usuário; "menu" = a que já tínhamos (chama
-- discreta, funciona como respiro). O laço volta pro começo ("menu" no fim
-- emenda com "menu" no início → dwell mais longo no estado de descanso).
local BG_SEQ = {
    "menu",         -- a que temos hoje
    "menu_normal",  -- normal
    "menu",         -- volta pra hoje
    "menu_1",       -- (1)
    "menu_2",       -- (2)
    "menu_normal",  -- normal
    "menu",         -- volta pra hoje  → emenda com o início
}
-- MESMA cadência do fogo dos postes do jogo: WorldRoad troca o frame da
-- chama a 10 fps com corte seco (fr[floor(_time*10)%#fr]). O menu segue igual
-- — flicker rápido, sem crossfade (só a chama muda entre os frames, então o
-- corte seco lê como fogo vivo, não como troca de imagem).
local BG_FPS = 10

-- Deterministic a partir do relógio: retorna (from, to, mix 0..1).
-- Corte seco → to = from e mix = 0 (drawParallaxCrossfade desenha só `from`).
local function bgFrame(t)
    local n = #BG_SEQ
    local idx = math.floor(t * BG_FPS) % n
    local scene = BG_SEQ[idx + 1]
    return scene, scene, 0
end

function Menu:drawBackground()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local bgAlpha = self.intro.alphaBg or 1
    local t = sceneClock()

    local SceneBackground = require("src.ui.SceneBackground")
    -- CAMADA 1: cenário com parallax (mouse desloca a sala) + crossfade de
    -- vela entre os frames do ciclo (BG_SEQ). Movimento reduzido: frame fixo.
    local fromScene, toScene, mix = bgFrame(t)
    local ok, tf = SceneBackground.drawParallaxCrossfade(fromScene, toScene, mix,
        width, height, 0.30,
        (self._parX or 0) * -14, (self._parY or 0) * -8, 1.07)
    if ok then
        self._sceneTf = tf

        -- CAMADA 1b: a página do livro levanta de vez em quando (correnteza)
        self:_drawPageFlutter(tf, bgAlpha)

        -- CAMADA 2: luz das velas (glow radial pulsando com noise orgânico)
        self:_drawCandleGlow(tf, t, bgAlpha)

        -- CAMADA 2b: feixe da lanterna do teto sobre o livro (degraus)
        self:_drawLightShaft(tf, bgAlpha)

        -- CAMADA 3: respiração quente global (flicker de sala à vela)
        local flick = 0.030 + 0.028 * love.math.noise(t * 1.9, 7.3)
        love.graphics.setColor(1, 0.70, 0.34, flick * bgAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)

        -- CAMADA 4: fumaça de incenso derivando (profundidade)
        self:_drawSmokeLayer(t, bgAlpha)

        if bgAlpha < 1 then
            love.graphics.setColor(0, 0, 0, 1 - bgAlpha)
            love.graphics.rectangle("fill", 0, 0, width, height)
        end
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

-- Âncoras das velas na IMAGEM do menu (coords relativas ao PNG 400×256,
-- medidas na captura). O transform do parallax converte pra tela — a luz
-- acompanha a vela mesmo com a sala deslocando.
local CANDLE_ANCHORS = {
    { xr = 0.209, yr = 0.44, phase = 0.0 },
    { xr = 0.770, yr = 0.44, phase = 3.7 },
}

-- Imagem radial cacheada pro glow (128×128, falloff quadrático).
local function ensureGlowImage(self)
    if self._glowImg then return end
    local N = 128
    local data = love.image.newImageData(N, N)
    data:mapPixel(function(px, py)
        local dx = (px - N / 2) / (N / 2)
        local dy = (py - N / 2) / (N / 2)
        local d = math.sqrt(dx * dx + dy * dy)
        local v = math.max(0, 1 - d)
        v = v * v
        return 1, 1, 1, v
    end)
    self._glowImg = love.graphics.newImage(data)
    self._glowImg:setFilter("linear", "linear")
end

function Menu:_drawCandleGlow(tf, t, bgAlpha)
    ensureGlowImage(self)
    love.graphics.setBlendMode("add")
    local flare = self._candleFlare or 0
    for _, a in ipairs(CANDLE_ANCHORS) do
        local x = tf.ox + a.xr * tf.dw
        local y = tf.oy + a.yr * tf.dh
        -- flicker orgânico (noise, não seno — vela real não é metrônomo);
        -- flare (entrada/clique): a chama cresce e clareia por um instante
        local flick = (0.70 + 0.30 * love.math.noise(t * 5.5, a.phase)) * (1 + 0.6 * flare)
        local r = tf.dw * 0.075
            * (0.92 + 0.14 * love.math.noise(t * 2.8, a.phase + 9)) * (1 + 0.35 * flare)
        -- halo largo alaranjado
        love.graphics.setColor(1, 0.55, 0.18, 0.26 * flick * bgAlpha)
        love.graphics.draw(self._glowImg, x, y, 0, r * 2 / 128, r * 2 / 128, 64, 64)
        -- núcleo quente menor
        love.graphics.setColor(1, 0.82, 0.45, 0.30 * flick * bgAlpha)
        love.graphics.draw(self._glowImg, x, y, 0, r / 128, r / 128, 64, 64)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Fumaça de incenso: 3 novelos derivando devagar na frente do cenário
-- (parallax mais forte que o fundo = profundidade de verdade).
local SMOKE_WISPS = {
    { img = "assets/effects/smoke1.png", yr = 0.80, speed = 9,  scaleR = 0.55, a = 0.09, seed = 0 },
    { img = "assets/effects/smoke2.png", yr = 0.88, speed = 14, scaleR = 0.70, a = 0.12, seed = 400 },
    { img = "assets/effects/smoke3.png", yr = 0.70, speed = 6,  scaleR = 0.45, a = 0.06, seed = 800 },
}

function Menu:_drawSmokeLayer(t, bgAlpha)
    local ImageCache = require("src.ui.ImageCache")
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local par = (self._parX or 0) * -26   -- parallax frontal mais forte
    t = t + 400   -- fase (t=0 em movimento reduzido ainda espalha os novelos)
    for _, wsp in ipairs(SMOKE_WISPS) do
        local img = ImageCache.get(wsp.img)
        if img then
            local iw = img:getWidth()
            local sc = (W * wsp.scaleR) / iw
            local span = W + iw * sc
            local x = ((t * wsp.speed + wsp.seed) % span) - iw * sc + par
            local y = H * wsp.yr + math.sin(t * 0.35 + wsp.seed) * 12
            love.graphics.setColor(1, 0.95, 0.85, wsp.a * bgAlpha)
            love.graphics.draw(img, x, y, 0, sc, sc, 0, img:getHeight() / 2)
        end
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
        local pulse = 0.85 + math.sin(sceneClock() * 1.2) * 0.15
        if alpha < 0.99 or reducedMotion() then pulse = 1 end -- intro/estático: sem pulse
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
    local t = sceneClock()

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

        -- v2: spin de clique — 360° com smoothstep + pop de escala.
        local spinRot, spinScale = 0, 1
        if fc.spinT and fc.spinT > 0 then
            local k = fc.spinT
            local s = k * k * (3 - 2 * k)          -- smoothstep
            spinRot = s * math.pi * 2
            spinScale = 1 + 0.14 * math.sin((1 - k) * math.pi)
        end
        fc.hover.scale = spinScale
        fc.hover.rot   = rotDrift + spinRot

        -- bbox do último draw (pro hit-test do clique em mousepressed)
        fc._cx, fc._cy, fc._w, fc._h = cx, cy, cardW, cardH

        CardBack.draw(cx, cy, cardW, cardH, fc.hover)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- (F1 do UI Overhaul: drawInstructions REMOVIDO — instruções de gameplay
-- vazavam por cima da arte do livro; dicas de jogo pertencem ao gameplay.)

function Menu:onPlayClick()
    -- Slot ÚNICO de save (padrão StS): começar outra corrida apaga a salva no
    -- primeiro checkpoint. Antes era SEM PERGUNTAR — um clique distraído em
    -- "Jogar" em vez de "Continuar" jogava fora a run (known_gaps 25).
    if self._hasSave and not self._newRunConfirmed then
        local ConfirmDialog = require("src.ui.ConfirmDialog")
        ConfirmDialog.show({
            title   = I18n.t("confirm.new_run_title"),
            body    = I18n.t("confirm.new_run_body"),
            confirm = I18n.t("confirm.new_run_yes"),
            cancel  = I18n.t("confirm.cancel"),
            danger  = true,
            onConfirm = function()
                self._newRunConfirmed = true
                self:onPlayClick()
                self._newRunConfirmed = false
            end,
        })
        return
    end
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
function Menu:setAchievementsCallback(cb) self.onAchievementsCallback = cb end
function Menu:setContinueCallback(cb) self.onContinueCallback = cb end
function Menu:setSettingsCallback(cb) self.onSettingsCallback = cb end
function Menu:setCreditsCallback(cb) self.onCreditsCallback = cb end

-- ESC no menu principal: antes fechava o jogo NA HORA (sem animação nem
-- pergunta) — quem aperta ESC "pra voltar" perdia a janela. Agora pergunta.
function Menu:requestQuit()
    local ConfirmDialog = require("src.ui.ConfirmDialog")
    if ConfirmDialog.isVisible() then return end
    ConfirmDialog.show({
        title   = I18n.t("confirm.quit_title"),
        body    = I18n.t("confirm.quit_body"),
        confirm = I18n.t("confirm.quit_yes"),
        cancel  = I18n.t("confirm.cancel"),
        danger  = true,
        onConfirm = function() self:onQuitClick() end,
    })
end

function Menu:onQuitClick()
    -- Identidade CRT: sair = a TV desliga (colapso) e ENTÃO fecha.
    local ok, CRTShader = pcall(require, "src.ui.CRTShader")
    if ok and CRTShader.powerOff then
        -- v3.6: colapso → linha → ponto de fósforo esfriando até apagar
        CRTShader.powerOff(1.2, function() love.event.quit() end)
    else
        love.event.quit()
    end
end

function Menu:setPlayCallback(callback)
    self.onPlayCallback = callback
end

function Menu:show()
    -- recria botões: o save pode ter surgido/sumido desde a última visita
    -- (Continuar aparece/some — F1 do UI Overhaul)
    self:createButtons()
    self.visible = true
end

-- Reanima o menu como se fosse a primeira vez: alpha 0→1 staggered nos botões,
-- title scale com back-out, music fade-in. Chamado por main.lua após o splash
-- e ao voltar do gameplay/collection/settings.
function Menu:enterWithIntro()
    self.visible = true
    -- OSD do aparelho reaparece (como TV real ao trocar de canal).
    self.osdTimer = 0
    -- as velas reagem à entrada (flare que decai em ~1 s)
    self._candleFlare = 1

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
        -- continueRun entra no stagger (antes surgia seco, a 100%, enquanto o
        -- resto da coluna fazia fade-in — o único botão "fora do ritmo").
        local order = { "continueRun", "play", "collection", "achievements", "settings", "quit" }
        for i, name in ipairs(order) do
            local delay = 0.30 + (i - 1) * 0.08
            EM.parallel(delay, function()
                EM.parallelEase(self.intro.alphaButtons,  name, 1, 0.30, "smooth",   "menu_intro")
                EM.parallelEase(self.intro.buttonOffsetY, name, 0, 0.30, "back_out", "menu_intro")
            end, "menu_intro")
        end
    end

    -- Música. fadeDuration > 0 faz crossfade-in suave via AudioManager.
    if Sfx.playMusic then
        Sfx.playMusic("menuMusic", { fadeDuration = 1.5 })
        -- Avisa o diretor de trilha que o menu já está tocando, senão ele
        -- reinicia a mesma faixa no primeiro update depois do splash.
        local okDir, MD = pcall(require, "src.systems.MusicDirector")
        if okDir then MD.markCurrent("menuMusic") end
    end
end

function Menu:hide()
    self.visible = false
end

function Menu:mousepressed(x, y, button)
    if not self.visible then return end

    local consumed = false
    for name, btn in pairs(self.buttons) do
        if btn:mousepressed(x, y, button) then consumed = true end
    end

    -- Link "Créditos" do rodapé.
    local r = self._creditsRect
    if not consumed and button == 1 and r and self.onCreditsCallback
        and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        self.onCreditsCallback()
        return
    end

    -- v2: cartas flutuantes clicáveis (easter egg) — só se o clique não
    -- caiu em botão (botões têm prioridade no z-order de hit).
    if not consumed and button == 1 then
        for _, fc in ipairs(self.floatingCards or {}) do
            if fc._cx and (fc.spinT or 0) <= 0
                and math.abs(x - fc._cx) <= fc._w / 2
                and math.abs(y - fc._cy) <= fc._h / 2 then
                fc.spinT = 1
                self._candleFlare = math.max(self._candleFlare or 0, 0.6)
                Sfx.play("cardSelect", { pitch = 1.1 + math.random() * 0.2 })
                break
            end
        end
    end
end

function Menu:mousereleased(x, y, button)
    if not self.visible then return end
    
    for name, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return Menu
