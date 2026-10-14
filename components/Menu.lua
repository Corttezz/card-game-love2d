local Debug = require("src.core.Debug")
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

local function reducedMotion()
    return _G.gameSettings and _G.gameSettings.reducedMotion and true or false
end
local function sceneClock()
    if reducedMotion() then return 0 end
    return love.timer.getTime()
end

function Menu:new()
    local instance = setmetatable({}, Menu)
    instance.buttons = {}
    instance.visible = true

    instance.intro = {
        active        = false,
        alphaTitle    = 1,
        alphaButtons  = { continueRun = 1, play = 1, collection = 1, achievements = 1, settings = 1, quit = 1 },
        alphaBg       = 1,
        titleScale    = 1,
        buttonOffsetY = { continueRun = 0, play = 0, collection = 0, achievements = 0, settings = 0, quit = 0 },
    }

    instance.floatingCards = {
        { ax = 0.16, ay = 0.30, phase = 0.0, freqY = 0.7, freqR = 0.5, hover = CardBackHover.new(), spinT = 0 },
        { ax = 0.84, ay = 0.30, phase = 1.7, freqY = 0.5, freqR = 0.6, hover = CardBackHover.new(), spinT = 0 },
    }

    instance.osdTimer = 0
    instance.motes = {}
    for i = 1, 26 do
        instance.motes[i] = {
            ax = math.random(), ay = math.random(),
            speed = 0.004 + math.random() * 0.010,
            drift = (math.random() - 0.5) * 0.006,
            phase = math.random() * math.pi * 2,
            size = 1 + math.random(2),
            shaft = i <= 16,
        }
    end
    instance._candleFlare = 0

    instance:createButtons()

    I18n.onLocaleChanged(function()
        if instance.visible ~= nil then instance:createButtons() end
    end)

    return instance
end

function Menu:_title()    return I18n.t("menu.title") end

function Menu:createButtons()
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")

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

    for _, btn in pairs(self.buttons) do
        btn:setVariant("tv")
    end
end

function Menu:updatePositions()
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")

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

    self:_ensureTitleDyna()
    if self._titleDyna then
        self._titleDyna.rotate = not reducedMotion()
        self._titleDyna:update(dt)
    end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end

    self.osdTimer = (self.osdTimer or 0) + dt

    for _, fc in ipairs(self.floatingCards or {}) do
        if fc.spinT and fc.spinT > 0 then
            fc.spinT = math.max(0, fc.spinT - dt / 0.55)
        end
    end

    self._candleFlare = math.max(0, (self._candleFlare or 0) - dt * 0.9)

    if reducedMotion() then
        self.embers = {}
        self._parX, self._parY = 0, 0
        return
    end

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

    do
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local mx, my = love.mouse.getPosition()
        local tx = math.max(-1, math.min(1, (mx / W - 0.5) * 2))
        local ty = math.max(-1, math.min(1, (my / H - 0.5) * 2))
        local k = math.min(1, dt * 4)
        self._parX = (self._parX or 0) + (tx - (self._parX or 0)) * k
        self._parY = (self._parY or 0) + (ty - (self._parY or 0)) * k
    end

    self.embers = self.embers or {}
    self._emberTimer = (self._emberTimer or 0) - dt
    local flare = self._candleFlare or 0
    if self._emberTimer <= 0 and #self.embers < (flare > 0.3 and 18 or 10) then
        self._emberTimer = (0.28 + math.random() * 0.5) * (1 - 0.6 * flare)
        table.insert(self.embers, {
            candle = math.random(2),
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
            rotate = true,
            pop_in = 0.5,
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

    self:drawBackground()

    self:_drawMotes()

    self:_drawEmbers()

    self:_drawVignette(self.intro.alphaBg or 1)

    self:_drawFloatingCards()

    self:drawTitle()

    for name, button in pairs(self.buttons) do
        local a = self.intro.alphaButtons[name] or 1
        if a > 0.1 then
            local offY = self.intro.buttonOffsetY[name] or 0
            local origY = button.y
            if offY ~= 0 then button.y = origY + offY end
            button:draw()
            self:_drawButtonCrtFx(button)
            if offY ~= 0 then button.y = origY end
        end
    end

    self:_drawProfilePlaque()
    self:_drawVersionFooter()

    self:_drawOsdChrome()

    love.graphics.setColor(1, 1, 1, 1)
end

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

function Menu:_drawButtonCrtFx(btn)
    if not btn.hover or btn.disabled then return end
    local t = sceneClock()
    local x, y, w, h = btn.x, btn.y, btn.width, btn.height
    local static = reducedMotion()

    if require("src.ui.CRTShader").isEnabled() then
        local bandH = 10
        local sweepY = y - bandH + ((t * (h + bandH) / 0.9) % (h + bandH))
        love.graphics.setScissor(x, y, w, h)
        love.graphics.setColor(1, 1, 0.92, 0.10)
        love.graphics.rectangle("fill", x, sweepY, w, bandH)
        love.graphics.setColor(1, 1, 0.92, 0.05)
        love.graphics.rectangle("fill", x, sweepY - 4, w, bandH + 8)
        love.graphics.setScissor()
    end

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

    local pulse = 0.35 + 0.20 * math.sin(t * 5)
    love.graphics.setColor(0.95, 0.78, 0.32, pulse * 0.5)
    love.graphics.rectangle("line", x - 1.5, y - 1.5, w + 3, h + 3)
    love.graphics.setColor(0.95, 0.78, 0.32, pulse * 0.22)
    love.graphics.rectangle("line", x - 3.5, y - 3.5, w + 7, h + 7)

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
        love.graphics.setColor(1, 0.85 - 0.45 * k, 0.30 - 0.20 * k, alpha)
        local s = k < 0.15 and 2 or 1
        love.graphics.rectangle("fill", math.floor(x), math.floor(y), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local SHAFT = { xr = 0.50, topY = 0.04, botY = 0.72, hwTop = 0.012, hwBot = 0.17 }
function Menu:_shaftBounds(tf, ay)
    local W = love.graphics.getWidth()
    local k = math.max(0, math.min(1, (ay - SHAFT.topY) / (SHAFT.botY - SHAFT.topY)))
    local sway = reducedMotion() and 0 or (love.math.noise(sceneClock() * 0.35, 3.1) - 0.5) * 0.02 * k
    local x0 = (tf.ox + (SHAFT.xr + sway) * tf.dw) / W
    local hw = (SHAFT.hwTop + (SHAFT.hwBot - SHAFT.hwTop) * k) * tf.dw / W
    return x0, hw
end

function Menu:_drawLightShaft(tf, bgAlpha)
    local W = love.graphics.getWidth()
    local flare = self._candleFlare or 0
    local breath = reducedMotion() and 0.5 or (0.5 + 0.5 * love.math.noise(sceneClock() * 0.8, 11.7))
    local px = tf.dh / 256
    local yt = math.floor(SHAFT.topY * 256)
    local yb = math.floor(SHAFT.botY * 256)
    love.graphics.setBlendMode("add")
    for step = 1, 3 do
        local shrink = 1 - (step - 1) * 0.33
        local alpha = (0.030 + 0.012 * breath + 0.03 * flare) * bgAlpha
        love.graphics.setColor(1, 0.86, 0.55, alpha)
        for iy = yt, yb, 2 do
            local ay = iy / 256
            local x0, hw = self:_shaftBounds(tf, ay)
            local halfPx = math.max(1, math.floor(hw * W * shrink / px))
            local cxPx = math.floor(x0 * W / px)
            local y0 = math.floor(tf.oy + iy * px)
            local y1 = math.floor(tf.oy + (iy + 2) * px)
            love.graphics.rectangle("fill", (cxPx - halfPx) * px, y0, halfPx * 2 * px, y1 - y0)
        end
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

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
        love.graphics.rectangle("fill", d, d, W - d * 2, inset)
        love.graphics.rectangle("fill", d, H - d - inset, W - d * 2, inset)
        love.graphics.rectangle("fill", d, d + inset, inset, H - d * 2 - inset * 2)
        love.graphics.rectangle("fill", W - d - inset, d + inset, inset, H - d * 2 - inset * 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local PAGE_QUAD = { x = 250, y = 168, w = 42, h = 20 }
function Menu:_drawPageFlutter(tf, bgAlpha)
    if reducedMotion() then return end
    local ImageCache = require("src.ui.ImageCache")
    local img = ImageCache.get("assets/sprites/scenes/menu.png")
    if not img then return end
    local t = sceneClock()
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

function Menu:_drawMotes()
    local a = (self.intro.alphaBg or 1)
    if a <= 0.05 then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = sceneClock()
    local g = Palette.AGED_GOLD_LIGHT
    for _, m in ipairs(self.motes or {}) do
        local twinkle = 0.25 + 0.20 * math.sin(t * 1.7 + m.phase)
        if m.shaft then twinkle = twinkle + 0.18 end
        love.graphics.setColor(g[1], g[2], g[3], twinkle * a)
        love.graphics.rectangle("fill",
            math.floor(m.ax * W), math.floor(m.ay * H), m.size, m.size)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:_drawProfilePlaque()
    local ProfileStats = require("engine.ProfileStats")
    if not ProfileStats.hasHistory() then return end
    local s = ProfileStats.get()

    local a = (self.intro.alphaBg or 1) * 0.9
    if a <= 0.05 then return end

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

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

    love.graphics.setColor(0, 0, 0, 0.75 * a)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2],
        Palette.PARCHMENT[3], a)
    love.graphics.print(text, x, y)
end

function Menu:_drawVersionFooter()
    local a = (self.intro.alphaBg or 1) * 0.65
    if a <= 0.05 then return end
    local f = FontManager.getFont(9)
    love.graphics.setFont(f)
    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
        Palette.PARCHMENT_DARK[3], a)
    local ver = "v" .. (Config.VERSION or "?")
    local y = love.graphics.getHeight() - 22
    love.graphics.print(ver, 12, y)
end

local BG_SEQ = {
    "menu",
    "menu_normal",
    "menu",
    "menu_1",
    "menu_2",
    "menu_normal",
    "menu",
}
local BG_FPS = 10

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
    local fromScene, toScene, mix = bgFrame(t)
    local ok, tf = SceneBackground.drawParallaxCrossfade(fromScene, toScene, mix,
        width, height, 0.30,
        (self._parX or 0) * -14, (self._parY or 0) * -8, 1.07)
    if ok then
        self._sceneTf = tf

        self:_drawPageFlutter(tf, bgAlpha)

        self:_drawCandleGlow(tf, t, bgAlpha)

        self:_drawLightShaft(tf, bgAlpha)

        local flick = 0.030 + 0.028 * love.math.noise(t * 1.9, 7.3)
        love.graphics.setColor(1, 0.70, 0.34, flick * bgAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)

        self:_drawSmokeLayer(t, bgAlpha)

        if bgAlpha < 1 then
            love.graphics.setColor(0, 0, 0, 1 - bgAlpha)
            love.graphics.rectangle("fill", 0, 0, width, height)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

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

local CANDLE_ANCHORS = {
    { xr = 0.209, yr = 0.44, phase = 0.0 },
    { xr = 0.770, yr = 0.44, phase = 3.7 },
}

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
        local flick = (0.70 + 0.30 * love.math.noise(t * 5.5, a.phase)) * (1 + 0.6 * flare)
        local r = tf.dw * 0.075
            * (0.92 + 0.14 * love.math.noise(t * 2.8, a.phase + 9)) * (1 + 0.35 * flare)
        love.graphics.setColor(1, 0.55, 0.18, 0.26 * flick * bgAlpha)
        love.graphics.draw(self._glowImg, x, y, 0, r * 2 / 128, r * 2 / 128, 64, 64)
        love.graphics.setColor(1, 0.82, 0.45, 0.30 * flick * bgAlpha)
        love.graphics.draw(self._glowImg, x, y, 0, r / 128, r / 128, 64, 64)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local SMOKE_WISPS = {
    { img = "assets/effects/smoke1.png", yr = 0.80, speed = 9,  scaleR = 0.55, a = 0.09, seed = 0 },
    { img = "assets/effects/smoke2.png", yr = 0.88, speed = 14, scaleR = 0.70, a = 0.12, seed = 400 },
    { img = "assets/effects/smoke3.png", yr = 0.70, speed = 6,  scaleR = 0.45, a = 0.06, seed = 800 },
}

function Menu:_drawSmokeLayer(t, bgAlpha)
    local ImageCache = require("src.ui.ImageCache")
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local par = (self._parX or 0) * -26
    t = t + 400
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

    local padX, padY = 28, 12
    local bx, by = tx - padX, ty - padY
    local bw, bh = tw + padX * 2, th + padY * 2

    local function colA(c, mul) return { c[1], c[2], c[3], (c[4] or 1) * (mul or alpha) } end
    PixelCanvas.rect(bx, by, bw, bh, colA(Palette.PANEL_FILL))
    PixelCanvas.rectOutline(bx, by, bw, bh, colA(Palette.PANEL_OUTLINE))
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, colA(Palette.PANEL_OUTLINE_INNER))

    if self._titleDyna then
        local pulse = 0.85 + math.sin(sceneClock() * 1.2) * 0.15
        if alpha < 0.99 or reducedMotion() then pulse = 1 end
        local g = Palette.AGED_GOLD_LIGHT
        local c = self._titleDyna.colours[1]
        c[1], c[2], c[3], c[4] = g[1] * pulse, g[2] * pulse, g[3] * pulse, alpha
        self._titleDyna:draw(0, 0)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:_drawFloatingCards()
    if not self.floatingCards then return end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local t = sceneClock()

    local cardW = math.floor(W * 0.12)
    local cardH = math.floor(cardW * 1.5)

    local bgAlpha = self.intro.alphaBg or 1
    if bgAlpha <= 0.05 then return end

    local alpha = 0.95 * bgAlpha
    local dt = love.timer.getDelta()

    local mx, my = love.mouse.getPosition()

    for _, fc in ipairs(self.floatingCards) do
        local cx = W * fc.ax
        local cy = H * fc.ay + math.sin(t * fc.freqY + fc.phase) * 14
        local rotDrift = math.sin(t * fc.freqR + fc.phase) * 0.10

        CardBackHover.update(fc.hover, mx, my, cx, cy, cardW, cardH, dt, "up")
        fc.hover.alpha = alpha

        local spinRot, spinScale = 0, 1
        if fc.spinT and fc.spinT > 0 then
            local k = fc.spinT
            local s = k * k * (3 - 2 * k)
            spinRot = s * math.pi * 2
            spinScale = 1 + 0.14 * math.sin((1 - k) * math.pi)
        end
        fc.hover.scale = spinScale
        fc.hover.rot   = rotDrift + spinRot

        fc._cx, fc._cy, fc._w, fc._h = cx, cy, cardW, cardH

        CardBack.draw(cx, cy, cardW, cardH, fc.hover)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:onPlayClick()
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
    if Sfx.fadeMusicOut then Sfx.fadeMusicOut(0.5) end
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
        Debug.warn("Configurações - callback não definido")
    end
end

function Menu:onCollectionClick()
    if self.onCollectionCallback then
        self.onCollectionCallback()
    else
        Debug.warn("Coleção - callback não definido")
    end
end

function Menu:setCollectionCallback(cb) self.onCollectionCallback = cb end
function Menu:setAchievementsCallback(cb) self.onAchievementsCallback = cb end
function Menu:setContinueCallback(cb) self.onContinueCallback = cb end
function Menu:setSettingsCallback(cb) self.onSettingsCallback = cb end

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
    local ok, CRTShader = pcall(require, "src.ui.CRTShader")
    if ok and CRTShader.powerOff then
        CRTShader.powerOff(1.2, function() love.event.quit() end)
    else
        love.event.quit()
    end
end

function Menu:setPlayCallback(callback)
    self.onPlayCallback = callback
end

function Menu:show()
    self:createButtons()
    self.visible = true
end

function Menu:enterWithIntro()
    self.visible = true
    self.osdTimer = 0
    self._candleFlare = 1

    self.intro.active        = true
    self.intro.alphaBg       = 0
    self.intro.alphaTitle    = 0
    self.intro.titleScale    = 0.85
    for k in pairs(self.intro.alphaButtons) do
        self.intro.alphaButtons[k] = 0
        self.intro.buttonOffsetY[k] = 12
    end

    local EM = _G.EventManager
    if not EM then
        self.intro.alphaBg = 1
        self.intro.alphaTitle = 1
        self.intro.titleScale = 1
        for k in pairs(self.intro.alphaButtons) do
            self.intro.alphaButtons[k] = 1
            self.intro.buttonOffsetY[k] = 0
        end
    else
        EM.clear("menu_intro")

        EM.parallelEase(self.intro, "alphaBg",       1, 0.35, "smooth",   "menu_intro")
        EM.parallelEase(self.intro, "alphaTitle",    1, 0.55, "smooth",   "menu_intro")
        EM.parallelEase(self.intro, "titleScale",    1, 0.55, "back_out", "menu_intro")

        local order = { "continueRun", "play", "collection", "achievements", "settings", "quit" }
        for i, name in ipairs(order) do
            local delay = 0.30 + (i - 1) * 0.08
            EM.parallel(delay, function()
                EM.parallelEase(self.intro.alphaButtons,  name, 1, 0.30, "smooth",   "menu_intro")
                EM.parallelEase(self.intro.buttonOffsetY, name, 0, 0.30, "back_out", "menu_intro")
            end, "menu_intro")
        end
    end

    if Sfx.playMusic then
        Sfx.playMusic("menuMusic", { fadeDuration = 1.5 })
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
